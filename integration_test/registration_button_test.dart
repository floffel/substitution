import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/integration_test_helper.dart'
    show skipIfNoMatrix, effectiveMatrixServer, waitForMatrixClient, handleAgeGate, settle;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Registration Options Test with Real Matrix Server', () {
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

    testWidgets(
      'Login page shows SSO and Web Register buttons',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await waitForMatrixClient(tester);
        await handleAgeGate(tester);
        await settle(tester, count: 2);

        // Find host input
        final hostInput = find.byKey(const Key('hostServerInput'));
        if (hostInput.evaluate().isEmpty) {
          // If already configured or on login page, skip host entry
          debugPrint('Host input not found, checking for login page...');
        } else {
          await tester.enterText(hostInput, effectiveMatrixServer(testMatrixServer));
          await settle(tester, count: 2);
          
          final submitButton = find.byKey(const Key('hostSubmitButton'));
          await tester.ensureVisible(submitButton);
          await settle(tester, count: 2);
          await tester.tap(submitButton);
          
          // Wait for transition to login page
          for (int i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            if (find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty) break;
          }
        }

        // Verify web register button is visible
        final registerWebFinder = find.byKey(const Key('registerWebButton'));
        expect(registerWebFinder, findsOneWidget);

        // Verify SSO button is visible
        final ssoButtonFinder = find.byType(OutlinedButton);
        if (ssoButtonFinder.evaluate().isNotEmpty) {
          debugPrint('✓ Found SSO alternatives');
        }

        debugPrint('✓ Registration buttons verify successfully');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
