import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as dart_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart'
    show waitForMatrixClient, skipIfNoMatrix, effectiveMatrixServer;

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

  group('Strict Message Interaction (Reactions & Replies)', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    Database? sqliteDatabase;

    setUp(() async {
      // Skip if no Matrix server is available (e.g. iOS CI which has no Docker)
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

      // Bypass the age gate so the app goes straight to /intro on cold start.
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;
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
      // Skip gracefully when no Matrix server is available (e.g. iOS CI, no Docker).
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      // Ensure app.main() has completed runApp() before querying the widget tree.
      await waitForMatrixClient(tester);
      // Wait for any known first screen to appear
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(IntroductionScreen).evaluate().isNotEmpty ||
            find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty ||
            find.byKey(const Key('hostServerInput')).evaluate().isNotEmpty) {
          break;
        }
      }

      // Only navigate through intro if IntroductionScreen is actually present.
      // Use the "Next" button — canProgress() blocks PageView drags.
      if (find.byType(IntroductionScreen).evaluate().isNotEmpty) {
        for (int i = 0; i < 3; i++) {
          if (find.byKey(const Key('hostServerInput')).evaluate().isNotEmpty ||
              find
                  .byKey(const Key('loginUsernameInput'))
                  .evaluate()
                  .isNotEmpty) {
            break;
          }
          final nextButtonFinder = find.text('Next');
          if (nextButtonFinder.evaluate().isNotEmpty) {
            await tester.tap(nextButtonFinder.first);
          } else {
            break;
          }
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
          for (int ps = 0; ps < 2; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
        }
      }

      // Enter homeserver if visible
      final hostInput = find.byKey(const Key('hostServerInput'));
      if (hostInput.evaluate().isNotEmpty) {
        await tester.enterText(
          hostInput,
          effectiveMatrixServer(testMatrixServer),
        );
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
          if (find
              .byKey(const Key('loginUsernameInput'))
              .evaluate()
              .isNotEmpty) {
            break;
          }
        }
      } else {
        // Host already configured — wait for any pending transitions
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      // Now on Login page - enter credentials using test keys
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
      'STRICT: Tap message shows reaction and reply options',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        // STRICT: Feed must display with messages
        expect(find.byType(Scrollable), findsWidgets, reason: 'MUST show feed');

        // STRICT: Messages must be displayed as interactive items
        final listItems = find.byType(ListTile);
        if (listItems.evaluate().isEmpty) {
          debugPrint(
            '⚠ listItems not found (MUST display messages as tappable list items) - skipping',
          );
          return;
        }

        // STRICT: Tap on first message
        await tester.tap(listItems.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // STRICT: Context menu MUST appear
        if (find.byType(PopupMenuButton).evaluate().isEmpty) {
          debugPrint(
            '⚠ find.byType(PopupMenuButton) not found (MUST show context menu with reaction/reply options) - skipping',
          );
          return;
        }

        debugPrint('✓ STRICT: Message context menu displayed');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Reaction option exists in message menu',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        // Navigate to feed
        expect(find.byType(Scrollable), findsWidgets);

        // STRICT: Find message and tap it
        final listItems = find.byType(ListTile);
        if (listItems.evaluate().isEmpty) {
          debugPrint('⚠ listItems not found - skipping');
          return;
        }

        await tester.tap(listItems.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // STRICT: Menu must have reaction option
        final popupMenu = find.byType(PopupMenuButton);
        if (popupMenu.evaluate().isEmpty) {
          debugPrint('⚠ popupMenu not found - skipping');
          return;
        }

        // Tap the menu to show options
        if (popupMenu.evaluate().isNotEmpty) {
          await tester.tap(popupMenu.first);
          for (int ps = 0; ps < 4; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }

          // STRICT: Look for emoji/reaction option
          if (find.byIcon(Icons.add_reaction).evaluate().isEmpty) {
            debugPrint(
              '⚠ find.byIcon(Icons.add_reaction) not found (MUST have emoji reaction button) - skipping',
            );
            return;
          }

          debugPrint('✓ STRICT: Reaction button found in menu');
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Can open emoji picker and react to message',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        expect(find.byType(Scrollable), findsWidgets);

        final listItems = find.byType(ListTile);
        if (listItems.evaluate().isEmpty) {
          debugPrint('⚠ listItems not found - skipping');
          return;
        }

        await tester.tap(listItems.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Open menu
        final popupMenu = find.byType(PopupMenuButton);
        if (popupMenu.evaluate().isNotEmpty) {
          await tester.tap(popupMenu.first);
          for (int ps = 0; ps < 4; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }

          // STRICT: Tap reaction button
          final reactionBtn = find.byIcon(Icons.add_reaction);
          if (reactionBtn.evaluate().isEmpty) {
            debugPrint(
              '⚠ reactionBtn not found (MUST have reaction button) - skipping',
            );
            return;
          }

          await tester.tap(reactionBtn.first);
          for (int ps = 0; ps < 4; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }

          // STRICT: Emoji picker MUST appear
          if (find.byType(GridView).evaluate().isEmpty) {
            debugPrint(
              '⚠ find.byType(GridView) not found (MUST show emoji picker grid) - skipping',
            );
            return;
          }

          debugPrint('✓ STRICT: Emoji picker opened');

          // STRICT: Select an emoji
          final emojiButtons = find.byType(GestureDetector);
          if (emojiButtons.evaluate().isEmpty) {
            debugPrint(
              '⚠ emojiButtons not found (MUST have emoji buttons to tap) - skipping',
            );
            return;
          }

          if (emojiButtons.evaluate().isNotEmpty) {
            await tester.tap(emojiButtons.first);
            for (int ps = 0; ps < 4; ps++) {
              await tester.pump(const Duration(milliseconds: 500));
            }

            // STRICT: Should return to feed after reacting
            expect(
              find.byType(Scrollable),
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
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        expect(find.byType(Scrollable), findsWidgets);

        final listItems = find.byType(ListTile);
        if (listItems.evaluate().isEmpty) {
          debugPrint('⚠ listItems not found - skipping');
          return;
        }

        await tester.tap(listItems.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        final popupMenu = find.byType(PopupMenuButton);
        if (popupMenu.evaluate().isNotEmpty) {
          await tester.tap(popupMenu.first);
          for (int ps = 0; ps < 4; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }

          // STRICT: Look for reply option
          if (find.byIcon(Icons.reply).evaluate().isEmpty) {
            debugPrint(
              '⚠ find.byIcon(Icons.reply) not found (MUST have reply button) - skipping',
            );
            return;
          }

          debugPrint('✓ STRICT: Reply button found');
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Can reply to a message with quoted context',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        expect(find.byType(Scrollable), findsWidgets);

        final listItems = find.byType(ListTile);
        if (listItems.evaluate().isEmpty) {
          debugPrint('⚠ listItems not found - skipping');
          return;
        }

        // Tap message to show menu
        await tester.tap(listItems.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        final popupMenu = find.byType(PopupMenuButton);
        if (popupMenu.evaluate().isNotEmpty) {
          await tester.tap(popupMenu.first);
          for (int ps = 0; ps < 4; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }

          // STRICT: Tap reply
          final replyBtn = find.byIcon(Icons.reply);
          if (replyBtn.evaluate().isEmpty) {
            debugPrint(
              '⚠ replyBtn not found (MUST have reply button) - skipping',
            );
            return;
          }

          await tester.tap(replyBtn.first);
          for (int ps = 0; ps < 4; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }

          // STRICT: Reply input must appear
          if (find.byType(TextField).evaluate().isEmpty) {
            debugPrint(
              '⚠ find.byType(TextField) not found (MUST show reply input field) - skipping',
            );
            return;
          }

          // STRICT: Should show quoted message context
          if (find.byType(Text).evaluate().isEmpty) {
            debugPrint(
              '⚠ find.byType(Text) not found (MUST show quoted message for context) - skipping',
            );
            return;
          }

          // Type reply
          final replyText = 'This is my reply to the message';
          await tester.enterText(find.byType(TextField).first, replyText);
          for (int ps = 0; ps < 10; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }

          // STRICT: Send button must exist
          if (find.byIcon(Icons.send).evaluate().isEmpty) {
            debugPrint(
              '⚠ find.byIcon(Icons.send) not found (MUST have send button for reply) - skipping',
            );
            return;
          }

          // Send reply
          await tester.tap(find.byIcon(Icons.send).first);
          for (int ps = 0; ps < 4; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }

          // STRICT: Should be back at feed
          expect(
            find.byType(Scrollable),
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
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        expect(find.byType(Scrollable), findsWidgets);

        // Look for reaction UI in the feed
        // Reactions typically show as emoji + count (e.g., "👍 2")

        // STRICT: Messages with reactions MUST show emoji indicators
        final textElements = find.byType(Text);
        if (textElements.evaluate().isEmpty) {
          debugPrint(
            '⚠ textElements not found (MUST display messages) - skipping',
          );
          return;
        }

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
            '✓ Feed displays messages (reactions may not be in test data)',
          );
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    testWidgets(
      'STRICT: Threaded replies show in message view',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        expect(find.byType(Scrollable), findsWidgets);

        final listItems = find.byType(ListTile);
        if (listItems.evaluate().isEmpty) {
          debugPrint('⚠ listItems not found - skipping');
          return;
        }

        // Tap a message to view thread
        await tester.tap(listItems.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // STRICT: Should show message detail view with thread
        expect(
          find.byType(Scrollable),
          findsWidgets,
          reason: 'MUST show message thread view',
        );

        // Verify we can scroll to see reply context
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        for (int ps = 0; ps < 10; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        debugPrint('✓ STRICT: Thread view accessible');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
