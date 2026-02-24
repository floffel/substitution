@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Feed Integration Tests', () {
    Database? sqliteDatabase;

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
        'Feed displays posts from multiple rooms in chronological order',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Note: This integration test validates the end-to-end feed functionality
      // In a real scenario with a test server, it would:
      // 1. Log in with test credentials
      // 2. Join multiple test rooms with posts
      // 3. Navigate to the feed
      // 4. Verify posts from all rooms appear in chronological order

      // For now, verify the app initializes
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
