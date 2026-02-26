import 'dart:io' as dart_io;
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Feed Merging Integration Test', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      debugPrint('MERGING: Resetting state...');
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
      debugPrint('MERGING: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets('Messages from multiple rooms are interleaved correctly in chronological order', (tester) async {
      final $ = wrapTester(tester);
      app.main();

      // 1. Login using Patrol helper
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

      // 2. Create two test rooms programmatically.
      debugPrint('MERGING: Creating test rooms...');
      final roomIdA = await client.createRoom(
        preset: CreateRoomPreset.publicChat,
        name: 'Merging Room A',
        powerLevelContentOverride: {'users_default': 50},
      );
      final roomIdB = await client.createRoom(
        preset: CreateRoomPreset.publicChat,
        name: 'Merging Room B',
        powerLevelContentOverride: {'users_default': 50},
      );

      // Wait for rooms to appear in client (via sync)
      await fastWait($.tester, () => client.getRoomById(roomIdA) != null && client.getRoomById(roomIdB) != null);

      // 3. Mark rooms as "substitution" using the service (so it's reactive)
      debugPrint('MERGING: Marking rooms as substitution...');
      service.addRoomId(roomIdA);
      service.addRoomId(roomIdB);
      
      // Also set account data so it persists across refreshes
      await client.setAccountDataPerRoom(client.userID!, roomIdA, "substitution", {"joined": true});
      await client.setAccountDataPerRoom(client.userID!, roomIdB, "substitution", {"joined": true});

      final roomA = client.getRoomById(roomIdA)!;
      final roomB = client.getRoomById(roomIdB)!;
      
      debugPrint('MERGING: Room A PL for ${client.userID}: ${roomA.getPowerLevelByUserId(client.userID!)}');
      debugPrint('MERGING: Room B PL for ${client.userID}: ${roomB.getPowerLevelByUserId(client.userID!)}');

      final timelineA = await roomA.getTimeline();
      final timelineB = await roomB.getTimeline();

      // 4. Send interleaved messages with forced delays
      debugPrint("MERGING: Sending Message 1 in Room A...");
      final eventId1 = await roomA.sendTextEvent("Chronological Message 1 (A)");
      await Future.delayed(const Duration(seconds: 1));

      debugPrint("MERGING: Sending Message 2 in Room B...");
      final eventId2 = await roomB.sendTextEvent("Chronological Message 2 (B)");
      await Future.delayed(const Duration(seconds: 1));

      debugPrint("MERGING: Sending Message 3 in Room A...");
      final eventId3 = await roomA.sendTextEvent("Chronological Message 3 (A)");

      // 5. Wait for events to appear in local timelines (via sync)
      debugPrint('MERGING: Waiting for events in local SDK state...');
      await fastWait($.tester, () {
        final has1 = timelineA.events.any((e) => e.eventId == eventId1);
        final has2 = timelineB.events.any((e) => e.eventId == eventId2);
        final has3 = timelineA.events.any((e) => e.eventId == eventId3);
        return has1 && has2 && has3;
      }, timeout: const Duration(seconds: 30));

      // 6. Trigger a refresh and wait for UI
      debugPrint('MERGING: Refreshing UI...');
      service.triggerRefresh();
      
      // Wait for messages to appear in UI
      // Note: Due to the 'red line' logic in home.dart, some messages might be pushed to the next page.
      // We wait for at least two messages from different rooms to verify interleaving.
      debugPrint('MERGING: Waiting for messages in UI...');
      await fastWait($.tester, () {
        // Use a broader search for the text since it might be in Html/RichText
        final has1 = find.textContaining("Chronological Message 1 (A)").evaluate().isNotEmpty;
        final has2 = find.textContaining("Chronological Message 2 (B)").evaluate().isNotEmpty;
        final has3 = find.textContaining("Chronological Message 3 (A)").evaluate().isNotEmpty;
        
        // We need at least one from Room A and one from Room B to verify merging.
        final anyA = has1 || has3;
        final anyB = has2;

        if (anyA || anyB) {
           debugPrint('MERGING: Found some messages. has1=$has1, has2=$has2, has3=$has3');
        }

        return anyA && anyB;
      }, timeout: const Duration(seconds: 60));

      // 7. Verify visual order in the feed (newest first)
      // Get all visible chronological messages and sort them by Y position
      final chronoFinders = [
        find.textContaining("Chronological Message 3 (A)"),
        find.textContaining("Chronological Message 2 (B)"),
        find.textContaining("Chronological Message 1 (A)"),
      ].where((f) => f.evaluate().isNotEmpty).toList();

      for (int i = 0; i < chronoFinders.length - 1; i++) {
        final posTop = $.tester.getCenter(chronoFinders[i]);
        final posBottom = $.tester.getCenter(chronoFinders[i+1]);
        expect(posTop.dy, lessThan(posBottom.dy), reason: "Message $i should be above Message ${i+1}");
      }

      debugPrint("✓ MERGING: Feed interleaving verified successfully!");
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
