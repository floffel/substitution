import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/write/pages/roomselect.dart';
import 'package:substitution/write/pages/textmessage.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:substitution/post/widgets/post.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:patrol/patrol.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait, waitUntilNotVisible;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Content Creation Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      debugPrint('POST_CREATION: Resetting state...');
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
      debugPrint('POST_CREATION: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets('Full flow: FAB -> Select Room -> Write -> Send -> Verify', (tester) async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      final $ = wrapTester(tester);
      app.main();
      
      if (!await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      )) return;

      final client = app.globalMatrixClient!;
      final service = app.globalSubstitutionService!;

      // 1. Create a fresh room for this test to avoid noise
      debugPrint('POST_CREATION: Creating fresh room...');
      final roomName = 'Creation Room ${DateTime.now().millisecondsSinceEpoch}';
      final roomId = await client.createRoom(
        name: roomName,
        preset: CreateRoomPreset.publicChat,
        powerLevelContentOverride: {'users_default': 50},
      );
      
      // Wait for SDK to sync the room
      await fastWait($.tester, () => client.getRoomById(roomId) != null);
      
      // Mark as substitution
      service.addRoomId(roomId);
      await client.setAccountDataPerRoom(client.userID!, roomId, "substitution", {"joined": true});
      service.triggerRefresh();
      await $.tester.pumpAndSettle();

      // 2. Tap Send icon in AppBar to start posting
      debugPrint('POST_CREATION: Tapping New Post button...');
      final newPostButton = $(Icons.send_outlined);
      await newPostButton.waitUntilVisible();
      await newPostButton.tap();
      await $.tester.pumpAndSettle();

      // 3. Verify RoomSelectPage and pick our fresh room
      expect($(RoomSelectPage).exists, true);
      debugPrint('POST_CREATION: Picking room $roomName...');
      await $(find.textContaining(roomName)).tap();
      await $.tester.pumpAndSettle();

      // 4. Verify TextMessageWrite page
      expect($(TextMessageWrite).exists, true);
      
      // 5. Enter unique message text
      final uniqueBody = 'UNIQUE_POST_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('POST_CREATION: Entering text: $uniqueBody...');
      
      final editorFinder = find.byType(quill.QuillEditor);
      await $(editorFinder).waitUntilVisible();
      
      // Set text directly on the controller for 100% reliability in tests
      final state = $.tester.state<TextMessageWriteState>(find.byType(TextMessageWrite));
      state.controller.document.insert(0, uniqueBody);
      await $.tester.pumpAndSettle();

      // 6. Tap Send button (Icons.send)
      debugPrint('POST_CREATION: Tapping Send...');
      final sendButton = $(Icons.send);
      await sendButton.waitUntilVisible();
      await sendButton.tap();
      
      // 7. Wait for navigation back to feed
      debugPrint('POST_CREATION: Waiting for redirect to feed...');
      await fastWait($.tester, () => $(HomePage).exists, timeout: const Duration(seconds: 30));
      await $.tester.pumpAndSettle();

      // 8. Verify message appears in feed
      debugPrint('POST_CREATION: Verifying message in feed...');
      await fastWait($.tester, () {
        return find.textContaining(uniqueBody, skipOffstage: false).evaluate().isNotEmpty;
      }, timeout: const Duration(seconds: 60));
      
      expect($(find.textContaining(uniqueBody)).exists, true);
      debugPrint('✓ POST_CREATION: Full flow verified successfully');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
