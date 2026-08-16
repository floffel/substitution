import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/settings/pages/followfeeds.dart';
import 'package:substitution/shared/widgets/roomwidget.dart';
import 'helpers/integration_test_helper.dart'
    show skipIfNoMatrix, fastWait, settle;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Room Discovery Strict Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

      debugPrint('DISCOVERY_STRICT: Resetting state...');
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
      debugPrint('DISCOVERY_STRICT: Tearing down...');
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
      'STRICT: Discovery page loads and shows seeded rooms',
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

        // 1. Navigate to Discover tab via bottom navigation
        debugPrint('DISCOVERY_STRICT: Tapping Discover tab...');
        await $.tester.tap(find.byIcon(Icons.explore_outlined));
        await settle($.tester);

        // 2. Verify page content
        expect($(FollowFeedSettings).exists, true);

        // 3. Wait for rooms to appear (seeded data)
        debugPrint('DISCOVERY_STRICT: Waiting for room list...');
        await fastWait(
          $.tester,
          () => $(RoomWidget).evaluate().length >= 3,
          timeout: const Duration(seconds: 60),
        );

        final roomCount = $(RoomWidget).evaluate().length;
        expect(
          roomCount >= 3,
          true,
          reason: 'MUST show at least 3 pre-joined rooms',
        );
        debugPrint('✓ DISCOVERY_STRICT: Found $roomCount rooms in list');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );

    testWidgets(
      'STRICT: Search filters the room list correctly',
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

        // 1. Navigate to Discover tab via bottom navigation
        await $.tester.tap(find.byIcon(Icons.explore_outlined));
        await settle($.tester);

        // 2. Wait for initial list
        await fastWait($.tester, () => $(RoomWidget).exists);
        final initialCount = $(RoomWidget).evaluate().length;

        // 3. Enter unique search term
        debugPrint('DISCOVERY_STRICT: Searching for test_art...');
        await $(TextField).first.enterText('test_art');
        await settle($.tester);

        // 4. Wait for filtered results
        await fastWait($.tester, () {
          final count = $(RoomWidget).evaluate().length;
          // Search should narrow down the list
          return count > 0 && count < initialCount;
        }, timeout: const Duration(seconds: 60));

        expect($(find.textContaining('test_art')).exists, true);
        expect($(find.textContaining('test_general')).exists, false);

        debugPrint('✓ DISCOVERY_STRICT: Search filtering verified');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}
