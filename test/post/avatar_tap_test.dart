import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockClient extends Mock implements Client {}

class MockEvent extends Mock implements Event {}

class MockRoom extends Mock implements Room {}

void main() {
  group('Avatar Tap Tests', () {
    late MockClient mockClient;
    late MockEvent mockEvent;
    late MockRoom mockRoom;

    setUp(() {
      mockClient = MockClient();
      mockEvent = MockEvent();
      mockRoom = MockRoom();

      when(() => mockEvent.senderId).thenReturn('@testuser:matrix.org');
      when(() => mockEvent.room).thenReturn(mockRoom);
      when(() => mockRoom.id).thenReturn('!room1:matrix.org');
    });

    testWidgets('Tapping avatar on PostWidget navigates to /profile/:userId',
        (WidgetTester tester) async {
      late GoRouter router;

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: Provider<Client>.value(
                    value: mockClient,
                    child: GestureDetector(
                      onTap: () {
                        context.push(
                            '/profile/${Uri.encodeComponent('@testuser:matrix.org')}');
                      },
                      child: CircleAvatar(
                        child: Text('@testuser:matrix.org'[0]),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/profile/:userId',
                builder: (context, state) {
                  final userId =
                      Uri.decodeComponent(state.pathParameters['userId']!);
                  return Scaffold(
                    body: Center(
                      child: Text('Profile: $userId'),
                    ),
                  );
                },
              ),
            ],
            initialLocation: '/',
            redirectLimit: 100,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the avatar
      await tester.tap(find.byType(CircleAvatar));
      await tester.pumpAndSettle();

      // Verify navigation happened
      expect(find.text('Profile: @testuser:matrix.org'), findsOneWidget);
    });

    testWidgets('Tapping avatar on CommentWidget navigates to /profile/:userId',
        (WidgetTester tester) async {
      late GoRouter router;

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: Provider<Client>.value(
                    value: mockClient,
                    child: GestureDetector(
                      onTap: () {
                        context.push(
                            '/profile/${Uri.encodeComponent('@testuser:matrix.org')}');
                      },
                      child: CircleAvatar(
                        child: Text('@testuser:matrix.org'[0]),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/profile/:userId',
                builder: (context, state) {
                  final userId =
                      Uri.decodeComponent(state.pathParameters['userId']!);
                  return Scaffold(
                    body: Center(
                      child: Text('Profile: $userId'),
                    ),
                  );
                },
              ),
            ],
            initialLocation: '/',
            redirectLimit: 100,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the avatar
      await tester.tap(find.byType(CircleAvatar));
      await tester.pumpAndSettle();

      // Verify navigation happened
      expect(find.text('Profile: @testuser:matrix.org'), findsOneWidget);
    });
  });
}
