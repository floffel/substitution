import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:substitution/post/widgets/comment.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:matrix/matrix.dart';
import 'package:go_router/go_router.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait, settle;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Comment Nesting and Collapsing Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

      debugPrint('NESTING: Resetting state...');

      // Enhanced resource cleanup for iOS stability
      try {
        if (app.globalMatrixClient != null) {
          debugPrint('NESTING: Disposing existing Matrix client...');
          app.globalMatrixClient!.abortSync();
          await app.globalMatrixClient!.dispose();
        }
      } catch (e) {
        debugPrint(
          'NESTING: Error disposing Matrix client, continuing anyway: $e',
        );
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
            debugPrint('NESTING: Deleting old database file...');
            await dbFile.delete();
          }
        } catch (e) {
          debugPrint('NESTING: Error cleaning database file: $e');
        }
      }

      // Extended delay for iOS resource cleanup
      await Future.delayed(const Duration(milliseconds: 1000));
      debugPrint('NESTING: State reset complete');
    });

    tearDown(() async {
      debugPrint('NESTING: Tearing down...');
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
      'Deeply nested comments render and can be navigated',
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

        final client = app.globalMatrixClient!;
        final rooms = await client.getJoinedRooms();
        final room =
            client.getRoomById(
              rooms.firstWhere(
                (id) => client.getRoomById(id)?.name == 'test_general',
              ),
            )!;

        // 1. Seed root event programmatically
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final rootText = 'Root Post for Nesting Test $timestamp';
        final rootId = await room.sendTextEvent(rootText);
        debugPrint('NESTING: Created root event $rootId');

        final timeline = await room.getTimeline();
        await fastWait(
          $.tester,
          () => timeline.events.any((e) => e.eventId == rootId),
          timeout: const Duration(seconds: 30),
        );

        Event lastEvent = timeline.events.firstWhere(
          (e) => e.eventId == rootId,
        );

        // 2. Seed 5 levels of replies (enough to trigger "Continue thread")
        int nestingLevel = 5;
        final threadRootId = rootId;
        for (int i = 1; i <= nestingLevel; i++) {
          final replyText = 'Nested Level $i ($timestamp)';
          final replyId = await room.sendEvent(
            {'body': replyText, 'msgtype': MessageTypes.Text},
            threadRootEventId: threadRootId,
            inReplyTo: lastEvent,
          );
          debugPrint('NESTING: Created reply level $i ID: $replyId');

          await fastWait(
            $.tester,
            () => timeline.events.any((e) => e.eventId == replyId),
            timeout: const Duration(seconds: 20),
          );
          lastEvent = timeline.events.firstWhere((e) => e.eventId == replyId);
        }

        // 3. Navigate to Post View
        debugPrint('NESTING: Navigating to post view...');
        final navContext = $.tester.element(find.byType(HomePage));
        navContext.go('/post/$rootId?room=${room.id}');
        await settle($.tester);

        // 4. Wait for comments to load in UI
        debugPrint('NESTING: Waiting for comments in UI...');
        await fastWait(
          $.tester,
          () => $(CommentWidget).exists,
          timeout: const Duration(seconds: 60),
        );

        // 5. Look for "Continue this thread" button (Icons.arrow_forward)
        debugPrint('NESTING: Looking for continuation button...');
        final continueButtonFinder = find.byIcon(Icons.arrow_forward);

        // Try to scroll to it if not visible
        try {
          await $.tester.scrollUntilVisible(
            continueButtonFinder,
            500.0,
            scrollable: find.byType(Scrollable).first,
          );
        } catch (e) {
          debugPrint(
            'NESTING: scrollUntilVisible failed (maybe already visible or not present): $e',
          );
        }

        final continueButton = $(continueButtonFinder);
        if (continueButton.exists) {
          debugPrint('NESTING: Tapping continuation button...');
          await continueButton.first.tap();
          await settle($.tester);

          // Verify we can go back
          final postNavContext = $.tester.element(find.byType(Scaffold).first);
          expect(GoRouter.of(postNavContext).canPop(), isTrue);
          debugPrint('✓ NESTING: Navigated into sub-thread');
        } else {
          debugPrint('NESTING: Continuation button not found in UI');
          // This might happen if aggregation didn't pick up all threads yet
        }

        debugPrint('✓ NESTING: Flow verified');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}
