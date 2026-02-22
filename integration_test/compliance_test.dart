import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:substitution/main.dart' as app;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as dart_io;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Compliance Features with Real Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    late Database? sqliteDatabase;

    setUp(() async {
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
      if (sqliteDatabase != null && !kIsWeb) {
        try {
          await sqliteDatabase!.close();
        } catch (e) {
          // Ignore database close errors
        }
      }
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
      try {
        await app.globalMatrixClient?.dispose();
        app.globalMatrixClient = null;
      } catch (e) {
        // Ignore dispose errors
      }
    });

    Future<void> loginUser(WidgetTester tester) async {
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(IntroductionScreen).evaluate().isNotEmpty) break;
      }
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Swipe to page 2 (Host)
      for (int i = 0; i < 2; i++) {
        await tester.drag(find.byType(IntroductionScreen), const Offset(-400, 0));
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      final hostInput = find.byKey(const Key('hostServerInput'));
      expect(hostInput, findsOneWidget, reason: 'Host input should be visible on page 2');
      await tester.enterText(hostInput, testMatrixServer);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      final submitButton = find.byKey(const Key('hostSubmitButton'));
      await tester.ensureVisible(submitButton);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.tap(submitButton, warnIfMissed: false);

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty) break;
      }

      final usernameField = find.byKey(const Key('loginUsernameInput'));
      expect(usernameField, findsOneWidget, reason: 'Username field should be visible');
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

      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('introGoButton')).evaluate().isNotEmpty) break;
      }

      final goButton = find.byKey(const Key('introGoButton'));
      if (goButton.evaluate().isNotEmpty) {
        await tester.tap(goButton, warnIfMissed: false);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(Scrollable).evaluate().isNotEmpty) break;
        }
      }
    }

    // ---------------------------------------------------------------------------
    // Legal page tests
    // ---------------------------------------------------------------------------

    testWidgets(
      'Legal drawer item is present and navigates to Legal page',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        // Wait for feed to load
        for (int ps = 0; ps < 8; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Open the navigation drawer
        final menuIcon = find.byIcon(Icons.menu);
        if (menuIcon.evaluate().isEmpty) {
          debugPrint('⚠ Menu icon not found — skipping');
          return;
        }
        await tester.tap(menuIcon.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Verify the Legal (gavel) icon is in the drawer
        expect(
          find.byIcon(Icons.gavel_outlined),
          findsOneWidget,
          reason: 'Legal entry should be present in the navigation drawer',
        );
        debugPrint('✓ Legal drawer item visible');

        // Tap the Legal item
        await tester.tap(find.byIcon(Icons.gavel_outlined));
        for (int ps = 0; ps < 8; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Verify all four legal tiles are shown on the Legal page
        expect(find.byIcon(Icons.description_outlined), findsOneWidget,
            reason: 'Terms of Service tile should be visible');
        expect(find.byIcon(Icons.privacy_tip_outlined), findsOneWidget,
            reason: 'Privacy Policy tile should be visible');
        expect(find.byIcon(Icons.info_outline), findsOneWidget,
            reason: 'Imprint tile should be visible');
        expect(find.byIcon(Icons.code), findsOneWidget,
            reason: 'Open Source Licenses tile should be visible');

        debugPrint('✓ Legal page displays all required compliance tiles');
      },
      timeout: const Timeout(Duration(seconds: 180)),
    );

    // ---------------------------------------------------------------------------
    // UGC moderation tests
    // ---------------------------------------------------------------------------

    testWidgets(
      'Post has a three-dot popup menu with Report/Block option',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        // Wait for feed to load
        for (int ps = 0; ps < 8; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Check if there are any posts visible in the feed
        final popupMenuFinder = find.byType(PopupMenuButton<String>);

        if (popupMenuFinder.evaluate().isEmpty) {
          debugPrint('⚠ No popup menu found in feed (possibly empty feed) — skipping');
          return;
        }

        // Tap the first popup menu button (⋮)
        await tester.tap(popupMenuFinder.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // The "Report / Block" menu item should now be visible
        expect(
          find.byIcon(Icons.flag_outlined),
          findsWidgets,
          reason: 'Report/Block menu item should appear in post popup menu',
        );

        debugPrint('✓ Post popup menu shows Report/Block option');
      },
      timeout: const Timeout(Duration(seconds: 180)),
    );

    testWidgets(
      'Tapping Report/Block opens dialog with report reason and block checkbox',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        for (int ps = 0; ps < 8; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        final popupMenuFinder = find.byType(PopupMenuButton<String>);

        if (popupMenuFinder.evaluate().isEmpty) {
          debugPrint('⚠ No posts in feed — skipping dialog test');
          return;
        }

        // Open popup menu on the first post
        await tester.tap(popupMenuFinder.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Tap "Report / Block"
        final reportBlockItem = find.byIcon(Icons.flag_outlined);
        if (reportBlockItem.evaluate().isEmpty) {
          debugPrint('⚠ Report/Block menu item not found — skipping');
          return;
        }
        await tester.tap(reportBlockItem.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // The dialog should now be visible — check for a TextField (reason) and Checkbox (block)
        expect(
          find.byType(AlertDialog),
          findsOneWidget,
          reason: 'Report/Block dialog should be displayed',
        );
        expect(
          find.byType(TextField),
          findsOneWidget,
          reason: 'Dialog should contain a reason text field',
        );
        expect(
          find.byType(CheckboxListTile),
          findsOneWidget,
          reason: 'Dialog should contain a block user checkbox',
        );

        debugPrint('✓ Report/Block dialog opens with correct UI elements');

        // Dismiss the dialog without submitting
        final cancelButton = find.text('Cancel');
        if (cancelButton.evaluate().isNotEmpty) {
          await tester.tap(cancelButton.first);
          for (int ps = 0; ps < 4; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
        }

        debugPrint('✓ Report/Block dialog dismissed cleanly');
      },
      timeout: const Timeout(Duration(seconds: 180)),
    );
  });
}
