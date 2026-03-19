import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  @override
  State<MxcImage> createState() => _MxcImageState();
}

class _MxcImageState extends State<MxcImage> {
  /// In-memory cache shared across all MxcImage instances.
  static final Map<String, Uint8List> _cache = {};

  Uint8List? _imageData;
  Object? _error;
  bool _loading = false;

  String get _cacheKey {
    final w = widget.width?.toInt() ?? 0;
    final h = widget.height?.toInt() ?? 0;
    return '${widget.uri}|${w}x$h|${widget.isThumbnail}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MxcImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _imageData = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) return;

    // Check memory cache first
    final cached = _cache[_cacheKey];
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

      // Download with auth header
      final response = await http.get(
        httpUri,
        headers: {
          if (widget.client.accessToken != null)
            'authorization': 'Bearer ${widget.client.accessToken}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} loading ${widget.uri}');
      }

      final bytes = response.bodyBytes;

      // Store in memory cache
      _cache[_cacheKey] = bytes;

      if (!mounted) return;
      setState(() {
        _imageData = bytes;
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

  /// Evict a specific URI from the memory cache.
  static void evictUri(Uri uri) {
    _cache.removeWhere((key, _) => key.startsWith('$uri|'));
  }

  /// Clear the entire in-memory image cache.
  static void clearImageCache() => _cache.clear();
}
