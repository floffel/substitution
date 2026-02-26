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
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Individual Room Feed Integration Test', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      debugPrint('ROOM_FEED: Resetting state...');
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

    tearDown(() async {
      debugPrint('ROOM_FEED: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    // Helper to wait for the feed to be truly ready with content
    Future<void> waitForFeedReady(PatrolIntegrationTester $) async {
      debugPrint('ROOM_FEED: Waiting for logic state (rooms)...');
      await fastWait($.tester, () => app.globalSubstitutionService?.roomCount != null && app.globalSubstitutionService!.roomCount > 0);
      
      debugPrint('ROOM_FEED: Waiting for UI state (PostWidget)...');
      await fastWait($.tester, () => $(PostWidget).exists, timeout: const Duration(seconds: 60));
      
      await $.tester.pumpAndSettle();
    }

    testWidgets('Can navigate to individual room feed and see only that room\'s posts', (tester) async {
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

      await waitForFeedReady($);
      
      final client = app.globalMatrixClient!;
      final rooms = await client.getJoinedRooms();
      // Find 'test_general' room ID from the seeded data
      final testGeneralRoomId = rooms.firstWhere((id) => client.getRoomById(id)?.name == 'test_general');
       // testArtRoomId removed

      debugPrint('ROOM_FEED: Navigating to test_general ($testGeneralRoomId)...');
      
      // Programmatic navigation using GoRouter
      final navContext = $.tester.element(find.byType(HomePage));
      navContext.go('/feed/$testGeneralRoomId');
      await $.tester.pumpAndSettle();

      // Wait for room-specific content
      await fastWait($.tester, () => $(PostWidget).exists, timeout: const Duration(seconds: 30));

      // Verify that all visible posts belong to test_general
      // We can't easily check the roomId of the widget without accessing state,
      // but we can check the text in the header if it contains the room name.
      final roomHeaders = find.textContaining('test_general').evaluate();
      expect(roomHeaders.isNotEmpty, true, reason: 'Should show room name in headers');
      
      final otherRoomHeaders = find.textContaining('test_art').evaluate();
      expect(otherRoomHeaders.isEmpty, true, reason: 'Should NOT show posts from other rooms');

      debugPrint('✓ ROOM_FEED: Verified room-specific filtering');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
