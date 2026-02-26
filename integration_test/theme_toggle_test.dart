import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:substitution/shared/services/theme_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait, waitUntilNotVisible;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Theme Toggle Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      debugPrint('THEME: Resetting state...');
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

    testWidgets('User can toggle dark mode and see UI changes', (tester) async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      final $ = wrapTester(tester);
      app.main();
      
      if (!await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      )) return;

      // 1. Open Menu
      debugPrint('THEME: Opening menu...');
      await $(Icons.menu).waitUntilVisible();
      await $(Icons.menu).tap();
      await $.tester.pumpAndSettle();

      // 2. Find Dark Mode Switch
      debugPrint('THEME: Toggling switch...');
      final themeTileFinder = find.byType(SwitchListTile);
      await $(themeTileFinder).waitUntilVisible();
      
      final bool initiallyDark = $.tester.widget<SwitchListTile>(themeTileFinder).value;
      debugPrint('THEME: Initially dark: $initiallyDark');

      // 3. Toggle by tapping the text part of the SwitchListTile
      // Tapping the whole tile is usually most reliable for SwitchListTile
      await $.tester.tap(themeTileFinder);
      await $.tester.pumpAndSettle();
      
      // 4. Wait for state change (either via UI or logic)
      debugPrint('THEME: Waiting for state update...');
      await fastWait($.tester, () {
        final currentVal = $.tester.widget<SwitchListTile>(themeTileFinder).value;
        return currentVal == !initiallyDark;
      }, timeout: const Duration(seconds: 10));
      
      expect($.tester.widget<SwitchListTile>(themeTileFinder).value, !initiallyDark);
      debugPrint('✓ THEME: Toggle successful');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
