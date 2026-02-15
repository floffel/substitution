import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:matrix/matrix.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding & Login Flow with Real Matrix Server', () {
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

    testWidgets(
      'Complete onboarding: host selection -> login -> view feed',
      (WidgetTester tester) async {
        // Start the app
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify we start at the introduction page
        expect(find.byType(MaterialApp), findsWidgets);

        // Step 1: Enter homeserver URL
        // Find the homeserver input field
        final hostInputFinder = find.byType(TextFormField).first;
        await tester.enterText(hostInputFinder, testMatrixServer);
        await tester.pumpAndSettle();

        // Tap the submit button
        final submitButtonFinder = find.byType(ElevatedButton).first;
        await tester.tap(submitButtonFinder);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Step 2: Enter credentials and login
        // Find username field (should be on login page now)
        final usernameFieldFinder = find.byType(TextFormField).first;
        await tester.enterText(usernameFieldFinder, testUser);
        await tester.pumpAndSettle();

        // Find password field (usually the second field)
        final passwordFieldFinder = find.byType(TextFormField).at(1);
        await tester.enterText(passwordFieldFinder, testPassword);
        await tester.pumpAndSettle();

        // Tap login button
        final loginButtonFinder = find.byType(ElevatedButton).first;
        await tester.tap(loginButtonFinder);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Step 3: Verify we're logged in and at the feed
        // The feed page should be displayed
        expect(find.byType(ListView), findsWidgets);

        // Should not see login/intro UI anymore
        expect(
          find.byType(TextFormField),
          findsNothing,
          reason: 'Login form should not be visible after successful login',
        );

        debugPrint('✓ Onboarding and login completed successfully');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    testWidgets(
      'Login with invalid credentials shows error',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Enter homeserver
        final hostInputFinder = find.byType(TextFormField).first;
        await tester.enterText(hostInputFinder, testMatrixServer);
        await tester.pumpAndSettle();

        final submitButtonFinder = find.byType(ElevatedButton).first;
        await tester.tap(submitButtonFinder);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Enter wrong credentials
        final usernameFieldFinder = find.byType(TextFormField).first;
        await tester.enterText(usernameFieldFinder, 'nonexistent_user');
        await tester.pumpAndSettle();

        final passwordFieldFinder = find.byType(TextFormField).at(1);
        await tester.enterText(passwordFieldFinder, 'wrong_password');
        await tester.pumpAndSettle();

        // Tap login
        final loginButtonFinder = find.byType(ElevatedButton).first;
        await tester.tap(loginButtonFinder);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify error dialog appears
        expect(
          find.byType(AlertDialog),
          findsWidgets,
          reason: 'Error dialog should appear on failed login',
        );

        debugPrint('✓ Invalid credentials properly rejected');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    testWidgets(
      'User can choose different homeserver',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Find homeserver field
        final hostInputFinder = find.byType(TextFormField).first;

        // Enter custom homeserver
        await tester.tap(hostInputFinder);
        await tester.pumpAndSettle();

        // Enter test homeserver
        await tester.enterText(hostInputFinder, testMatrixServer);
        await tester.pumpAndSettle();

        // Verify it was entered
        expect(find.text(testMatrixServer), findsWidgets);

        debugPrint('✓ Homeserver selection working');
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
