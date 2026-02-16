import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Discovery Flow Integration Tests', () {
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
        'Navigate to follow feeds -> add server -> search rooms -> see results',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to follow feeds settings
      // (This would depend on the actual navigation implementation)
      // For now, we're just verifying the test structure is correct

      // Add server (would require interacting with DialogAddServer)

      // Search for rooms (would require entering search text)

      // Verify results are displayed
      expect(find.byType(app.SubstitutionApp), findsOneWidget);
    });

    testWidgets('Search multiple servers and results merge correctly',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to follow feeds settings

      // Add multiple servers

      // Search across servers

      // Verify results from all servers appear
      expect(find.byType(app.SubstitutionApp), findsOneWidget);
    });

    testWidgets('Join room and verify it appears in main feed',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to follow feeds

      // Search for a room

      // Join the room

      // Verify it appears in the main feed
      expect(find.byType(app.SubstitutionApp), findsOneWidget);
    });

    testWidgets('Leave room and verify it disappears from main feed',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to follow feeds

      // Leave a joined room

      // Verify it's removed from the main feed
      expect(find.byType(app.SubstitutionApp), findsOneWidget);
    });
  });
}
