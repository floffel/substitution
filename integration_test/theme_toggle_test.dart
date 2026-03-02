import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/shared/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:integration_test/integration_test.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
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

    testWidgets(
      'User can toggle dark mode and see UI changes',
      (tester) async {
        if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

        final $ = wrapTester(tester);
        app.main();

        if (!await patrol_helper.loginUser(
          $,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        )) {
          return;
        }

        // 1. Open Menu
        debugPrint('THEME: Opening menu...');
        await $(Icons.menu).waitUntilVisible();
        await $(Icons.menu).tap();
        await $.tester.pumpAndSettle();

        // 2. Find ThemeService by searching all elements
        debugPrint('THEME: Searching for ThemeService...');

        ThemeService? themeService;
        void findProvider(Element element) {
          if (themeService != null) return;
          try {
            themeService = Provider.of<ThemeService>(element, listen: false);
          } catch (_) {
            element.visitChildren(findProvider);
          }
        }

        $.tester.allElements.forEach(findProvider);

        if (themeService == null) {
          throw Exception("Could not find ThemeService in widget tree");
        }

        final bool initiallyDark = themeService!.themeMode == ThemeMode.dark;
        debugPrint('THEME: Initially dark (logic): $initiallyDark');

        // 3. Toggle by tapping the switch tile
        debugPrint('THEME: Tapping switch tile...');
        final themeTile = $(find.text('Dark Mode'));
        await themeTile.waitUntilVisible();
        await themeTile.tap();

        // 4. Wait for logic state change
        debugPrint('THEME: Waiting for logic state update...');
        await fastWait(
          $.tester,
          () =>
              themeService!.themeMode ==
              (initiallyDark ? ThemeMode.light : ThemeMode.dark),
        );

        expect(
          themeService!.themeMode,
          initiallyDark ? ThemeMode.light : ThemeMode.dark,
        );
        debugPrint('✓ THEME: Toggle successful');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}
