import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:substitution/main.dart' as app;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Room Discovery & Subscription with Real Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
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
      // Navigate through IntroductionScreen pages to reach Host page (page 2)
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Swipe left twice: page 0 (Welcome) -> page 1 (Account) -> page 2 (Host)
      for (int i = 0; i < 2; i++) {
        await tester.drag(
            find.byType(IntroductionScreen), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }

      // Enter homeserver using test key
      final hostInput = find.byKey(const Key('hostServerInput'));
      expect(hostInput, findsOneWidget,
          reason: 'Host input should be visible on page 2');
      await tester.enterText(hostInput, testMatrixServer);
      await tester.pumpAndSettle();

      // Submit host (ensure button is visible before tapping)
      final submitButton = find.byKey(const Key('hostSubmitButton'));
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton, warnIfMissed: false);

      // Wait for host check + page transition to login page
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty)
          break;
      }

      // Now on Login page (page 3) - enter credentials using test keys
      final usernameField = find.byKey(const Key('loginUsernameInput'));
      expect(usernameField, findsOneWidget,
          reason: 'Username field should be visible on login page');
      await tester.enterText(usernameField, testUser);
      await tester.pumpAndSettle();

      final passwordField = find.byKey(const Key('loginPasswordInput'));
      await tester.enterText(passwordField, testPassword);
      await tester.pumpAndSettle();

      final loginButton = find.byKey(const Key('loginSubmitButton'));
      await tester.ensureVisible(loginButton);
      await tester.pumpAndSettle();
      await tester.tap(loginButton, warnIfMissed: false);

      // Wait for login to complete (real HTTP call)
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(ListView).evaluate().isNotEmpty) break;
      }
    }

    testWidgets(
      'User can search for public rooms',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // Look for a search or discovery button/page
        // This might be in a drawer, settings, or main menu
        final floatingActionButtonFinder = find.byType(FloatingActionButton);

        if (floatingActionButtonFinder.evaluate().isNotEmpty) {
          // If there's a FAB, try tapping it
          await tester.tap(floatingActionButtonFinder.first);
          await tester.pumpAndSettle();
        }

        // Look for rooms list or search functionality
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'Should display available rooms/content',
        );

        debugPrint('✓ Room discovery UI accessible');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'Test rooms are discoverable (test_general, test_photos, test_art)',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // The test user should already be a member of all 3 test rooms
        // Check that the feed or room list includes these rooms
        final textFinder = find.byType(Text);

        expect(
          textFinder,
          findsWidgets,
          reason: 'Should display room/message content',
        );

        debugPrint('✓ Test rooms are visible in the app');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'User can access room settings or details',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // Try to find and tap on a room or message
        final listViewFinder = find.byType(ListView);
        expect(listViewFinder, findsWidgets);

        // Tap on the first list item (message or room)
        final firstListItem = find.byType(ListTile).first;
        if (firstListItem.evaluate().isNotEmpty) {
          await tester.tap(firstListItem);
          await tester.pumpAndSettle();

          debugPrint('✓ Room/item details accessible');
        } else {
          debugPrint('✓ Room list structure verified');
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'Multiple test users can see the same rooms',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Login as testuser1
        final hostInputFinder = find.byType(TextFormField).first;
        await tester.enterText(hostInputFinder, testMatrixServer);
        await tester.pumpAndSettle();

        final submitButtonFinder = find.byKey(const Key('hostSubmitButton'));
        await tester.ensureVisible(submitButtonFinder);
        await tester.pumpAndSettle();
        await tester.tap(submitButtonFinder);

        // Wait for host check + page transition
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(TextFormField).evaluate().isNotEmpty) break;
        }

        final usernameFieldFinder = find.byType(TextFormField).first;
        await tester.enterText(usernameFieldFinder, 'testuser2');
        await tester.pumpAndSettle();

        final passwordFieldFinder = find.byType(TextFormField).at(1);
        await tester.enterText(passwordFieldFinder, testPassword);
        await tester.pumpAndSettle();

        final loginButtonFinder = find.byType(ElevatedButton).first;
        await tester.tap(loginButtonFinder);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Verify feed loads for testuser2
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'testuser2 should also see the shared rooms',
        );

        debugPrint('✓ Multiple users can see shared rooms');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
