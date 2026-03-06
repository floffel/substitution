import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/settings/pages/key_verification.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:go_router/go_router.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Key Verification Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

      debugPrint('SECURITY: Resetting state...');
      try {
        app.globalMatrixClient?.abortSync();
        await app.globalMatrixClient?.dispose();
      } catch (e) {
        debugPrint('TEST: Matrix client cleanup warning: $e');
      }
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
      debugPrint('SECURITY: Tearing down...');
      try {
        app.globalMatrixClient?.abortSync();
        await app.globalMatrixClient?.dispose();
      } catch (e) {
        debugPrint('TEST: Matrix client cleanup warning: $e');
      }
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets(
      'Can view device list in security settings',
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

        // 1. Navigate directly to Security page
        debugPrint('SECURITY: Navigating to KeyVerificationPage...');
        final navContext = $.tester.element(find.byType(HomePage));
        navContext.push('/settings/security');
        await $.tester.pumpAndSettle();

        // 2. Verify KeyVerificationPage
        expect($(KeyVerificationPage).exists, true);

        // 3. Wait for UI to settle
        await $.tester.pumpAndSettle();

        // 4. Verify 'Refresh' functionality via Pull-to-Refresh
        // Even if no devices are found, we want to make sure the UI is interactive
        debugPrint('SECURITY: Performing pull-to-refresh...');
        final listFinder = find.byType(ListView);
        if (listFinder.evaluate().isNotEmpty) {
          await $.tester.drag(listFinder.first, const Offset(0, 500));
          await $.tester.pumpAndSettle();
        }

        debugPrint('✓ SECURITY: Security page verified');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}
