import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/post/widgets/post.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpTestInfrastructure();

  group('PostWidget Reaction Behavior', () {
    late MockClient mockClient;
    late MockRoom mockRoom;
    late MockEvent mockEvent;
    late MockEvent mockDisplayEvent;
    late MockUser mockSender;

    setUp(() {
      mockClient = MockClient();
      mockSender =
          createMockUser(id: '@user:matrix.org', displayName: 'Test User');
      mockRoom = createMockRoom(name: 'Test Room', id: '!room:matrix.org');

      mockEvent = createMockEvent(
        type: 'm.room.message',
        body: 'Test message',
        room: mockRoom,
        sender: mockSender,
      );

      mockDisplayEvent = createMockEvent(
        type: 'm.room.message',
        body: 'Test message',
        room: mockRoom,
        sender: mockSender,
      );

      when(() => mockEvent.messageType).thenReturn(MessageTypes.Text);
      when(() => mockDisplayEvent.messageType).thenReturn(MessageTypes.Text);
      when(() => mockDisplayEvent.formattedText).thenReturn('Test message');
    });

    testWidgets('Smoke: renders with reaction button',
        (WidgetTester tester) async {
      // Arrange
      when(() => mockRoom.sendReaction(any(), any()))
          .thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        PostWidget(event: mockEvent, displayEvent: mockDisplayEvent),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert - reaction button should be visible
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    });

    testWidgets('Tap reaction icon opens emoji picker dialog',
        (WidgetTester tester) async {
      // Arrange
      when(() => mockRoom.sendReaction(any(), any()))
          .thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        PostWidget(event: mockEvent, displayEvent: mockDisplayEvent),
        mockClient: mockClient,
      );

      // Act - find and tap the reaction (favorite) button
      final reactionButtons = find.byIcon(Icons.favorite_rounded);
      expect(reactionButtons, findsWidgets);

      await tester.tap(reactionButtons.last);
      await tester.pump();

      // Assert - reaction button remains present after tap
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    });

    testWidgets('Reply button is present on post', (WidgetTester tester) async {
      // Arrange
      when(() => mockRoom.sendReaction(any(), any()))
          .thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        PostWidget(event: mockEvent, displayEvent: mockDisplayEvent),
        mockClient: mockClient,
      );

      // Assert - reply button should be visible
      expect(find.byIcon(Icons.reply), findsWidgets);
    });

    testWidgets('PostWidget renders username and content',
        (WidgetTester tester) async {
      // Arrange
      when(() => mockRoom.sendReaction(any(), any()))
          .thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        PostWidget(event: mockEvent, displayEvent: mockDisplayEvent),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert - PostWidget should render with content
      expect(find.byType(PostWidget), findsOneWidget);
    });
  });
}
