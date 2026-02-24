import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Stream that emits true when connected, false when disconnected
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .map((result) {
          return !result.contains(ConnectivityResult.none);
        })
        .handleError((Object _) {
          // On Linux CI environments without NetworkManager, DBus calls may fail.
          // Treat as online so tests can proceed.
          return true;
        });
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
