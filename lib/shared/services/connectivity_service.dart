import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  // On Linux, connectivity_plus uses DBus / NetworkManager which may not be
  // available in CI environments.  The plugin throws DBusServiceUnknownException
  // asynchronously from within its zone when you subscribe to the stream, and
  // Flutter's test framework surfaces that as a test failure.  To avoid this we
  // skip real connectivity monitoring on Linux and always report "online".
  static bool get _linuxWithoutNetworkManager =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Stream that emits true when connected, false when disconnected.
  /// On Linux, returns an empty stream (always "online").
  Stream<bool> get onConnectivityChanged {
    if (_linuxWithoutNetworkManager) {
      return const Stream<bool>.empty();
    }
    return _connectivity.onConnectivityChanged
        .map((result) => !result.contains(ConnectivityResult.none))
        .handleError((Object e) {
          debugPrint('ConnectivityService: stream error: $e');
        });
  }

  /// Check current connectivity status.
  /// On Linux without NetworkManager, defaults to online.
  Future<bool> get isOnline async {
    if (_linuxWithoutNetworkManager) {
      return true;
    }
    try {
      final result = await _connectivity.checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('ConnectivityService: failed to check connectivity: $e');
      return true;
    }
  }
}
