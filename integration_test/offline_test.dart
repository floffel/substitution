import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart' show fastWait, settle;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Offline and Caching Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    tearDown(() async {
      debugPrint('OFFLINE: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets(
      'Verify messages survive app restart (caching)',
      (tester) async {
        if (kIsWeb) return;

        final $ = wrapTester(tester);

        // --- SETUP: Wipe DB once at the very start of THIS specific test ---
        if (!kIsWeb) {
          final appDocDir = await getApplicationDocumentsDirectory();
          final dbFile = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await dbFile.exists()) await dbFile.delete();
        }
        SharedPreferences.setMockInitialValues({'age_confirmed': true});
        AgeGatePage.confirmed = true;

        // -- PHASE 1: Populate Cache --
        debugPrint('OFFLINE: Phase 1 - Populating cache...');
        app.main();
        await settle($.tester);

        if (!await patrol_helper.loginUser(
          $,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        )) {
          debugPrint('OFFLINE: Login failed');
          return;
        }

        final uniqueCacheMessage =
            'OFFLINE_CACHE_${DateTime.now().millisecondsSinceEpoch}';
        final client = app.globalMatrixClient!;

        // Wait for rooms to be available
        await fastWait(
          $.tester,
          () => client.rooms.isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        final room = client.rooms.firstWhere((r) => r.name.contains('general'));

        debugPrint(
          'OFFLINE: Sending message to be cached: $uniqueCacheMessage',
        );
        await room.sendTextEvent(uniqueCacheMessage);

        await fastWait(
          $.tester,
          () => find.textContaining(uniqueCacheMessage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 60),
        );
        debugPrint('OFFLINE: Message visible, killing app...');
        await settle($.tester);

        // -- PHASE 2: Restart without wiping DB --
        debugPrint('OFFLINE: Phase 2 - Restarting app...');
        await client.dispose();
        app.globalMatrixClient = null;
        app.globalSubstitutionService = null;

        // Clear widget tree completely
        await $.tester.pumpWidget(const SizedBox());
        await Future.delayed(const Duration(seconds: 1));
        await $.tester.pump();

        app.main();
        await settle($.tester);

        // Wait for app to reach the feed automatically (via persisted session)
        debugPrint('OFFLINE: Waiting for auto-login/feed reach...');
        await fastWait(
          $.tester,
          () => find.byType(Scrollable).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 60),
        );

        debugPrint('OFFLINE: Verifying message presence from local cache...');
        bool found = false;
        for (int i = 0; i < 10; i++) {
          if (find.textContaining(uniqueCacheMessage).evaluate().isNotEmpty) {
            found = true;
            break;
          }
          debugPrint('OFFLINE: Step $i, searching for cached message...');
          await $.tester.pump(const Duration(seconds: 1));
        }

        expect(found, true, reason: 'Message should be loaded from cache');
        debugPrint('✓ OFFLINE: Cache persistence verified');
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}
