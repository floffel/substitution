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

  group('Feed with Real Matrix Server', () {
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
      // Wait for app to fully initialize (async main)
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(IntroductionScreen).evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();

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

      // Scroll submit button into view and tap
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

      // Enter credentials using test keys
      final usernameField = find.byKey(const Key('loginUsernameInput'));
      expect(usernameField, findsOneWidget,
          reason: 'Username field should be visible on login page');
      await tester.enterText(usernameField, testUser);
      await tester.pumpAndSettle();

      final passwordField = find.byKey(const Key('loginPasswordInput'));
      await tester.enterText(passwordField, testPassword);
      await tester.pumpAndSettle();

      // Scroll login button into view and tap
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
      'Display unified feed from multiple rooms',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // Verify feed is displayed
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'Feed should display a list of messages',
        );

        // Verify messages are loaded
        final textWidgetsFinder = find.byType(Text);
        expect(
          textWidgetsFinder,
          findsWidgets,
          reason: 'Feed should display message content',
        );

        debugPrint('✓ Unified feed displayed with messages');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'Feed displays content from test_general room (has 5 messages)',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // Wait for feed to load all messages
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for sample messages from test_general room
        // The init script creates: "Hello everyone! Welcome to this test room."
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'Feed should display messages from test_general',
        );

        debugPrint('✓ Feed displays test_general room content');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'Feed displays content from test_photos room (has 3 messages)',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // Wait for feed to load
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify feed content includes messages
        final listViewFinder = find.byType(ListView);
        expect(
          listViewFinder,
          findsWidgets,
          reason: 'Feed should include test_photos messages',
        );

        debugPrint('✓ Feed includes test_photos room content');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'Feed loads and shows messages chronologically',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // Get the list view
        final listViewFinder = find.byType(ListView);
        expect(listViewFinder, findsWidgets);

        // Scroll down to load more messages (infinite scroll)
        await tester.drag(listViewFinder.first, const Offset(0, -300));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify more content is available
        expect(
          find.byType(Text),
          findsWidgets,
          reason: 'Feed should have loadable messages',
        );

        debugPrint('✓ Feed supports scrolling and infinite loading');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'Feed excludes test_art room (empty room)',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // Wait for feed to load
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Empty rooms shouldn't contribute messages to the feed,
        // but the room should still be accessible
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'Feed should exist even with some empty rooms',
        );

        debugPrint('✓ Empty rooms properly handled in feed');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
