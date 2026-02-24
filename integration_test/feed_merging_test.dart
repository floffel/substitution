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

        // Ensure app is fully loaded and settled before trying to find context
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Let's try to find any widget that might have a GoRouter
        final BuildContext context = tester.element(
          find.byType(Navigator).first,
        );
        // ignore: use_build_context_synchronously
        GoRouter.of(context).go("/");
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // 2. Create two test rooms
        final roomIdA = await client.createRoom(
          preset: CreateRoomPreset.publicChat,
          name: 'Merging Room A',
        );
        final roomIdB = await client.createRoom(
          preset: CreateRoomPreset.publicChat,
          name: 'Merging Room B',
        );

        // 3. Mark rooms as 'substitution' joined so they appear in feed
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

        // Wait for sync to pick up the new messages
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 1000));
        }

        // 5. Navigate to Home Feed (to force refresh)
        // ignore: use_build_context_synchronously
        GoRouter.of(context).go("/");
        await tester.pumpAndSettle();

        // Wait for feed to load
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 500));
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
      timeout: const Timeout(Duration(seconds: 240)),
    );
  });
}
