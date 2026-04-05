import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Tracks which Matrix spec versions the user's homeserver supports, so the
/// app can decide whether optimised endpoints like `timestamp_to_event`
/// (Matrix spec v1.6+) are available.
///
/// Background: the global feed merges posts across multiple rooms
/// newest-first. With many rooms and temporal gaps, efficient pagination
/// requires `GET /_matrix/client/v1/rooms/{roomId}/timestamp_to_event`
/// (added in v1.6) to skip over gaps without making dozens of
/// `requestHistory` calls. If the user's homeserver doesn't support v1.6,
/// the feed still works but uses the slower `requestHistory` fallback
/// per-room.
///
/// This service queries `/_matrix/client/versions` at startup and caches
/// the result. Individual rooms on federated servers are served via the
/// user's own homeserver (which proxies federation), so only the user's
/// own server version matters for this decision.
class MatrixServerCapabilities extends ChangeNotifier {
  MatrixServerCapabilities(this._client);

  final Client _client;

  /// Supported spec versions reported by the user's own homeserver.
  Set<String> _supportedVersions = const {};

  /// Whether the versions query has completed (success or failure).
  bool _loaded = false;

  /// The minimum Matrix spec version required for the optimised pagination
  /// path (timestamp_to_event was added in v1.6).
  static const String optimisedFeedMinVersion = 'v1.6';

  bool get isLoaded => _loaded;

  Set<String> get supportedVersions => _supportedVersions;

  /// `true` iff the user's own homeserver supports `timestamp_to_event`.
  bool get supportsTimestampToEvent =>
      _meetsVersion(_supportedVersions, optimisedFeedMinVersion);

  /// Parses a spec version string like 'v1.6' or 'r0.5.0' into a comparable
  /// tuple. Unrecognised formats sort as oldest.
  static List<int> _parseVersion(String v) {
    final match = RegExp(r'[vr](\d+)\.(\d+)(?:\.(\d+))?').firstMatch(v);
    if (match == null) return [0, 0, 0];
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.tryParse(match.group(3) ?? '0') ?? 0,
    ];
  }

  /// Compares two version strings.
  static int compareVersions(String a, String b) {
    final pa = _parseVersion(a);
    final pb = _parseVersion(b);
    for (int i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i] - pb[i];
    }
    return 0;
  }

  static bool _meetsVersion(Set<String> supported, String required) {
    for (final v in supported) {
      if (compareVersions(v, required) >= 0) return true;
    }
    return false;
  }

  /// Extracts the homeserver hostname from a Matrix ID (`@user:host`,
  /// `!room:host`, etc).
  static String? homeserverOfId(String mxid) {
    final idx = mxid.lastIndexOf(':');
    if (idx < 0 || idx == mxid.length - 1) return null;
    return mxid.substring(idx + 1);
  }

  /// Fetches and caches the supported spec versions. Safe to call multiple
  /// times; only issues a network request on the first call.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final resp = await _client.getVersions();
      _supportedVersions = resp.versions.toSet();
    } catch (e) {
      debugPrint('MatrixServerCapabilities: getVersions failed: $e');
      _supportedVersions = const {};
    }
    _loaded = true;
    notifyListeners();
  }

  /// Clears cached state (call on logout).
  void clear() {
    _supportedVersions = const {};
    _loaded = false;
    notifyListeners();
  }
}
