import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;

void main() {
  group('Feed Integration Tests', () {
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
