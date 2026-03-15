import "package:integration_test/integration_test.dart";
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Simple iOS Test', () {
    setUp(() async {
      // Just basic setup
    });

    testWidgets('Basic iOS app startup', (tester) async {
      // Just check if app can start without crashing
      app.main();

      // Pump several frames instead of pumpAndSettle (which can hang
      // indefinitely if the app has background timers, e.g. Matrix reconnects)
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Basic expectation
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
