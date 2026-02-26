import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart'
    show skipIfNoMatrix;
import 'helpers/login_helper.dart' as login_helper;

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
      debugPrint('--- tearDown ---');
      await app.globalMatrixClient?.dispose();
      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final dbFile = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await dbFile.exists()) {
            await dbFile.delete();
          }
        } catch (e) {
          debugPrint('Error deleting DB in tearDown: $e');
        }
      }
    });

    testWidgets(
      'Consolidated Logout test: Login -> Logout -> Verify back to intro',
      (WidgetTester tester) async {
        // 1. Setup & Start
        AgeGatePage.confirmed = true;
        app.main();

        // 2. Login
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: 'testuser1',
          password: 'testpass123',
        );

        // 3. Verify logged in (on Feed)
        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('Login success confirmed.');

        // 4. Navigate to Settings
        final settingsIcon = find.byIcon(Icons.settings);
        expect(settingsIcon, findsOneWidget);
        await tester.tap(settingsIcon);
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // 5. Trigger Logout
        final logoutTile = find.byIcon(Icons.logout);
        expect(logoutTile, findsOneWidget);
        await tester.tap(logoutTile);
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // 6. Confirm Logout dialog
        final confirmButton = find.text('Logout');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton.first);
          // Wait for transition back to Intro/Host page
          for (int i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            if (find.byType(IntroductionScreen).evaluate().isNotEmpty) break;
          }
        }

        // Final check for onboarding page content
        expect(find.byType(IntroductionScreen), findsOneWidget);
        debugPrint('Consolidated Logout test passed successfully');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
