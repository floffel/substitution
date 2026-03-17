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
import 'package:substitution/settings/widgets/roomwidget.dart';
import 'package:substitution/settings/widgets/sheet_room_preview.dart';
import 'package:matrix/matrix.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Discovery Flow Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      debugPrint('DISCOVERY: Resetting state...');

      // Enhanced resource cleanup for iOS stability
      try {
        if (app.globalMatrixClient != null) {
          debugPrint('DISCOVERY: Disposing existing Matrix client...');
          app.globalMatrixClient!.abortSync();
          await app.globalMatrixClient!.dispose();
        }
      } catch (e) {
        debugPrint(
          'DISCOVERY: Error disposing Matrix client, continuing anyway: $e',
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
            debugPrint('DISCOVERY: Deleting old database file...');
            await dbFile.delete();
          }
        } catch (e) {
          debugPrint('DISCOVERY: Error cleaning database file: $e');
        }
      }

      // Extended delay for iOS resource cleanup
      await Future.delayed(const Duration(milliseconds: 1000));
      debugPrint('DISCOVERY: State reset complete');
    });

    tearDown(() async {
      debugPrint('DISCOVERY: Tearing down...');
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
      'Navigate to follow feeds and search rooms',
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

        // Navigate to Discover tab via bottom navigation
        debugPrint('DISCOVERY: Tapping Discover tab...');
        await $.tester.tap(find.byIcon(Icons.explore_outlined));
        await $.tester.pumpAndSettle();

        // 3. Verify FollowFeedSettings is visible in the Discover tab
        expect($(FollowFeedSettings).exists, true);

        // 4. Search for 'test_art' (seeded room)
        debugPrint('DISCOVERY: Searching for test_art...');
        final searchInput = $(TextField).first;
        await searchInput.enterText('test_art');
        await $.tester.pumpAndSettle();

        // 5. Wait for results (network call to queryPublicRooms)
        debugPrint('DISCOVERY: Waiting for search results...');
        await fastWait(
          $.tester,
          () => $(RoomWidget).exists,
          timeout: const Duration(seconds: 60),
        );

        expect($(find.textContaining('test_art')).exists, true);
        debugPrint('✓ DISCOVERY: Search results verified');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );

    testWidgets(
      'Join and Leave a room from discovery',
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

        // Ensure test_photos is NOT joined
        final rooms = await client.getJoinedRooms();
        final photoRoomId = rooms.firstWhere(
          (id) => client.getRoomById(id)?.name == 'test_photos',
          orElse: () => '',
        );

        if (photoRoomId.isNotEmpty) {
          debugPrint(
            'DISCOVERY: Leaving test_photos to prepare for join test...',
          );
          await client.leaveRoom(photoRoomId);
          // Wait for sync to reflect leave
          await fastWait(
            $.tester,
            () =>
                client.getRoomById(photoRoomId)?.membership != Membership.join,
          );
        }

        // Navigate to Discover tab via bottom navigation
        debugPrint('DISCOVERY: Tapping Discover tab...');
        await $.tester.tap(find.byIcon(Icons.explore_outlined));
        await $.tester.pumpAndSettle();

        // Search for test_photos
        debugPrint('DISCOVERY: Searching for test_photos...');
        await $(TextField).first.enterText('test_photos');
        await $.tester.pumpAndSettle();

        // Wait for RoomWidget to appear
        await fastWait(
          $.tester,
          () => $(RoomWidget).exists,
          timeout: const Duration(seconds: 60),
        );

        // Find the join button (Icons.person_add_rounded)
        final joinButton = $(Icons.person_add_rounded);
        await joinButton.waitUntilVisible();
        debugPrint('DISCOVERY: Tapping join button...');
        await joinButton.first.tap();

        // Wait for join to complete (button should change to Icons.person_remove_rounded)
        debugPrint('DISCOVERY: Waiting for join to complete...');
        await fastWait(
          $.tester,
          () => $(Icons.person_remove_rounded).exists,
          timeout: const Duration(seconds: 60),
        );
        expect($(Icons.person_remove_rounded).exists, true);
        debugPrint('✓ DISCOVERY: Room joined successfully');

        // Now leave it
        final leaveButton = $(Icons.person_remove_rounded);
        debugPrint('DISCOVERY: Tapping leave button...');
        await leaveButton.first.tap();

        // Wait for leave to complete
        debugPrint('DISCOVERY: Waiting for leave to complete...');
        await fastWait(
          $.tester,
          () => $(Icons.person_add_rounded).exists,
          timeout: const Duration(seconds: 60),
        );
        expect($(Icons.person_add_rounded).exists, true);
        debugPrint('✓ DISCOVERY: Room left successfully');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );

    testWidgets(
      'Tapping a room tile opens the room preview bottom sheet',
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

        // Navigate to Discover tab
        debugPrint('DISCOVERY PREVIEW: Tapping Discover tab...');
        await $.tester.tap(find.byIcon(Icons.explore_outlined));
        await $.tester.pumpAndSettle();

        expect($(FollowFeedSettings).exists, true);

        // Search for test_art to ensure a room appears
        debugPrint('DISCOVERY PREVIEW: Searching for test_art...');
        await $(TextField).first.enterText('test_art');
        await $.tester.pumpAndSettle();

        // Wait for RoomWidget to appear
        await fastWait(
          $.tester,
          () => $(RoomWidget).exists,
          timeout: const Duration(seconds: 60),
        );

        // Tap the room tile body (not the trailing icon buttons)
        // The ListTile body is the RoomWidget itself, so tap the title text area
        debugPrint('DISCOVERY PREVIEW: Tapping room tile to open preview...');
        final roomTile = $(RoomWidget).first;
        await roomTile.tap();
        await $.tester.pumpAndSettle();

        // Verify the RoomPreviewSheet is now visible
        expect($(RoomPreviewSheet).exists, true);
        debugPrint('✓ DISCOVERY PREVIEW: Room preview sheet opened');

        // Dismiss the bottom sheet by tapping outside
        await $.tester.tapAt(const Offset(200, 10));
        await $.tester.pumpAndSettle();
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}
