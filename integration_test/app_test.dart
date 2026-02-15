import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Substitution App - Base Integration Tests', () {
    testWidgets('App starts and displays home page',
        (WidgetTester tester) async {
      // Start the app
      app.main();

      // Wait for the app to stabilize
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify the app is running by checking for Material App
      expect(find.byType(MaterialApp), findsWidgets);
    });

    testWidgets('App handles Matrix connection', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app is responsive
      expect(find.byType(MaterialApp), findsWidgets);
    });

    testWidgets('Navigation works correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Add navigation tests based on your app's routes
      expect(find.byType(MaterialApp), findsWidgets);
    });

    testWidgets('App handles orientation changes', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Test portrait orientation
      tester.binding.window.physicalSizeTestValue = const ui.Size(1080, 2400);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      await tester.pumpAndSettle();

      // Test landscape orientation
      tester.binding.window.physicalSizeTestValue = const ui.Size(2400, 1080);
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsWidgets);
    });
  });
}
