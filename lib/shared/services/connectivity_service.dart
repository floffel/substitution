import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  // Lazily-initialised broadcast stream that never throws.
  // On Linux CI without NetworkManager the DBus call inside
  // ConnectivityPlusLinuxPlugin._startListenConnectivity throws a
  // DBusServiceUnknownException.  We catch it here and substitute an
  // infinite stream that always reports "online".
  Stream<bool>? _cachedStream;

  /// Stream that emits true when connected, false when disconnected.
  Stream<bool> get onConnectivityChanged {
    _cachedStream ??= _buildStream();
    return _cachedStream!;
  }

  Stream<bool> _buildStream() {
    try {
      return _connectivity.onConnectivityChanged
          .map((result) => !result.contains(ConnectivityResult.none))
          .handleError((Object e) {
            debugPrint('ConnectivityService: stream error: $e');
            // Returning nothing from handleError suppresses the error and
            // keeps the stream alive.
          });
    } catch (e) {
      // ConnectivityPlusLinuxPlugin may throw synchronously when DBus is
      // unavailable (e.g. Linux CI runners without NetworkManager).
      debugPrint('ConnectivityService: failed to init connectivity stream: $e');
      // Return a stream that never emits (i.e. always "online").
      return const Stream<bool>.empty();
    }
  }

  /// Check current connectivity status
  Future<bool> get isOnline async {
    try {
      final result = await _connectivity.checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      // On Linux environments without NetworkManager (e.g. CI), connectivity
      // checks via DBus may fail. Default to online.
      debugPrint('ConnectivityService: failed to check connectivity: $e');
      return true;
    }
  }
}
