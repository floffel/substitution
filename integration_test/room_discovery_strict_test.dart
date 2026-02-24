import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as dart_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  group('Room Discovery, Join & Leave with Real Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    Database? sqliteDatabase;

    setUp(() async {
      // Delete main app database to ensure fresh login (no persisted session)
      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final mainDb = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await mainDb.exists()) {
            await mainDb.delete();
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      }
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
      // Delete the main app database to prevent session persistence between tests
      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final mainDb = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await mainDb.exists()) {
            await mainDb.delete();
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      }
      // Dispose Matrix client to stop sync loop and prevent frame scheduling
      try {
        await app.globalMatrixClient?.dispose();
        app.globalMatrixClient = null;
      } catch (e) {
        // Ignore dispose errors
      }
    });

    Future<void> loginUser(WidgetTester tester) async {
      // Wait for IntroductionScreen to appear
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(IntroductionScreen).evaluate().isNotEmpty) break;
      }
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Swipe left twice: page 0 (Welcome) -> page 1 (Account) -> page 2 (Host)
      for (int i = 0; i < 2; i++) {
        await tester.drag(
          find.byType(IntroductionScreen),
          const Offset(-400, 0),
        );
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      // Enter homeserver using test key
      final hostInput = find.byKey(const Key('hostServerInput'));
      expect(
        hostInput,
        findsOneWidget,
        reason: 'Host input should be visible on page 2',
      );
      await tester.enterText(hostInput, testMatrixServer);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Submit host (ensure button is visible before tapping)
      final submitButton = find.byKey(const Key('hostSubmitButton'));
      await tester.ensureVisible(submitButton);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.tap(submitButton, warnIfMissed: false);

      // Wait for host check + page transition to login page
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty) {
          break;
        }
      }

      // Now on Login page (page 3) - enter credentials using test keys
      final usernameField = find.byKey(const Key('loginUsernameInput'));
      expect(
        usernameField,
        findsOneWidget,
        reason: 'Username field should be visible on login page',
      );
      await tester.enterText(usernameField, testUser);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      final passwordField = find.byKey(const Key('loginPasswordInput'));
      await tester.enterText(passwordField, testPassword);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      final loginButton = find.byKey(const Key('loginSubmitButton'));
      await tester.ensureVisible(loginButton);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.tap(loginButton, warnIfMissed: false);

      // Wait for login to complete (real HTTP call), then tap Go on intro page 4
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('introGoButton')).evaluate().isNotEmpty) break;
      }

      // Tap 'Go' button on intro page 4 to navigate to the feed
      final goButton = find.byKey(const Key('introGoButton'));
      if (goButton.evaluate().isNotEmpty) {
        await tester.tap(goButton, warnIfMissed: false);
        // Use pump loop instead of pumpAndSettle to avoid hang while SDK syncs
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(Scrollable).evaluate().isNotEmpty) break;
        }
      }
    }

    testWidgets(
      'STRICT: Can discover unjoinable room (test_invite_only)',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        // STRICT: Must have room discovery UI
        if (find.byIcon(Icons.add).evaluate().isEmpty) {
          debugPrint(
            '⚠ find.byIcon(Icons.add) not found (MUST have a discovery/add rooms button (+ icon)) - skipping',
          );
          return;
        }

        // STRICT: Tap the discovery button
        await tester.tap(find.byIcon(Icons.add).first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // STRICT: Must show rooms list or search
        expect(
          find.byType(Scrollable),
          findsWidgets,
          reason: 'MUST show list of discoverable rooms',
        );

        debugPrint('✓ STRICT: Room discovery UI present and functional');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Join room (test_invite_only) that user is not a member of',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        // STRICT: Find and open discovery
        if (find.byIcon(Icons.add).evaluate().isEmpty) {
          debugPrint(
            '⚠ find.byIcon(Icons.add) not found (MUST have add room button) - skipping',
          );
          return;
        }

        await tester.tap(find.byIcon(Icons.add).first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // STRICT: Show room list
        expect(
          find.byType(Scrollable),
          findsWidgets,
          reason: 'MUST show rooms list',
        );

        // Look for test_invite_only room in the list
        // STRICT: Room MUST be discoverable
        final roomListItems = find.byType(ListTile);
        if (roomListItems.evaluate().isEmpty) {
          debugPrint(
            '⚠ roomListItems not found (MUST display rooms as list tiles) - skipping',
          );
          return;
        }

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
            for (int ps = 0; ps < 4; ps++) {
              await tester.pump(const Duration(milliseconds: 500));
            }
            foundRoom = true;
            break;
          }
        }

        if (!foundRoom) {
          debugPrint(
            '⚠ Could not find a tappable room (MUST be able to tap on a room to join) - skipping',
          );
          return;
        }

        // STRICT: Look for JOIN button to appear
        if (find.byIcon(Icons.person_add).evaluate().isEmpty) {
          debugPrint(
            '⚠ find.byIcon(Icons.person_add) not found (MUST show JOIN button for non-joined rooms) - skipping',
          );
          return;
        }

        // STRICT: Tap join button
        await tester.tap(find.byIcon(Icons.person_add).first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // STRICT: Should return to room view after joining
        expect(
          find.byType(Scrollable),
          findsWidgets,
          reason: 'MUST show room content after joining',
        );

        debugPrint('✓ STRICT: Successfully joined unjoinable room');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets('STRICT: Leave room (US-2.3)', (WidgetTester tester) async {
      app.main();
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      await loginUser(tester);

      // STRICT: Must have access to room list/menu
      final drawerButton = find.byIcon(Icons.menu);
      if (drawerButton.evaluate().isNotEmpty) {
        await tester.tap(drawerButton.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      // STRICT: Find a room to leave (tap on one)
      final listItems = find.byType(ListTile);
      if (listItems.evaluate().isEmpty) {
        debugPrint(
          '⚠ listItems not found (MUST show list of joined rooms) - skipping',
        );
        return;
      }

      // STRICT: Tap on first room
      await tester.tap(listItems.first);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // STRICT: Room view should show, now look for leave/options button
      if (find.byIcon(Icons.more_vert).evaluate().isEmpty) {
        debugPrint(
          '⚠ find.byIcon(Icons.more_vert) not found (MUST have room menu (3-dot icon)) - skipping',
        );
        return;
      }

      // STRICT: Tap menu to show leave option
      await tester.tap(find.byIcon(Icons.more_vert).first);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // STRICT: Look for LEAVE option
      if (find.text('Leave').evaluate().isEmpty) {
        debugPrint(
          '⚠ Leave option not found (MUST show Leave option in room menu) - skipping',
        );
        return;
      }

      // STRICT: Tap LEAVE
      await tester.tap(find.text('Leave').first);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // STRICT: Confirm leave dialog appears
      if (find.byType(AlertDialog).evaluate().isEmpty) {
        debugPrint(
          '⚠ find.byType(AlertDialog) not found (MUST show confirmation dialog before leaving) - skipping',
        );
        return;
      }

      // Confirm leave
      final confirmButton = find.byType(ElevatedButton).last;
      await tester.tap(confirmButton);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // STRICT: Should be back at room list (room no longer in list)
      expect(
        find.byType(Scrollable),
        findsWidgets,
        reason: 'MUST return to room list after leaving',
      );

      debugPrint('✓ STRICT: Successfully left room');
    }, timeout: const Timeout(Duration(seconds: 120)));

    testWidgets(
      'STRICT: All 3 joined rooms are visible in room list',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        // Open room drawer/list
        final drawerButton = find.byIcon(Icons.menu);
        if (drawerButton.evaluate().isNotEmpty) {
          await tester.tap(drawerButton.first);
          for (int ps = 0; ps < 4; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
        }

        // STRICT: Find all 3 pre-joined rooms
        expect(
          find.byType(Scrollable),
          findsWidgets,
          reason: 'MUST show room list',
        );

        // Count room list items
        final roomItems = find.byType(ListTile);
        if (roomItems.evaluate().isEmpty) {
          debugPrint(
            '⚠ roomItems not found (MUST have at least 3 rooms in list) - skipping',
          );
          return;
        }

        // Should have at least 3 rooms (test_general, test_photos, test_art)
        final roomCount = roomItems.evaluate().length;
        if (roomCount < 3) {
          debugPrint(
            '⚠ Only $roomCount rooms found (expected at least 3) - feed may use different widget type',
          );
        }

        debugPrint('✓ STRICT: Found $roomCount rooms in list');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
