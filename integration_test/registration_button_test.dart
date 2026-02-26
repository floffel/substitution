import 'dart:io' as dart_io;
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, effectiveMatrixServer, fastWait, waitForMatrixClient;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Registration Options Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      debugPrint('REGISTRATION: Resetting state...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;

      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;
      
      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final dbFile = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await dbFile.exists()) {
            await dbFile.delete();
          }
        } catch (_) {}
      }
    });

    tearDown(() async {
      debugPrint('REGISTRATION: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets('Login page shows Web Register button after host entry', (tester) async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      final $ = wrapTester(tester);
      app.main();
      
      await waitForMatrixClient($.tester);
      
      // Wait for app to load
      await fastWait($.tester, () => $(Key('hostServerInput')).exists || $(Key('ageGateConfirmButton')).exists);
      
      if ($(Key('ageGateConfirmButton')).exists) {
        await $(Key('ageGateConfirmButton')).tap();
        await $.tester.pumpAndSettle();
      }

      // 1. Enter Host
      debugPrint('REGISTRATION: Entering host URL...');
      final hostInput = $(Key('hostServerInput'));
      await hostInput.waitUntilVisible();
      await hostInput.enterText(effectiveMatrixServer(testMatrixServer));
      await $(Key('hostSubmitButton')).tap();
      await $.tester.pumpAndSettle();

      // 2. Verify Registration button
      debugPrint('REGISTRATION: Waiting for register button...');
      final registerButton = $(Key('registerWebButton'));
      await registerButton.waitUntilVisible(timeout: const Duration(seconds: 30));
      
      expect(registerButton.exists, true);
      debugPrint('✓ REGISTRATION: Web register button found');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
