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
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byKey(const Key('ageGateConfirmButton')).evaluate().isNotEmpty) {
      break;
    }
  }

  // Check if we are stuck on the Age Gate
  final ageGateButton = find.byKey(const Key('ageGateConfirmButton'));

  if (ageGateButton.evaluate().isNotEmpty) {
    debugPrint('Age Gate detected — tapping confirm...');
    await tester.tap(ageGateButton);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  } else {
    debugPrint('No Age Gate detected (or already passed).');
  }
}
