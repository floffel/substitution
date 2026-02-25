import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matrix/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:substitution/settings/widgets/dialogcreateroom.dart';
import 'package:substitution/feed/pages/home.dart' as home_page;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart';

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

  group('Create Room explicitly on Follow Feeds with Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    Database? sqliteDatabase;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;

      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

      // Use databaseFactory to safely delete the database file
      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final dbPath = '${appDocDir.path}/matrix_database.db';
          await databaseFactory.deleteDatabase(dbPath);
        } catch (e) {
          debugPrint("Failed to delete database in setUp: $e");
        }
      }

      // Initialize a useless sqliteDatabase just to satisfy any local references
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
          // Ignore
        }
      }
      try {
        await app.globalMatrixClient?.dispose();
        app.globalMatrixClient = null;
      } catch (e) {
        // Ignore dispose errors
      }

      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final dbPath = '${appDocDir.path}/matrix_database.db';
          await databaseFactory.deleteDatabase(dbPath);
        } catch (e) {
          debugPrint("Failed to delete database in tearDown: $e");
        }
      }
    });

    Future<void> loginUser(WidgetTester tester) async {
      final client = app.globalMatrixClient!;

      debugPrint("Starting programmatic login for test user...");
      client.homeserver = Uri.parse(testMatrixServer);
      await client.checkHomeserver(client.homeserver!);

      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      debugPrint("Login success, navigating to Feed...");
      // Use the root Scaffold context — IntroductionPage may have already been
      // replaced by the router after programmatic login.
      final navContext =
          find.byType(Scaffold).evaluate().isNotEmpty
              ? tester.element(find.byType(Scaffold).first)
              : tester.element(find.byType(app.IntroductionPage));
      GoRouter.of(navContext).go("/");

      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byIcon(Icons.menu).evaluate().isNotEmpty) break;
      }
    }

    testWidgets(
      'User can create a room from Follow feeds',
      (WidgetTester tester) async {
        app.main();
        await waitForMatrixClient(tester);

        await loginUser(tester);

        // Verify we are on the Feed
        bool foundFeed = false;
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(home_page.HomePage).evaluate().isNotEmpty ||
              find.byIcon(Icons.menu).evaluate().isNotEmpty) {
            foundFeed = true;
            break;
          }
        }

        if (!foundFeed) {
          fail("UI stayed on Introduction/Login page after programmatic auth");
        }

        // Navigate directly to the Follow Feeds page using GoRouter
        final targetContext = tester.element(find.byType(Scaffold).first);
        GoRouter.of(targetContext).push("/settings/feed");

        // Wait for push transition to Follow Feeds settings page
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Find and tap the Create Room button
        final createRoomButton = find.widgetWithText(
          ActionChip,
          "settings.ownfeeds.buttons.create_room".tr(),
        );
        expect(
          createRoomButton,
          findsOneWidget,
          reason: 'Create Room button should be visible',
        );

        await tester.tap(createRoomButton);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Wait for the dialog to appear
        expect(
          find.byType(DialogCreateRoom),
          findsOneWidget,
          reason: 'Create room dialog should open',
        );

        // Find text fields via their labels
        final nameField = find.widgetWithText(
          TextFormField,
          "settings.dialog.create.placeholder_name".tr(),
        );
        final aliasField = find.widgetWithText(
          TextFormField,
          "settings.dialog.create.placeholder_alias".tr(),
        );
        final topicField = find.widgetWithText(
          TextFormField,
          "settings.dialog.create.placeholder_topic".tr(),
        );

        expect(nameField, findsOneWidget);
        expect(aliasField, findsOneWidget);
        expect(topicField, findsOneWidget);

        // Use a unique name for the test room
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final generatedRoomName = 'test_room_$timestamp';

        await tester.enterText(nameField, generatedRoomName);
        await tester.enterText(aliasField, 'alias_$timestamp');
        await tester.enterText(topicField, 'A room generated by e2e test');
        await tester.pump();

        // Submit the form
        final submitButton = find.widgetWithText(
          TextButton,
          'settings.dialog.create.submit'.tr(),
        );
        expect(submitButton, findsOneWidget);

        await tester.tap(submitButton);

        // Wait for network response and dialog to dismiss
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(DialogCreateRoom).evaluate().isEmpty) {
            break;
          }
        }

        expect(
          find.byType(DialogCreateRoom),
          findsNothing,
          reason: 'Dialog should be dismissed after a successful creation.',
        );

        // The list should now have been refreshed from the Matrix servers. Let's see if the newly created room is found.
        // On follow feeds, "test_" search will bring it up. Or we can just search explicitly.
        final searchField = find.byType(TextFormField);
        expect(
          searchField,
          findsOneWidget,
          reason: 'Room search input should be visible',
        );

        await tester.enterText(searchField, generatedRoomName);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.testTextInput.receiveAction(TextInputAction.done);

        // Wait for debouncing and network resolution
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find
              .textContaining(generatedRoomName, skipOffstage: false)
              .evaluate()
              .isEmpty) {
            // not found yet
          } else {
            break;
          }
        }

        // Assuming test user actually created it correctly and is joined:
        // Actually newly created rooms might not immediately show in queryPublicRooms depending on matrix config,
        // but it will be in the user's joined rooms which FollowFeed _fetchRooms maps into it if it was returned by sync.
        expect(
          find.textContaining(generatedRoomName, skipOffstage: false),
          findsWidgets,
          reason: 'Newly created room should appear in follow feeds list.',
        );
      },
      timeout: const Timeout(Duration(seconds: 180)),
    );
  });
}
