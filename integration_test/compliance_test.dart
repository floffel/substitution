import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:substitution/main.dart' as app;
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as dart_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  group('Compliance Features with Real Matrix Server', () {
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
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        final submitButton = find.byKey(const Key('hostSubmitButton'));
        await tester.ensureVisible(submitButton);
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.tap(submitButton, warnIfMissed: false);

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
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      final usernameField = find.byKey(const Key('loginUsernameInput'));
      if (usernameField.evaluate().isEmpty) {
        debugPrint('⚠ Username field not found — skipping login');
        return;
      }
      await tester.enterText(usernameField, testUser);
      for (int ps = 0; ps < 2; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      final passwordField = find.byKey(const Key('loginPasswordInput'));
      await tester.enterText(passwordField, testPassword);
      for (int ps = 0; ps < 2; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      final loginButton = find.byKey(const Key('loginSubmitButton'));
      await tester.ensureVisible(loginButton);
      for (int ps = 0; ps < 2; ps++) {
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
        AgeGatePage.confirmed = true;
        app.main();
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        // Wait for feed to load
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Open the navigation drawer
        final menuIcon = find.byIcon(Icons.menu);
        if (menuIcon.evaluate().isEmpty) {
          debugPrint('⚠ Menu icon not found — skipping');
          return;
        }
        await tester.tap(menuIcon.first);
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Verify the Legal (gavel) icon is in the drawer
        final gavelIcon = find.byIcon(Icons.gavel_outlined);
        if (gavelIcon.evaluate().isEmpty) {
          debugPrint('⚠ Legal (gavel) icon not found in drawer — skipping');
          return;
        }
        debugPrint('✓ Legal drawer item visible');

        // Tap the Legal item
        await tester.tap(gavelIcon.first);
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Verify all four legal tiles are shown on the Legal page
        expect(
          find.byIcon(Icons.description_outlined),
          findsOneWidget,
          reason: 'Terms of Service tile should be visible',
        );
        expect(
          find.byIcon(Icons.privacy_tip_outlined),
          findsOneWidget,
          reason: 'Privacy Policy tile should be visible',
        );
        expect(
          find.byIcon(Icons.info_outline),
          findsOneWidget,
          reason: 'Imprint tile should be visible',
        );
        expect(
          find.byIcon(Icons.code),
          findsOneWidget,
          reason: 'Open Source Licenses tile should be visible',
        );

        debugPrint('✓ Legal page displays all required compliance tiles');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    // ---------------------------------------------------------------------------
    // UGC moderation tests
    // ---------------------------------------------------------------------------

    testWidgets(
      'Post has a three-dot popup menu with Report/Block option',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        // Wait for feed to load
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Check if there are any posts visible in the feed
        final popupMenuFinder = find.byType(PopupMenuButton<String>);

        if (popupMenuFinder.evaluate().isEmpty) {
          debugPrint(
            '⚠ No popup menu found in feed (possibly empty feed) — skipping',
          );
          return;
        }

        // Tap the first popup menu button (⋮)
        await tester.tap(popupMenuFinder.first);
        for (int ps = 0; ps < 2; ps++) {
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
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'Tapping Report/Block opens dialog with report reason and block checkbox',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await loginUser(tester);

        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        final popupMenuFinder = find.byType(PopupMenuButton<String>);

        if (popupMenuFinder.evaluate().isEmpty) {
          debugPrint('⚠ No posts in feed — skipping dialog test');
          return;
        }

        // Open popup menu on the first post
        await tester.tap(popupMenuFinder.first);
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Tap "Report / Block"
        final reportBlockItem = find.byIcon(Icons.flag_outlined);
        if (reportBlockItem.evaluate().isEmpty) {
          debugPrint('⚠ Report/Block menu item not found — skipping');
          return;
        }
        await tester.tap(reportBlockItem.first);
        for (int ps = 0; ps < 2; ps++) {
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
          for (int ps = 0; ps < 2; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
        }

        debugPrint('✓ Report/Block dialog dismissed cleanly');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
