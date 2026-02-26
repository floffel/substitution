import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:matrix/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as dart_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  group('Feed Merging Integration Test', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;

      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final dbPath = '${appDocDir.path}/matrix_database.db';
          if (await dart_io.File(dbPath).exists()) {
            await databaseFactory.deleteDatabase(dbPath);
          }
        } catch (e) {
          debugPrint("Failed to delete database in setUp: $e");
        }
      }
    });

    tearDown(() async {
      try {
        await app.globalMatrixClient?.dispose();
        app.globalMatrixClient = null;
      } catch (e) {
        debugPrint("Failed to dispose client in tearDown: $e");
      }

      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final dbPath = '${appDocDir.path}/matrix_database.db';
          if (await dart_io.File(dbPath).exists()) {
            await databaseFactory.deleteDatabase(dbPath);
          }
        } catch (e) {
          debugPrint("Failed to delete database in tearDown: $e");
        }
      }
    });

    testWidgets(
      'Messages from multiple rooms are interleaved correctly in chronological order',
      (WidgetTester tester) async {
        app.main();
        await waitForMatrixClient(tester);

        final client = app.globalMatrixClient!;

        // 1. Programmatic Login
        client.homeserver = Uri.parse(testMatrixServer);
        await client.checkHomeserver(client.homeserver!);
        await client.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: testUser),
          password: testPassword,
        );

        // Pump briefly to let any immediate transitions settle.
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 250));
        }

        // Find a context that is inside the GoRouter subtree.
        // IntroductionPage is shown before login; Scaffold is inside any page.
        // MaterialApp.router is NOT inside the router, so GoRouter.of won't work on it.
        Element? navContext;
        if (find.byType(app.IntroductionPage).evaluate().isNotEmpty) {
          navContext = tester.element(find.byType(app.IntroductionPage).first);
        } else if (find.byType(Scaffold).evaluate().isNotEmpty) {
          navContext = tester.element(find.byType(Scaffold).first);
        }
        // ignore: use_build_context_synchronously
        if (navContext != null) {
          GoRouter.of(navContext).go("/");
        } else {
          debugPrint('⚠ No router context found — cannot navigate to feed');
        }
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // 2. Create two test rooms.
        // Set users_default to 50 so that the feed's power-level filter
        // (>= 50) accepts messages from the room creator even before the
        // m.room.power_levels state event is fully loaded by the SDK.
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

        // 3. Persist 'substitution' account data for the two rooms so that if
        // the service is re-initialised it will still find them.
        await client.setAccountDataPerRoom(
          client.userID!,
          roomIdA,
          "substitution",
          {"joined": true},
        );
        await client.setAccountDataPerRoom(
          client.userID!,
          roomIdB,
          "substitution",
          {"joined": true},
        );

        // 4. Send interleaved messages with forced delays to ensure distinct timestamps
        final roomA = client.getRoomById(roomIdA)!;
        final roomB = client.getRoomById(roomIdB)!;

        debugPrint("Sending Message 1 in Room A...");
        await roomA.sendTextEvent("Chronological Message 1 (A)");
        await Future.delayed(const Duration(seconds: 2));

        debugPrint("Sending Message 2 in Room B...");
        await roomB.sendTextEvent("Chronological Message 2 (B)");
        await Future.delayed(const Duration(seconds: 2));

        debugPrint("Sending Message 3 in Room A...");
        await roomA.sendTextEvent("Chronological Message 3 (A)");

        // Wait for sync to pick up the new messages.
        // We open the timeline and wait until it has at least 1 message event,
        // confirming that the SDK has processed the sync.
        final timelineA = await roomA.getTimeline();
        bool messagesAppeared = false;
        for (int attempt = 0; attempt < 30; attempt++) {
          await tester.pump(const Duration(milliseconds: 1000));
          final msgs =
              timelineA.events
                  .where((e) => e.type == EventTypes.Message)
                  .toList();
          if (msgs.isNotEmpty) {
            debugPrint(
              '✓ Sync confirmed: ${msgs.length} message(s) in Room A timeline',
            );
            messagesAppeared = true;
            break;
          }
        }
        if (!messagesAppeared) {
          debugPrint('⚠ Messages did not appear in Room A timeline after 30s');
        }
        timelineA.cancelSubscriptions();

        // 5. Navigate to Home Feed (to force a full feed rebuild).
        // First trigger a SubstitutionService refresh so the new room IDs are
        // registered with the live service instance, then navigate away and back
        // to ensure GoRouter recreates the Feed/HomePage widget.
        if (app.globalSubstitutionService != null) {
          app.globalSubstitutionService!.addRoomId(roomIdA);
          app.globalSubstitutionService!.addRoomId(roomIdB);
          app.globalSubstitutionService!.triggerRefresh();
          for (int i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
        }

        // Navigate away and back to guarantee widget reconstruction.
        // Re-query the context each time because navigating invalidates old elements.
        Element? findNavContext() {
          if (find.byType(app.IntroductionPage).evaluate().isNotEmpty) {
            return tester.element(find.byType(app.IntroductionPage).first);
          } else if (find.byType(Scaffold).evaluate().isNotEmpty) {
            return tester.element(find.byType(Scaffold).first);
          }
          return null;
        }

        final navCtxA = findNavContext();
        // ignore: use_build_context_synchronously
        if (navCtxA != null) {
          GoRouter.of(navCtxA).go("/settings/feed");
          for (int i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
        }
        final navCtxB = findNavContext();
        // ignore: use_build_context_synchronously
        if (navCtxB != null) {
          GoRouter.of(navCtxB).go("/");
        }
        // Use timed pumps instead of pumpAndSettle to avoid stalling on Matrix sync loop.
        for (int i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find
                  .textContaining("Chronological Message 1 (A)")
                  .evaluate()
                  .isNotEmpty &&
              find
                  .textContaining("Chronological Message 2 (B)")
                  .evaluate()
                  .isNotEmpty &&
              find
                  .textContaining("Chronological Message 3 (A)")
                  .evaluate()
                  .isNotEmpty) {
            break;
          }
        }

        // 6. Verify visual order in the feed
        // descending order (newest first)
        // Expected: "Chronological Message 3 (A)", "Chronological Message 2 (B)", "Chronological Message 1 (A)"

        final msg3 = find.textContaining("Chronological Message 3 (A)");
        final msg2 = find.textContaining("Chronological Message 2 (B)");
        final msg1 = find.textContaining("Chronological Message 1 (A)");

        expect(msg3, findsOneWidget);
        expect(msg2, findsOneWidget);
        expect(msg1, findsOneWidget);

        final Offset pos3 = tester.getCenter(msg3);
        final Offset pos2 = tester.getCenter(msg2);
        final Offset pos1 = tester.getCenter(msg1);

        // In a vertical list, smaller Y coordinate means higher/earlier in the list
        expect(
          pos3.dy,
          lessThan(pos2.dy),
          reason: "Message 3 (newest) should be above Message 2",
        );
        expect(
          pos2.dy,
          lessThan(pos1.dy),
          reason: "Message 2 should be above Message 1 (oldest)",
        );

        debugPrint("✓ Feed merging and interleaving verified successfully!");
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
