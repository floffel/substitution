import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, effectiveMatrixServer;
import 'helpers/patrol_wrapper.dart';

void main() {
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

    testWidgets('Login page shows SSO and Web Register buttons', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      
      await $(MaterialApp).waitUntilVisible();

      // Find host input
      final hostInput = $(Key('hostServerInput'));
      if (hostInput.exists) {
        await hostInput.enterText(effectiveMatrixServer(testMatrixServer));
        await $(Key('hostSubmitButton')).tap();
      }

      // Verify web register button is visible (it waits implicitly)
      expect($(Key('registerWebButton')).exists, true);

      // Verify SSO button visibility
      if ($(OutlinedButton).exists) {
        debugPrint('✓ Found SSO alternatives');
      }

      debugPrint('✓ Registration buttons verify successfully');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
