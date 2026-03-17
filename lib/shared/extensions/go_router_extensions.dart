import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension GoRouterPushIfNew on BuildContext {
  /// Pushes [location] only if it differs from the currently active route.
  ///
  /// This prevents duplicate history entries when the user taps a link that
  /// points to the page they are already viewing (e.g. tapping the same profile
  /// avatar twice in a row, or tapping a feed link while already on that feed).
  void pushIfNew(String location, {Object? extra}) {
    final current = GoRouterState.of(this).uri.toString();
    if (current != location) {
      push(location, extra: extra);
    }
  }
}
