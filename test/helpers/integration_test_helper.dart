import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to handle the Age Gate screen if it appears.
///
/// This checks for the existence of the age gate confirmation button.
/// If found, it taps the button and waits for the app to settle.
///
/// Usage in tests:
/// ```dart
/// app.main();
/// await handleAgeGate(tester);
/// ```
Future<void> handleAgeGate(WidgetTester tester) async {
  // Wait for the app to render the first frame(s)
  await tester.pumpAndSettle();

  // Check if we are stuck on the Age Gate
  final ageGateButton = find.byKey(const Key('ageGateConfirmButton'));

  if (ageGateButton.evaluate().isNotEmpty) {
    debugPrint('ℹ Age Gate detected — tapping confirm...');
    await tester.tap(ageGateButton);
    await tester.pumpAndSettle();
  } else {
    debugPrint('ℹ No Age Gate detected (or already passed).');
  }
}
