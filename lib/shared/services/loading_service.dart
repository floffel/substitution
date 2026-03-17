import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A lightweight service that tracks whether any async operation is currently
/// in progress. Any widget can call [setLoading] / [setDone] with a unique
/// string key. The service is "loading" as long as at least one key is active.
///
/// Register in the app's MultiProvider so all widgets can access it.
class LoadingService extends ChangeNotifier {
  final Set<String> _activeKeys = {};
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// Returns true when at least one operation is still in progress.
  bool get isLoading => _activeKeys.isNotEmpty;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Safely notify listeners. If called during a build/layout phase, the
  /// notification is deferred to a post-frame callback to avoid the
  /// "setState() or markNeedsBuild() called during build" error.
  void _safeNotify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      // We are inside the build/layout phase – defer the notification.
      if (!_notifyScheduled) {
        _notifyScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyScheduled = false;
          // Guard against disposal between scheduling and firing.
          if (!_disposed) notifyListeners();
        });
      }
    } else {
      notifyListeners();
    }
  }

  /// Mark [key] as loading. Multiple calls with the same key are idempotent.
  void setLoading(String key) {
    if (_activeKeys.add(key)) {
      _safeNotify();
    }
  }

  /// Mark [key] as done. No-op if the key was not active.
  void setDone(String key) {
    if (_activeKeys.remove(key)) {
      _safeNotify();
    }
  }
}
