import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:matrix/matrix.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('History and Caching Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      debugPrint('HISTORY: Resetting state...');
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
      debugPrint('HISTORY: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets('Fetch very old messages via pagination', (tester) async {
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
      final service = app.globalSubstitutionService!;

      // 1. Create a fresh room
      debugPrint('HISTORY: Creating room...');
      final roomId = await client.createRoom(
        name: 'History Test Room',
        preset: CreateRoomPreset.publicChat,
        powerLevelContentOverride: {'users_default': 50},
      );
      
      await fastWait($.tester, () => client.getRoomById(roomId) != null);
      final room = client.getRoomById(roomId)!;
      service.addRoomId(roomId);
      await client.setAccountDataPerRoom(client.userID!, roomId, "substitution", {"joined": true});

      // Send 50 messages in chunks to ensure they are distinct
      final oldestMessageBody = 'OLDEST_MESSAGE_STAY_HERE';
      await room.sendTextEvent(oldestMessageBody);
      
      debugPrint('HISTORY: Seeding messages...');
      for (int i = 1; i <= 50; i++) {
        await room.sendTextEvent('Filler message $i');
        if (i % 10 == 0) {
          debugPrint('HISTORY: Sent $i/50...');
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      final newestMessageBody = 'NEWEST_MESSAGE_TOP';
      await room.sendTextEvent(newestMessageBody);

      service.triggerRefresh();
      await $.tester.pumpAndSettle();

      // 2. Load the feed and verify the newest message is there
      debugPrint('HISTORY: Waiting for newest message...');
      await fastWait($.tester, () => find.textContaining(newestMessageBody).evaluate().isNotEmpty, timeout: const Duration(seconds: 60));
      expect($(find.textContaining(newestMessageBody)).exists, true);

      // 3. Scroll to find the oldest message
      debugPrint('HISTORY: Scrolling to find oldest message...');
      final scrollable = $(Scrollable).first;
      
      bool foundOldest = false;
      for (int i = 0; i < 20; i++) { 
        if (find.textContaining(oldestMessageBody, skipOffstage: false).evaluate().isNotEmpty) {
          foundOldest = true;
          break;
        }
        debugPrint('HISTORY: Dragging down (step $i)...');
        await $.tester.drag(scrollable, const Offset(0, -1500));
        await $.tester.pumpAndSettle();
        await $.tester.pump(const Duration(seconds: 1));
      }

      expect(foundOldest, true, reason: 'The oldest message should eventually be fetched and displayed');
      debugPrint('✓ HISTORY: Successfully fetched old messages via pagination');
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
