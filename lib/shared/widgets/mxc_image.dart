import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:matrix/matrix.dart';

/// A widget that loads and displays an image from an `mxc://` URI.
///
/// Handles the async resolution of download URIs and includes the required
/// `Authorization` header for authenticated media (Matrix spec v1.11+).
/// Images are cached in memory to avoid redundant network requests.
class MxcImage extends StatefulWidget {
  const MxcImage({
    super.key,
    required this.uri,
    required this.client,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isThumbnail = true,
    this.placeholder,
    this.errorBuilder,
  });

  /// The `mxc://` URI to load.
  final Uri uri;

  /// The Matrix client (used for URI resolution and auth token).
  final Client client;

  /// Display width of the image.
  final double? width;

  /// Display height of the image.
  final double? height;

  /// How the image should be inscribed into the space.
  final BoxFit fit;

  /// Whether to request a thumbnail instead of the full image.
  final bool isThumbnail;

  /// Widget to show while loading. If null, shows nothing.
  final Widget Function(BuildContext context)? placeholder;

  /// Widget to show on error. If null, shows nothing.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @visibleForTesting
  static void debugClearCaches() {
    _MxcImageState._cache.clear();
    _MxcImageState._cacheSizes.clear();
    _MxcImageState._cacheBytes = 0;
    _MxcImageState._inFlight.clear();
  }

  @visibleForTesting
  static void debugPutInMemoryCache(String key, Uint8List bytes) {
    _MxcImageState._putInMemoryCache(key, bytes);
  }

  @visibleForTesting
  static Uint8List? debugGetFromMemoryCache(String key) {
    return _MxcImageState._getFromMemoryCache(key);
  }

  @visibleForTesting
  static int debugMemoryEntryCount() => _MxcImageState._cache.length;

  @visibleForTesting
  static Future<Uint8List> debugRunCoalesced(
    String key,
    Future<Uint8List> Function() loader,
  ) {
    return _MxcImageState._withInFlightDedup(key, loader);
  }

  @override
  State<MxcImage> createState() => _MxcImageState();
}

class _MxcImageState extends State<MxcImage> {
  /// In-memory LRU cache shared across all MxcImage instances.
  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  static final Map<String, int> _cacheSizes = {};
  static const int _maxMemoryEntries = 150;
  static const int _maxMemoryBytes = 32 * 1024 * 1024;
  static int _cacheBytes = 0;

  /// Tracks currently running image loads per cache key.
  /// Multiple widgets requesting the same image await the same future.
  static final Map<String, Future<Uint8List>> _inFlight = {};

  /// Disk cache for Matrix media.
  static final CacheManager _diskCache = CacheManager(
    Config(
      'substitution_mxc_image_cache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 400,
    ),
  );

  Uint8List? _imageData;
  Object? _error;
  bool _loading = false;

  String get _cacheKey {
    final w = widget.width?.toInt() ?? 0;
    final h = widget.height?.toInt() ?? 0;
    return '${widget.uri}|${w}x$h|${widget.isThumbnail}';
  }

  static Uint8List? _getFromMemoryCache(String key) {
    final bytes = _cache.remove(key);
    if (bytes == null) return null;
    // Reinsert to mark as recently used.
    _cache[key] = bytes;
    return bytes;
  }

  static void _putInMemoryCache(String key, Uint8List bytes) {
    final existing = _cache.remove(key);
    if (existing != null) {
      _cacheBytes -= _cacheSizes.remove(key) ?? existing.length;
    }

    _cache[key] = bytes;
    _cacheSizes[key] = bytes.length;
    _cacheBytes += bytes.length;

    while (_cache.length > _maxMemoryEntries || _cacheBytes > _maxMemoryBytes) {
      final lruKey = _cache.keys.first;
      _cache.remove(lruKey);
      _cacheBytes -= _cacheSizes.remove(lruKey) ?? 0;
    }
  }

  static Future<Uint8List> _withInFlightDedup(
    String key,
    Future<Uint8List> Function() loader,
  ) async {
    final existing = _inFlight[key];
    if (existing != null) {
      return await existing;
    }

    final future = loader();
    _inFlight[key] = future;

    try {
      return await future;
    } finally {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Check memory cache synchronously to avoid a blank frame.
    final cached = _getFromMemoryCache(_cacheKey);
    if (cached != null) {
      _imageData = cached;
      return;
    }
    // Defer network loading to after initState so that MediaQuery.of(context)
    // is available. Calling it synchronously from initState triggers
    // "dependOnInheritedWidgetOfExactType was called before initState completed".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(MxcImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height ||
        oldWidget.isThumbnail != widget.isThumbnail) {
      _imageData = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) return;

    // Check memory cache first
    final cached = _getFromMemoryCache(_cacheKey);
    if (cached != null) {
      if (mounted) setState(() => _imageData = cached);
      return;
    }

    _loading = true;

    try {
      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
      final width =
          widget.width != null ? (widget.width! * devicePixelRatio) : null;
      final height =
          widget.height != null ? (widget.height! * devicePixelRatio) : null;

      // Resolve the mxc:// URI to an HTTP(S) URI (async, supports authenticated media)
      final Uri httpUri;
      if (widget.isThumbnail && (width != null || height != null)) {
        httpUri = await widget.uri.getThumbnailUri(
          widget.client,
          width: width ?? height ?? 128,
          height: height ?? width ?? 128,
          method: ThumbnailMethod.crop,
        );
      } else {
        httpUri = await widget.uri.getDownloadUri(widget.client);
      }

      if (httpUri.toString().isEmpty) {
        throw Exception('Failed to resolve mxc URI: ${widget.uri}');
      }

      final imageBytes = await _withInFlightDedup(
        _cacheKey,
        () => _loadBytes(httpUri, _cacheKey),
      );

      if (!mounted) return;
      setState(() {
        _imageData = imageBytes;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      debugPrint('MxcImage: Error loading ${widget.uri}: $e');
    } finally {
      _loading = false;
    }
  }

  Future<Uint8List> _loadBytes(Uri httpUri, String key) async {
    final cacheUrl = httpUri.toString();
    final headers = {
      if (widget.client.accessToken != null)
        'authorization': 'Bearer ${widget.client.accessToken}',
    };

    final cachedOnDisk = await _diskCache.getFileFromCache(cacheUrl);
    if (cachedOnDisk != null) {
      final bytes = await cachedOnDisk.file.readAsBytes();
      _putInMemoryCache(key, bytes);
      return bytes;
    }

    final file = await _diskCache.getSingleFile(cacheUrl, headers: headers);
    final bytes = await file.readAsBytes();
    _putInMemoryCache(key, bytes);
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    if (_imageData != null) {
      return Image.memory(
        _imageData!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (ctx, err, stack) {
          return widget.errorBuilder?.call(ctx, err) ?? const SizedBox.shrink();
        },
      );
    }

    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!) ??
          const SizedBox.shrink();
    }

    // Loading state
    return widget.placeholder?.call(context) ?? const SizedBox.shrink();
  }
}
