import 'package:flutter/foundation.dart';

/// A lightweight service that tracks whether any async operation is currently
/// in progress. Any widget can call [setLoading] / [setDone] with a unique
/// string key. The service is "loading" as long as at least one key is active.
///
/// Register in the app's MultiProvider so all widgets can access it.
class LoadingService extends ChangeNotifier {
  final Set<String> _activeKeys = {};

  /// Returns true when at least one operation is still in progress.
  bool get isLoading => _activeKeys.isNotEmpty;

  /// Mark [key] as loading. Multiple calls with the same key are idempotent.
  void setLoading(String key) {
    if (_activeKeys.add(key)) {
      notifyListeners();
    }
  }

  /// Mark [key] as done. No-op if the key was not active.
  void setDone(String key) {
    if (_activeKeys.remove(key)) {
      notifyListeners();
    }
  }
}
