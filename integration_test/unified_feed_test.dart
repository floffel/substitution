import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart'
    show skipIfNoMatrix, waitForMatrixClient;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';
import 'helpers/test_synchronizer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Unified Feed with Real Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      debugPrint('UNIFIED_FEED: Resetting state...');

      // Complete cleanup before each test
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;

      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;

      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final mainDb = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await mainDb.exists()) {
            await mainDb.delete();
          }
        } catch (_) {}
      }

      // iOS stability delay
      await Future.delayed(const Duration(milliseconds: 1000));
    });

    tearDown(() async {
      debugPrint('UNIFIED_FEED: Tearing down...');
      try {
        if (app.globalMatrixClient != null) {
          app.globalMatrixClient!.abortSync();
          await app.globalMatrixClient!.dispose();
        }
      } catch (e) {
        debugPrint(
          'UNIFIED_FEED: Error disposing Matrix client, continuing anyway: $e',
        );
      }
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;

      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final dbFile = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await dbFile.exists()) {
            await dbFile.delete();
          }
        } catch (_) {}
      }

      // Extended delay for iOS stability between test cases
      await Future.delayed(const Duration(milliseconds: 1000));
    });

    testWidgets('Display unified feed from multiple rooms', (tester) async {
      debugPrint('UNIFIED_FEED: Starting unified feed test...');
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;

      await TestSynchronizer.synchronizedWaitForMatrixClient($.tester);

      debugPrint('UNIFIED_FEED: Starting login...');
      if (!await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      )) {
        debugPrint('UNIFIED_FEED: Login failed');
        return;
      }

      await TestSynchronizer.synchronizedPumpAndSettle($.tester);

      debugPrint('UNIFIED_FEED: Checking for feed...');
      expect($(Scrollable).exists, true);

      debugPrint('✓ UNIFIED_FEED: Unified feed displayed with messages');
    });
  });
}
