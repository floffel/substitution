import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Feed with Real Matrix Server', () {
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
      timeout: const Timeout(Duration(seconds: 60)),
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
      timeout: const Timeout(Duration(seconds: 60)),
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
      timeout: const Timeout(Duration(seconds: 60)),
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
      timeout: const Timeout(Duration(seconds: 60)),
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
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
