import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/post/widgets/post.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpTestInfrastructure();

  group('PostWidget Reply Behavior', () {
    late MockClient mockClient;
    late MockRoom mockRoom;
    late MockEvent mockEvent;
    late MockEvent mockDisplayEvent;
    late MockUser mockSender;

    setUp(() {
      mockClient = MockClient();
      mockSender = createMockUser(
        id: '@user:matrix.org',
        displayName: 'Test User',
      );
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

    testWidgets('Reply button is present on PostWidget', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () => mockRoom.sendReaction(any(), any()),
      ).thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        PostWidget(event: mockEvent, displayEvent: mockDisplayEvent),
        mockClient: mockClient,
      );

      // Act
      final replyButton = find.byIcon(Icons.chat_bubble_outline);

      // Assert
      expect(replyButton, findsWidgets);
    });

    testWidgets('PostWidget with event shows correct structure', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () => mockRoom.sendReaction(any(), any()),
      ).thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        PostWidget(event: mockEvent, displayEvent: mockDisplayEvent),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert
      expect(find.byType(PostWidget), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsWidgets);
      expect(find.byIcon(Icons.favorite_border), findsWidgets);
    });

    testWidgets('Reply button and reaction button coexist', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () => mockRoom.sendReaction(any(), any()),
      ).thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        PostWidget(event: mockEvent, displayEvent: mockDisplayEvent),
        mockClient: mockClient,
      );

      // Act & Assert
      expect(find.byIcon(Icons.chat_bubble_outline), findsWidgets);
      expect(find.byIcon(Icons.favorite_border), findsWidgets);
    });

    testWidgets('PostWidget renders without errors', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () => mockRoom.sendReaction(any(), any()),
      ).thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        PostWidget(event: mockEvent, displayEvent: mockDisplayEvent),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert - widget should be built
      expect(find.byType(PostWidget), findsOneWidget);
    });
  });
}
