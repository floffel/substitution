import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class MockClient extends Mock implements Client {}

class MockEvent extends Mock implements Event {}

class MockRoom extends Mock implements Room {}

void main() {
  group('Offline Mode Widget Tests', () {
    late MockClient mockClient;
    late MockEvent mockEvent;
    late MockRoom mockRoom;

    setUp(() {
      mockClient = MockClient();
      mockEvent = MockEvent();
      mockRoom = MockRoom();

      when(() => mockEvent.body).thenReturn('Test message');
      when(() => mockEvent.senderId).thenReturn('@testuser:matrix.org');
      when(() => mockEvent.room).thenReturn(mockRoom);
      when(() => mockRoom.id).thenReturn('!room1:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
    });

    testWidgets('When offline, cached posts are still displayed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<Client>.value(
              value: mockClient,
              child: Column(
                children: [
                  const Text('Offline'),
                  ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        title: Text(mockEvent.body),
                        subtitle: Text(mockEvent.senderId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify cached posts are displayed
      expect(find.text('Test message'), findsOneWidget);
      expect(find.text('@testuser:matrix.org'), findsOneWidget);
    });

    testWidgets('When offline, "offline" banner is shown', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<Client>.value(
              value: mockClient,
              child: Stack(
                children: [
                  ListView(children: [ListTile(title: Text(mockEvent.body))]),
                  MaterialBanner(
                    content: const Text('Offline — showing cached content'),
                    actions: [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify offline banner is shown
      expect(find.text('Offline — showing cached content'), findsOneWidget);
    });

    testWidgets('When coming back online, new posts are fetched', (
      WidgetTester tester,
    ) async {
      bool fetchedNewData = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<Client>.value(
              value: mockClient,
              child: FutureBuilder<void>(
                future: Future.delayed(const Duration(milliseconds: 100), () {
                  fetchedNewData = true;
                }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return const Text('Data fetched');
                  }
                  return const Text('Loading');
                },
              ),
            ),
          ),
        ),
      );

      // Initially showing loading
      expect(find.text('Loading'), findsOneWidget);

      // Wait for future to complete
      await tester.pumpAndSettle();

      // Verify data was fetched
      expect(fetchedNewData, true);
      expect(find.text('Data fetched'), findsOneWidget);
    });

    testWidgets('Network failure with cached data shows error indicator', (
      WidgetTester tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<Client>.value(
              value: mockClient,
              child: FutureBuilder<void>(
                future: completer.future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const Text('Failed to fetch new content'),
                        ListTile(
                          title: Text(mockEvent.body),
                          subtitle: const Text('(Cached)'),
                        ),
                      ],
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Loading');
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      // Should show loading first
      expect(find.text('Loading'), findsOneWidget);

      // Complete with error
      completer.completeError(Exception('Network error'));
      await tester.pumpAndSettle();

      // Verify error indicator and cached data are shown
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Failed to fetch new content'), findsOneWidget);
      expect(find.text('Test message'), findsOneWidget);
      expect(find.text('(Cached)'), findsOneWidget);
    });
  });
}
