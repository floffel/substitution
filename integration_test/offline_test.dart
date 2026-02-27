import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'helpers/integration_test_helper.dart' show fastWait;
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

    // We do NOT wipe the database in setUp for the caching test
    // to verify persistence.

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

        // -- PHASE 1: Populate Cache --
        debugPrint('OFFLINE: Phase 1 - Populating cache...');
        app.main();

        if (!await patrol_helper.loginUser(
          $,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        )) {
          return;
        }

        final uniqueCacheMessage =
            'OFFLINE_CACHE_${DateTime.now().millisecondsSinceEpoch}';
        final client = app.globalMatrixClient!;
        final rooms = await client.getJoinedRooms();
        final room = client.getRoomById(rooms.first)!;

        debugPrint('OFFLINE: Sending message to be cached...');
        await room.sendTextEvent(uniqueCacheMessage);

        await fastWait(
          $.tester,
          () => find.textContaining(uniqueCacheMessage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 60),
        );
        debugPrint('OFFLINE: Message visible, killing app...');

        // -- PHASE 2: Restart without wiping DB --
        await client.dispose();
        app.globalMatrixClient = null;
        app.globalSubstitutionService = null;
        await Future.delayed(const Duration(seconds: 1));

        debugPrint('OFFLINE: Phase 2 - Restarting app...');
        app.main();

        // Wait for app to reach the feed automatically (via persisted session)
        await fastWait(
          $.tester,
          () => $(Scrollable).exists,
          timeout: const Duration(seconds: 60),
        );

        // Trigger logic refresh to load from store
        if (app.globalSubstitutionService != null) {
          app.globalSubstitutionService!.triggerRefresh();
        }
        await $.tester.pumpAndSettle();

        debugPrint('OFFLINE: Verifying message presence from local cache...');
        await fastWait($.tester, () {
          return find
              .textContaining(uniqueCacheMessage, skipOffstage: false)
              .evaluate()
              .isNotEmpty;
        }, timeout: const Duration(seconds: 60));

        expect($(find.textContaining(uniqueCacheMessage)).exists, true);
        debugPrint('✓ OFFLINE: Cache persistence verified');
      },
      timeout: const Timeout(Duration(minutes: 7)),
    );
  });
}
