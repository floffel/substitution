import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/shared/services/loading_service.dart';

/// A thin loading indicator bar that sits at the very top of the page content
/// (just below the AppBar). It is **always** allocated the same 3 px of height
/// so it never causes a layout shift.
///
/// - While loading : shows an animated indeterminate [LinearProgressIndicator].
/// - When done     : fades to fully transparent via [AnimatedOpacity].
///
/// The [LinearProgressIndicator] is only present in the tree while loading,
/// which prevents its continuous animation from blocking [pumpAndSettle] in
/// widget tests.
class TopLoadingBar extends StatelessWidget {
  const TopLoadingBar({super.key});

  static const double barHeight = 3.0;
  static const Duration _fadeDuration = Duration(milliseconds: 400);

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<LoadingService, bool>(
      (svc) => svc.isLoading,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: barHeight,
      child: AnimatedOpacity(
        opacity: isLoading ? 1.0 : 0.0,
        duration: _fadeDuration,
        // Only put the animating widget in the tree while loading so that
        // WidgetTester.pumpAndSettle() can settle once loading is done.
        child:
            isLoading
                ? LinearProgressIndicator(
                  backgroundColor: colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                )
                : const SizedBox.expand(),
      ),
    );
  }
}
