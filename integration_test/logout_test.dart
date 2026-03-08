import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Logout Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
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
      // Dispose the Matrix client cleanly.
      // DB deletion is intentionally omitted here: deleting the file
      // immediately after dispose() races with Sqflite's internal WAL flush,
      // causing a spurious SqfliteDatabaseException after the test has already
      // passed. The setUp above deletes the DB before each test run instead.
      try {
        app.globalMatrixClient?.abortSync();
        await app.globalMatrixClient?.dispose();
      } catch (e) {
        debugPrint('TEST: Matrix client cleanup warning: $e');
      }
      app.globalMatrixClient = null;
    });

    testWidgets(
      'Consolidated Logout test: Login -> Logout -> Verify back to intro',
      (tester) async {
        final $ = wrapTester(tester);
        AgeGatePage.confirmed = true;
        app.main();

        final loggedIn = await patrol_helper.loginUser(
          $,
          matrixServer: testMatrixServer,
          username: 'testuser1',
          password: 'testpass123',
        );
        if (!loggedIn) return;

        debugPrint('Login success confirmed.');

        // Navigate to Menu
        await $(Icons.menu).waitUntilVisible();
        await $(Icons.menu).tap();
        for (int i = 0; i < 10; i++) {
          await $.tester.pump(const Duration(milliseconds: 300));
        }

        // Trigger Logout
        await $(Icons.logout).tap();

        // Confirm Logout dialog
        final confirmButton = $(find.text('Logout'));
        if (confirmButton.exists) {
          await confirmButton.tap();
          await $(IntroductionScreen).waitUntilVisible();
        }

        expect($(IntroductionScreen).exists, true);
        debugPrint('Consolidated Logout test passed successfully');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}
