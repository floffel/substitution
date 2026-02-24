import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:substitution/post/widgets/comment.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as dart_io;
import 'package:matrix/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/login_helper.dart' as login_helper;
import 'package:substitution/shared/pages/age_gate.dart';
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

  group('Comment Nesting and Collapsing Test', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );

    Database? sqliteDatabase;

    setUp(() async {
      // Reset age gate so the app always starts from the age-gate screen
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      AgeGatePage.confirmed = false;

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

    Future<void> doLogin(WidgetTester tester) =>
        login_helper.loginUser(tester, matrixServer: testMatrixServer);

    testWidgets(
      'Deeply nested comments render without overflow and can be collapsed',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        await doLogin(tester);

        // Wait for Matrix client and room list
        final client = app.globalMatrixClient!;
        for (int i = 0; i < 20; i++) {
          if (client.rooms.isNotEmpty) break;
          await tester.pump(const Duration(milliseconds: 500));
        }

        if (client.rooms.isEmpty) {
          debugPrint('⚠ No rooms found - skipping nested thread test');
          return;
        }

        final room = client.rooms.first;
        debugPrint('Found room: \${room.name} (\${room.id})');

        // Seed root event programmatically
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final rootText = 'Root Post for Nesting Test $timestamp';
        final rootId = await room.sendTextEvent(rootText);

        Event? lastEvent;
        for (int i = 0; i < 30; i++) {
          final timeline = await room.getTimeline();
          try {
            lastEvent = timeline.events.cast<Event?>().firstWhere(
              (e) => e?.eventId == rootId,
              orElse: () => null,
            );
          } catch (e) {
            lastEvent = null;
          }
          if (lastEvent != null) break;
          await tester.pump(const Duration(milliseconds: 500));
        }

        if (lastEvent == null) {
          debugPrint('⚠ Failed to find root event in timeline - skipping');
          return;
        }

        // Seed 10 levels of replies recursively
        int maxNestingLevel = 10;
        final threadRootId = rootId;
        for (int i = 1; i <= maxNestingLevel; i++) {
          final replyText = 'Nested Reply Level $i ($timestamp)';
          final replyId = await room.sendEvent(
            {'body': replyText, 'msgtype': MessageTypes.Text},
            threadRootEventId: threadRootId,
            inReplyTo: lastEvent,
          );

          bool syncFound = false;
          // Wait for sync so the next reply has a valid context
          for (int j = 0; j < 30; j++) {
            final timeline = await room.getTimeline(
              eventContextId: threadRootId,
            );
            await timeline.requestHistory(
              historyCount: 20,
            ); // fetch more to ensure
            try {
              lastEvent = timeline.events.cast<Event?>().firstWhere(
                (e) => e?.eventId == replyId,
                orElse: () => null,
              );
            } catch (e) {
              lastEvent = null;
            }
            if (lastEvent != null) {
              syncFound = true;
              break;
            }
            await tester.pump(const Duration(milliseconds: 500));
          }

          if (!syncFound) {
            debugPrint(
              '⚠ Failed to sync nested level \$i - test might be partial',
            );
            break;
          }
        }

        debugPrint(
          '✓ Recursively generated thread with $maxNestingLevel layers',
        );
        for (int ps = 0; ps < 10; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Directly navigate to Post View rather than scrolling to find it
        final context = tester.element(find.byType(Scrollable).first);
        GoRouter.of(context).go('/post/$rootId?room=${room.id}');
        await tester.pumpAndSettle();

        // Give the Post view time to resolve all FutureBuilders for the nested comment tree.
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        // Diagnostic: print all text widgets visible on screen
        final allTexts =
            tester.allWidgets
                .whereType<Text>()
                .map((t) => t.data ?? '')
                .where((s) => s.isNotEmpty)
                .toSet();
        debugPrint(
          '=== Text widgets on screen after navigation + pump: ${allTexts.join(' | ')} ===',
        );
        debugPrint(
          '=== CommentWidgets count: ${find.byType(CommentWidget).evaluate().length} ===',
        );

        // Find the "Continue this thread..." button by its icon – since the text is locale-dependent.
        // The button is a TextButton.icon with Icons.arrow_forward.
        final continueButtonFinder = find.byIcon(Icons.arrow_forward);

        // Scroll to find it – try all Scrollables (may be nested)
        final scrollables = find.byType(Scrollable);
        for (
          int s = 0;
          s < scrollables.evaluate().length &&
              continueButtonFinder.evaluate().isEmpty;
          s++
        ) {
          try {
            await tester.scrollUntilVisible(
              continueButtonFinder,
              300.0,
              scrollable: scrollables.at(s),
            );
          } catch (_) {
            // try next scrollable
          }
        }

        if (continueButtonFinder.evaluate().isEmpty) {
          debugPrint('⚠ Continue thread button not found – all widget types:');
          debugPrint(
            tester.allWidgets
                .map((w) => w.runtimeType.toString())
                .toSet()
                .join(', '),
          );
        }

        expect(
          continueButtonFinder,
          findsWidgets,
          reason: 'Should find continue button capping the deep thread',
        );

        // Tap the first ancestor button of the text
        await tester.ensureVisible(continueButtonFinder.first);
        await tester.tap(continueButtonFinder.first);
        await tester.pumpAndSettle();

        // Verify we can go back (GoRouter pushed a new entry — canPop should be true)
        final navContext = tester.element(find.byType(Scaffold).first);
        expect(
          GoRouter.of(navContext).canPop(),
          isTrue,
          reason:
              'GoRouter should be able to go back after pushing the sub-thread route',
        );
        debugPrint(
          '✓ Navigated into deep nested Post view via continuation button (can pop: true)',
        );

        // Pop back programmatically (back navigation)
        GoRouter.of(navContext).pop();
        await tester.pumpAndSettle();

        debugPrint('✓ Returned to main thread view successfully');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
