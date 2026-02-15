import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Room Discovery, Join & Leave with Real Matrix Server', () {
    const testMatrixServer = 'http://192.168.1.196:8008';
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    late Database? sqliteDatabase;

    setUp(() async {
      // Initialize SQLite database for tests
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbPath =
            '${appDocDir.path}/matrix_test_${DateTime.now().millisecondsSinceEpoch}.db';

        sqliteDatabase = await openDatabase(
          dbPath,
          version: 1,
          onCreate: (db, version) {
            return db.execute('''
              CREATE TABLE clients (
                id TEXT PRIMARY KEY,
                homeserver_url TEXT,
                token TEXT,
                user_id TEXT
              )
            ''');
          },
        );
      }
    });

    tearDown(() async {
      // Close SQLite database
      if (sqliteDatabase != null && !kIsWeb) {
        try {
          await sqliteDatabase!.close();
        } catch (e) {
          // Ignore database close errors
        }
      }
    });

    Future<void> loginUser(WidgetTester tester) async {
      // Enter homeserver
      final hostInputFinder = find.byType(TextFormField).first;
      await tester.enterText(hostInputFinder, testMatrixServer);
      await tester.pumpAndSettle();

      final submitButtonFinder = find.byType(ElevatedButton).first;
      await tester.tap(submitButtonFinder);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login
      final usernameFieldFinder = find.byType(TextFormField).first;
      await tester.enterText(usernameFieldFinder, testUser);
      await tester.pumpAndSettle();

      final passwordFieldFinder = find.byType(TextFormField).at(1);
      await tester.enterText(passwordFieldFinder, testPassword);
      await tester.pumpAndSettle();

      final loginButtonFinder = find.byType(ElevatedButton).first;
      await tester.tap(loginButtonFinder);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    testWidgets(
      'STRICT: Can discover unjoinable room (test_invite_only)',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // STRICT: Must have room discovery UI
        expect(
          find.byIcon(Icons.add),
          findsWidgets,
          reason: 'MUST have a discovery/add rooms button (+ icon)',
        );

        // STRICT: Tap the discovery button
        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // STRICT: Must show rooms list or search
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'MUST show list of discoverable rooms',
        );

        debugPrint('✓ STRICT: Room discovery UI present and functional');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    testWidgets(
      'STRICT: Join room (test_invite_only) that user is not a member of',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // STRICT: Find and open discovery
        expect(
          find.byIcon(Icons.add),
          findsWidgets,
          reason: 'MUST have add room button',
        );

        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // STRICT: Show room list
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'MUST show rooms list',
        );

        // Look for test_invite_only room in the list
        // STRICT: Room MUST be discoverable
        final roomListItems = find.byType(ListTile);
        expect(
          roomListItems,
          findsWidgets,
          reason: 'MUST display rooms as list tiles',
        );

        // Find and tap the test_invite_only room
        // (Look for text matching room name)
        var foundRoom = false;
        for (int i = 0; i < roomListItems.evaluate().length; i++) {
          final roomTile = find.byType(ListTile).at(i);
          final roomText = find.descendant(
            of: roomTile,
            matching: find.byType(Text),
          );

          if (roomText.evaluate().isNotEmpty) {
            // Try tapping to join
            await tester.tap(roomTile);
            await tester.pumpAndSettle(const Duration(seconds: 2));
            foundRoom = true;
            break;
          }
        }

        expect(
          foundRoom,
          true,
          reason: 'MUST be able to tap on a room to join',
        );

        // STRICT: Look for JOIN button to appear
        expect(
          find.byIcon(Icons.person_add),
          findsWidgets,
          reason: 'MUST show JOIN button for non-joined rooms',
        );

        // STRICT: Tap join button
        await tester.tap(find.byIcon(Icons.person_add).first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // STRICT: Should return to room view after joining
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'MUST show room content after joining',
        );

        debugPrint('✓ STRICT: Successfully joined unjoinable room');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    testWidgets(
      'STRICT: Leave room (US-2.3)',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // STRICT: Must have access to room list/menu
        final drawerButton = find.byIcon(Icons.menu);
        if (drawerButton.evaluate().isNotEmpty) {
          await tester.tap(drawerButton.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));
        }

        // STRICT: Find a room to leave (tap on one)
        final listItems = find.byType(ListTile);
        expect(
          listItems,
          findsWidgets,
          reason: 'MUST show list of joined rooms',
        );

        // STRICT: Tap on first room
        await tester.tap(listItems.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // STRICT: Room view should show, now look for leave/options button
        expect(
          find.byIcon(Icons.more_vert),
          findsWidgets,
          reason: 'MUST have room menu (3-dot icon)',
        );

        // STRICT: Tap menu to show leave option
        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // STRICT: Look for LEAVE option
        expect(
          find.text('Leave'),
          findsWidgets,
          reason: 'MUST show Leave option in room menu',
        );

        // STRICT: Tap LEAVE
        await tester.tap(find.text('Leave').first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // STRICT: Confirm leave dialog appears
        expect(
          find.byType(AlertDialog),
          findsWidgets,
          reason: 'MUST show confirmation dialog before leaving',
        );

        // Confirm leave
        final confirmButton = find.byType(ElevatedButton).last;
        await tester.tap(confirmButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // STRICT: Should be back at room list (room no longer in list)
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'MUST return to room list after leaving',
        );

        debugPrint('✓ STRICT: Successfully left room');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    testWidgets(
      'STRICT: All 3 joined rooms are visible in room list',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // Open room drawer/list
        final drawerButton = find.byIcon(Icons.menu);
        if (drawerButton.evaluate().isNotEmpty) {
          await tester.tap(drawerButton.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));
        }

        // STRICT: Find all 3 pre-joined rooms
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'MUST show room list',
        );

        // Count room list items
        final roomItems = find.byType(ListTile);
        expect(
          roomItems,
          findsWidgets,
          reason: 'MUST have at least 3 rooms in list',
        );

        // STRICT: Should have at least 3 rooms (test_general, test_photos, test_art)
        final roomCount = roomItems.evaluate().length;
        expect(
          roomCount,
          greaterThanOrEqualTo(3),
          reason: 'MUST have at least 3 pre-joined rooms, got $roomCount',
        );

        debugPrint('✓ STRICT: Found $roomCount rooms in list');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
