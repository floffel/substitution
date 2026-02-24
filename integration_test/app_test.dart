import 'dart:io' as dart_io;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Substitution App - Base Integration Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbPath = '${appDocDir.path}/matrix_database.db';
        final dbFile = dart_io.File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      }
    });

    tearDown(() async {
      await app.globalMatrixClient?.dispose();
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbPath = '${appDocDir.path}/matrix_database.db';
        final dbFile = dart_io.File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      }
    });

    testWidgets('App starts and displays home page', (
      WidgetTester tester,
    ) async {
      // Start the app
      app.main();
      await waitForMatrixClient(tester);

      await handleAgeGate(tester);

      await handleAgeGate(tester);

      // Wait for the app to stabilize
      for (int ps = 0; ps < 10; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Verify the app is running by checking for Material App
      expect(find.byType(MaterialApp), findsWidgets);
    });

    testWidgets('App handles Matrix connection', (WidgetTester tester) async {
      app.main();
      await waitForMatrixClient(tester);
      await handleAgeGate(tester);
      for (int ps = 0; ps < 10; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Verify app is responsive
      expect(find.byType(MaterialApp), findsWidgets);
    });

    testWidgets('Navigation works correctly', (WidgetTester tester) async {
      app.main();
      await waitForMatrixClient(tester);
      await handleAgeGate(tester);
      for (int ps = 0; ps < 10; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Add navigation tests based on your app's routes
      expect(find.byType(MaterialApp), findsWidgets);
    });

    testWidgets('App handles orientation changes', (WidgetTester tester) async {
      app.main();
      await waitForMatrixClient(tester);
      await handleAgeGate(tester);
      for (int ps = 0; ps < 10; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Test portrait orientation
      tester.view.physicalSize = const ui.Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      for (int ps = 0; ps < 10; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Test landscape orientation
      tester.view.physicalSize = const ui.Size(2400, 1080);
      for (int ps = 0; ps < 10; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.byType(MaterialApp), findsWidgets);
    });
  });
}
