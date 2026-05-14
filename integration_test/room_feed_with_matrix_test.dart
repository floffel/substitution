import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/post/widgets/post.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:patrol/patrol.dart';
import 'package:go_router/go_router.dart';

import 'helpers/integration_test_helper.dart'
    show skipIfNoMatrix, fastWait, effectiveMatrixServer, settle;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Individual Room Feed Integration Test', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(
        matrixServer: effectiveMatrixServer(testMatrixServer),
      )) {
        return;
      }

      debugPrint('ROOM_FEED: Resetting state...');
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
      debugPrint('ROOM_FEED: Tearing down...');
      try {
        app.globalMatrixClient?.abortSync();
        await app.globalMatrixClient?.dispose();
      } catch (e) {
        debugPrint('TEST: Matrix client cleanup warning: $e');
      }
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    // Helper to wait for the feed to be truly ready with content
    Future<void> waitForFeedReady(PatrolIntegrationTester $) async {
      debugPrint('ROOM_FEED: Waiting for logic state (rooms)...');
      await fastWait(
        $.tester,
        () =>
            app.globalSubstitutionService?.roomCount != null &&
            app.globalSubstitutionService!.roomCount > 0,
      );

      debugPrint('ROOM_FEED: Waiting for UI state (PostWidget)...');
      await fastWait(
        $.tester,
        () => find.byType(PostWidget).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 180),
      );

      await settle($.tester);
    }

    testWidgets(
      'Can navigate to individual room feed and see only that room\'s posts',
      (tester) async {
        if (!await skipIfNoMatrix(
          matrixServer: effectiveMatrixServer(testMatrixServer),
        )) {
          return;
        }

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

        await waitForFeedReady($);

        final client = app.globalMatrixClient!;
        final rooms = await client.getJoinedRooms();
        // Find 'test_general' room ID from the seeded data
        final testGeneralRoomId = rooms.firstWhere(
          (id) => client.getRoomById(id)?.name == 'test_general',
        );

        debugPrint(
          'ROOM_FEED: Navigating to test_general ($testGeneralRoomId)...',
        );

        // Programmatic navigation using GoRouter
        final navContext = $.tester.element(find.byType(HomePage));
        navContext.go('/feed/$testGeneralRoomId');
        await settle($.tester);

        // Wait for room-specific content
        await fastWait(
          $.tester,
          () => find.byType(PostWidget).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 60),
        );

        // Verify that all visible posts belong to test_general
        final postWidgets =
            find
                .byType(PostWidget)
                .evaluate()
                .map((e) => e.widget as PostWidget)
                .toList();
        for (final post in postWidgets) {
          expect(
            post.event.roomId,
            testGeneralRoomId,
            reason: 'Should only show posts from $testGeneralRoomId',
          );
        }

        // Verify that we are NOT seeing messages from other rooms via state check
        final homeState = $.tester.state<HomePageState>(find.byType(HomePage));
        final roomIds = homeState.currentRoomIds;
        expect(
          roomIds.length,
          1,
          reason: 'Should only track 1 room in individual feed mode',
        );
        expect(roomIds.first, testGeneralRoomId);

        debugPrint('✓ ROOM_FEED: Verified room-specific filtering');
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}
