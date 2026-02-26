import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:substitution/post/widgets/post.dart';
import 'package:substitution/post/widgets/display/file_display.dart';
import 'package:patrol/patrol.dart';
import 'package:matrix/matrix.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait, waitUntilNotVisible;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Message Type Rendering Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      debugPrint('MESSAGE_TYPES: Resetting state...');
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
      debugPrint('MESSAGE_TYPES: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets('Feed correctly renders text and image messages', (tester) async {
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

      // 1. Create a fresh room
      debugPrint('MESSAGE_TYPES: Creating room...');
      final roomId = await client.createRoom(
        name: 'Type Test Room',
        preset: CreateRoomPreset.publicChat,
        powerLevelContentOverride: {'users_default': 50},
      );
      
      await fastWait($.tester, () => client.getRoomById(roomId) != null);
      service.addRoomId(roomId);
      await client.setAccountDataPerRoom(client.userID!, roomId, "substitution", {"joined": true});
      service.triggerRefresh();
      await $.tester.pumpAndSettle();

      final room = client.getRoomById(roomId)!;
      final timeline = await room.getTimeline();

      // 2. Send Text message
      final textBody = 'TYPES_TEXT_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('MESSAGE_TYPES: Sending text message: $textBody');
      await room.sendTextEvent(textBody);

      // 3. Send "Image" message
      debugPrint('MESSAGE_TYPES: Sending image event...');
      await room.sendEvent({
        'msgtype': MessageTypes.Image,
        'body': 'Types Image',
        'url': 'mxc://example.com/fake_image',
        'info': {
          'mimetype': 'image/png',
          'size': 100,
          'w': 10,
          'h': 10,
        }
      });

      // 4. Wait for SDK to have both messages
      debugPrint('MESSAGE_TYPES: Waiting for SDK sync...');
      await fastWait($.tester, () {
        final hasText = timeline.events.any((dynamic e) {
          try { return e.body.toString().contains(textBody); } catch (_) { return false; }
        });
        final hasImage = timeline.events.any((dynamic e) {
          try { return e.body.toString().contains('Types Image'); } catch (_) { return false; }
        });
        return hasText && hasImage;
      }, timeout: const Duration(seconds: 30));

      // 5. Verify both appear in feed
      debugPrint('MESSAGE_TYPES: Verifying rendering...');
      
      await fastWait($.tester, () {
        final hasText = find.textContaining(textBody, skipOffstage: false).evaluate().isNotEmpty;
        final hasImage = find.byType(FileDisplay).evaluate().isNotEmpty;
        
        if (hasText && hasImage) {
          debugPrint('✓ MESSAGE_TYPES: Both found in UI');
          return true;
        }
        return false;
      }, timeout: const Duration(seconds: 60));

      // Final check with standard expect
      expect(find.textContaining(textBody, skipOffstage: false), findsOneWidget);
      expect(find.byType(FileDisplay, skipOffstage: false), findsOneWidget);
      
      debugPrint('✓ MESSAGE_TYPES: Text and Image rendering verified');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
