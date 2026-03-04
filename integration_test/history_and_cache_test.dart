import "package:integration_test/integration_test.dart";

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:matrix/matrix.dart';
import 'package:substitution/post/widgets/post.dart';
import 'package:substitution/feed/pages/home.dart';
import 'helpers/integration_test_helper.dart'
    show
        skipIfNoMatrix,
        fastWait,
        effectiveMatrixServer,
        settle,
        waitForSync,
        waitForMatrixClient;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('History and Caching Integration Tests', () {
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

      debugPrint('HISTORY: Resetting state...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;

      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      }
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      debugPrint('HISTORY: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets(
      'Fetch very old messages via pagination',
      (tester) async {
        final $ = wrapTester(tester);

        app.main();
        await waitForMatrixClient($.tester);

        debugPrint('HISTORY: Logging in...');
        if (!await patrol_helper.loginUser(
          $,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        )) {
          debugPrint('HISTORY: Login failed');
          return;
        }
        debugPrint('HISTORY: Login successful');

        // 1. Create a dedicated room for history testing
        debugPrint('HISTORY: Creating room...');
        final client = app.globalMatrixClient!;
        final service = app.globalSubstitutionService!;
        final roomName = 'History Test Room';

        final roomId = await client
            .createRoom(
              name: roomName,
              preset: CreateRoomPreset.publicChat,
              powerLevelContentOverride: {'users_default': 50},
            )
            .timeout(const Duration(seconds: 60));

        debugPrint(
          'HISTORY: Room created: $roomId. Waiting for SDK to catch up...',
        );
        await fastWait($.tester, () => client.getRoomById(roomId) != null);

        debugPrint('HISTORY: Marking room as substitution...');
        service.addRoomId(roomId);
        await client
            .setAccountDataPerRoom(client.userID!, roomId, "substitution", {
              "joined": true,
            })
            .timeout(const Duration(seconds: 30));

        debugPrint(
          'HISTORY: Triggering refresh and waiting for room discovery...',
        );
        service.triggerRefresh();

        // Wait for HomePage to pick up the 6th room
        await fastWait($.tester, () {
          final homeState = $.tester.state<HomePageState>(
            find.byType(HomePage),
          );
          return homeState.currentRoomIds.length >= 6;
        }, timeout: const Duration(seconds: 30));
        debugPrint(
          'HISTORY: HomePage discovered the new room. Current rooms: 6',
        );
        await settle($.tester);

        final room = client.getRoomById(roomId)!;

        // 2. Seed many messages to force pagination
        debugPrint('HISTORY: Seeding messages...');
        final oldestMessageBody = 'OLDEST_MESSAGE_STAY_HERE';
        final newestMessageBody = 'NEWEST_MESSAGE_TOP';

        await room
            .sendTextEvent(oldestMessageBody)
            .timeout(const Duration(seconds: 30));
        debugPrint('HISTORY: Sent oldest message');

        for (int i = 1; i <= 20; i++) {
          await room
              .sendTextEvent('Filler message $i')
              .timeout(const Duration(seconds: 10));
          if (i % 5 == 0) debugPrint('HISTORY: Sent $i/20...');
        }

        await room
            .sendTextEvent(newestMessageBody)
            .timeout(const Duration(seconds: 30));
        debugPrint('HISTORY: Sent newest message. Waiting for sync...');

        // Wait for sync to pick up all messages
        await waitForSync($.tester, timeout: const Duration(seconds: 60));

        debugPrint('HISTORY: Waiting for newest message to appear in UI...');
        await fastWait(
          $.tester,
          () => find.textContaining(newestMessageBody).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 60),
        );
        debugPrint('HISTORY: Newest message found in UI');

        // 3. Scroll to find the oldest message
        debugPrint('HISTORY: Starting scroll sequence...');
        final scrollableFinder = find.byType(Scrollable).first;

        bool foundOldest = false;
        for (int i = 0; i < 100; i++) {
          final postWidgets =
              find
                  .byType(PostWidget)
                  .evaluate()
                  .map((e) => e.widget as PostWidget)
                  .toList();

          debugPrint(
            'HISTORY: Step $i, searching for $oldestMessageBody. Visible: ${postWidgets.length} posts',
          );

          for (final post in postWidgets) {
            if (post.displayEvent.body.contains(oldestMessageBody)) {
              foundOldest = true;
              debugPrint(
                '✓ HISTORY: Found oldest message in visible widgets at step $i',
              );
              break;
            }
          }

          if (foundOldest) break;

          // Fling is often more effective than drag for triggering PagedListView updates
          await $.tester.fling(scrollableFinder, const Offset(0, -1000), 2000);
          await $.tester.pump();
          // Wait for momentum and lazy loading
          await $.tester.pump(const Duration(milliseconds: 200));
          await $.tester.pump();
        }

        expect(
          foundOldest,
          true,
          reason:
              'The oldest message should eventually be fetched and displayed',
        );
        debugPrint(
          '✓ HISTORY: Successfully fetched old messages via pagination',
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}
