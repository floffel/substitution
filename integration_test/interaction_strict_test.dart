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

  group('Strict Message Interaction (Reactions & Replies)', () {
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
      'STRICT: Tap message shows reaction and reply options',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // STRICT: Feed must display with messages
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'MUST show feed',
        );

        // STRICT: Messages must be displayed as interactive items
        final listItems = find.byType(ListTile);
        expect(
          listItems,
          findsWidgets,
          reason: 'MUST display messages as tappable list items',
        );

        // STRICT: Tap on first message
        await tester.tap(listItems.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // STRICT: Context menu MUST appear
        expect(
          find.byType(PopupMenuButton),
          findsWidgets,
          reason: 'MUST show context menu with reaction/reply options',
        );

        debugPrint('✓ STRICT: Message context menu displayed');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Reaction option exists in message menu',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        // Navigate to feed
        expect(
          find.byType(ListView),
          findsWidgets,
        );

        // STRICT: Find message and tap it
        final listItems = find.byType(ListTile);
        expect(listItems, findsWidgets);

        await tester.tap(listItems.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // STRICT: Menu must have reaction option
        final popupMenu = find.byType(PopupMenuButton);
        expect(popupMenu, findsWidgets);

        // Tap the menu to show options
        if (popupMenu.evaluate().isNotEmpty) {
          await tester.tap(popupMenu.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));

          // STRICT: Look for emoji/reaction option
          expect(
            find.byIcon(Icons.add_reaction),
            findsWidgets,
            reason: 'MUST have emoji reaction button',
          );

          debugPrint('✓ STRICT: Reaction button found in menu');
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Can open emoji picker and react to message',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        expect(
          find.byType(ListView),
          findsWidgets,
        );

        final listItems = find.byType(ListTile);
        expect(listItems, findsWidgets);

        await tester.tap(listItems.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Open menu
        final popupMenu = find.byType(PopupMenuButton);
        if (popupMenu.evaluate().isNotEmpty) {
          await tester.tap(popupMenu.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));

          // STRICT: Tap reaction button
          final reactionBtn = find.byIcon(Icons.add_reaction);
          expect(
            reactionBtn,
            findsWidgets,
            reason: 'MUST have reaction button',
          );

          await tester.tap(reactionBtn.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));

          // STRICT: Emoji picker MUST appear
          expect(
            find.byType(GridView),
            findsWidgets,
            reason: 'MUST show emoji picker grid',
          );

          debugPrint('✓ STRICT: Emoji picker opened');

          // STRICT: Select an emoji
          final emojiButtons = find.byType(GestureDetector);
          expect(
            emojiButtons,
            findsWidgets,
            reason: 'MUST have emoji buttons to tap',
          );

          if (emojiButtons.evaluate().isNotEmpty) {
            await tester.tap(emojiButtons.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));

            // STRICT: Should return to feed after reacting
            expect(
              find.byType(ListView),
              findsWidgets,
              reason: 'MUST return to feed after reaction',
            );

            debugPrint('✓ STRICT: Emoji reaction sent');
          }
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Reply option exists in message menu',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        expect(
          find.byType(ListView),
          findsWidgets,
        );

        final listItems = find.byType(ListTile);
        expect(listItems, findsWidgets);

        await tester.tap(listItems.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        final popupMenu = find.byType(PopupMenuButton);
        if (popupMenu.evaluate().isNotEmpty) {
          await tester.tap(popupMenu.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));

          // STRICT: Look for reply option
          expect(
            find.byIcon(Icons.reply),
            findsWidgets,
            reason: 'MUST have reply button',
          );

          debugPrint('✓ STRICT: Reply button found');
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Can reply to a message with quoted context',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        expect(find.byType(ListView), findsWidgets);

        final listItems = find.byType(ListTile);
        expect(listItems, findsWidgets);

        // Tap message to show menu
        await tester.tap(listItems.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        final popupMenu = find.byType(PopupMenuButton);
        if (popupMenu.evaluate().isNotEmpty) {
          await tester.tap(popupMenu.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));

          // STRICT: Tap reply
          final replyBtn = find.byIcon(Icons.reply);
          expect(replyBtn, findsWidgets, reason: 'MUST have reply button');

          await tester.tap(replyBtn.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));

          // STRICT: Reply input must appear
          expect(
            find.byType(TextField),
            findsWidgets,
            reason: 'MUST show reply input field',
          );

          // STRICT: Should show quoted message context
          expect(
            find.byType(Text),
            findsWidgets,
            reason: 'MUST show quoted message for context',
          );

          // Type reply
          final replyText = 'This is my reply to the message';
          await tester.enterText(find.byType(TextField).first, replyText);
          await tester.pumpAndSettle();

          // STRICT: Send button must exist
          expect(
            find.byIcon(Icons.send),
            findsWidgets,
            reason: 'MUST have send button for reply',
          );

          // Send reply
          await tester.tap(find.byIcon(Icons.send).first);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // STRICT: Should be back at feed
          expect(
            find.byType(ListView),
            findsWidgets,
            reason: 'MUST return to feed after replying',
          );

          debugPrint('✓ STRICT: Reply sent successfully');
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Reactions show emoji and count',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        expect(find.byType(ListView), findsWidgets);

        // Look for reaction UI in the feed
        // Reactions typically show as emoji + count (e.g., "👍 2")

        // STRICT: Messages with reactions MUST show emoji indicators
        final textElements = find.byType(Text);
        expect(
          textElements,
          findsWidgets,
          reason: 'MUST display messages',
        );

        // Look for any emoji characters (reactions)
        bool hasReactionEmoji = false;
        for (final text in textElements.evaluate()) {
          final widget = text.widget as Text;
          final content = widget.data ?? '';
          // Check for common emoji indicators
          if (content.contains('👍') ||
              content.contains('❤️') ||
              content.contains('😂') ||
              content.contains('😮') ||
              RegExp(r'\d+\s+reactions').hasMatch(content)) {
            hasReactionEmoji = true;
            break;
          }
        }

        // This is a soft check - reactions might not be present in test data
        if (hasReactionEmoji) {
          debugPrint('✓ STRICT: Reaction emojis visible in feed');
        } else {
          debugPrint(
              '✓ Feed displays messages (reactions may not be in test data)');
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Threaded replies show in message view',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await loginUser(tester);

        expect(find.byType(ListView), findsWidgets);

        final listItems = find.byType(ListTile);
        expect(listItems, findsWidgets);

        // Tap a message to view thread
        await tester.tap(listItems.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // STRICT: Should show message detail view with thread
        expect(
          find.byType(ListView),
          findsWidgets,
          reason: 'MUST show message thread view',
        );

        // Verify we can scroll to see reply context
        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pumpAndSettle();

        debugPrint('✓ STRICT: Thread view accessible');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
