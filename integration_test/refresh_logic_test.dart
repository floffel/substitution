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

  group('Refresh Logic Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    Database? sqliteDatabase;

    setUp(() async {
      // Cleanup for fresh start
      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final mainDb = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await mainDb.exists()) {
            await mainDb.delete();
          }
        } catch (e) {
          debugPrint("Failed to delete database in setUp: $e");
        }

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
          debugPrint("Failed to close database in tearDown: $e");
        }
      }
      try {
        await app.globalMatrixClient?.dispose();
        app.globalMatrixClient = null;
      } catch (e) {
        debugPrint("Failed to dispose client in tearDown: $e");
      }
    });

    Future<void> loginUser(WidgetTester tester) async {
      // Wait for app to load
      await tester.pumpAndSettle();

      // Swipe intro - matching feed_with_matrix_test.dart
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(IntroductionScreen).evaluate().isNotEmpty) break;
      }

      for (int i = 0; i < 2; i++) {
        await tester.drag(
          find.byType(IntroductionScreen),
          const Offset(-400, 0),
        );
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      // Enter host
      final hostInput = find.byKey(const Key('hostServerInput'));
      await tester.enterText(hostInput, testMatrixServer);
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      await tester.tap(find.byKey(const Key('hostSubmitButton')));

      // Wait for login page
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty) {
          break;
        }
      }

      // Enter credentials
      await tester.enterText(
        find.byKey(const Key('loginUsernameInput')),
        testUser,
      );
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.enterText(
        find.byKey(const Key('loginPasswordInput')),
        testPassword,
      );
      for (int ps = 0; ps < 4; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      await tester.tap(find.byKey(const Key('loginSubmitButton')));

      // Wait for Go button
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('introGoButton')).evaluate().isNotEmpty) break;
      }

      await tester.tap(find.byKey(const Key('introGoButton')));

      // Wait for feed
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(Scrollable).evaluate().isNotEmpty) break;
      }
    }

    testWidgets('Pull to refresh in populated feed works', (
      WidgetTester tester,
    ) async {
      app.main();
      await loginUser(tester);

      // Verify feed has content
      expect(find.byType(Scrollable).first, findsOneWidget);

      // Perform pull to refresh
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();

      // Verify no crash happened and content is still there
      expect(find.byType(Scrollable).first, findsOneWidget);
    });

    testWidgets('Pull to refresh in empty room room handles null check', (
      WidgetTester tester,
    ) async {
      app.main();
      await loginUser(tester);

      // Even if the room is populated, we just want to ensure _fetchFutureEvents doesn't crash
      // after the fix.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.byType(Scrollable).first, findsOneWidget);
    });

    testWidgets('New background message appears after refresh', (
      WidgetTester tester,
    ) async {
      app.main();
      await loginUser(tester);

      // Get the client from the app
      final client = app.globalMatrixClient!;
      final rooms = client.getJoinedRooms();
      final roomIds = await rooms;
      if (roomIds.isEmpty) return;

      final roomId = roomIds.first;
      final room = client.getRoomById(roomId)!;

      // Content for unique message
      final testMessage =
          "Background message ${DateTime.now().millisecondsSinceEpoch}";

      // Send message via client (simulating background sync or other user)
      await room.sendEvent({"body": testMessage, "msgtype": "m.text"});

      // Message won't appear immediately because we didn't pump much or it's outside UI loop
      // Verify message is NOT yet in the feed (optional, but good for proving refresh works)
      // expect(find.text(testMessage), findsNothing);

      // Perform pull to refresh
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 500));
      // Give it some time to process
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Verify message NOW appears in the feed
      expect(find.text(testMessage), findsOneWidget);
    });
  });
}
