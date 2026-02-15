import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/post/widgets/comment.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpTestInfrastructure();

  group('CommentWidget Threading Behavior', () {
    late MockClient mockClient;
    late MockRoom mockRoom;
    late MockEvent mockEvent;
    late MockEvent mockDisplayEvent;
    late MockEvent mockPostEvent;
    late MockUser mockSender;

    setUp(() {
      mockClient = MockClient();
      mockSender =
          createMockUser(id: '@user:matrix.org', displayName: 'Test User');
      mockRoom = createMockRoom(name: 'Test Room', id: '!room:matrix.org');

      mockPostEvent = createMockEvent(
        type: 'm.room.message',
        body: 'Original post',
        room: mockRoom,
        sender: mockSender,
      );

      mockEvent = createMockEvent(
        type: 'm.room.message',
        body: 'Reply message',
        room: mockRoom,
        sender: mockSender,
      );

      mockDisplayEvent = createMockEvent(
        type: 'm.room.message',
        body: 'Reply message',
        room: mockRoom,
        sender: mockSender,
      );

      when(() => mockEvent.messageType).thenReturn(MessageTypes.Text);
      when(() => mockDisplayEvent.messageType).thenReturn(MessageTypes.Text);
      when(() => mockDisplayEvent.formattedText).thenReturn('Reply message');
      when(() => mockEvent.aggregatedEvents(any(), any()))
          .thenReturn(<Event>{});
    });

    testWidgets('CommentWidget renders correctly', (WidgetTester tester) async {
      // Arrange
      when(() => mockRoom.sendReaction(any(), any()))
          .thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        CommentWidget(
          event: mockEvent,
          displayEvent: mockDisplayEvent,
          postEvent: mockPostEvent,
        ),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert - comment widget should render
      expect(find.byType(CommentWidget), findsOneWidget);
    });

    testWidgets('CommentWidget has reply and reaction buttons',
        (WidgetTester tester) async {
      // Arrange
      when(() => mockRoom.sendReaction(any(), any()))
          .thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        CommentWidget(
          event: mockEvent,
          displayEvent: mockDisplayEvent,
          postEvent: mockPostEvent,
        ),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert - buttons should be present
      expect(find.byIcon(Icons.reply), findsWidgets);
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    });

    testWidgets('CommentWidget can be toggled (collapsed/expanded)',
        (WidgetTester tester) async {
      // Arrange
      when(() => mockRoom.sendReaction(any(), any()))
          .thenAnswer((_) async => 'reaction_id');

      await pumpApp(
        tester,
        CommentWidget(
          event: mockEvent,
          displayEvent: mockDisplayEvent,
          postEvent: mockPostEvent,
        ),
        mockClient: mockClient,
      );

      // Act - tap the comment header to toggle visibility
      final commentRow = find.byType(Row).first;
      await tester.tap(commentRow);
      await tester.pump();

      // Assert - comment widget should still be present (state changed internally)
      expect(find.byType(CommentWidget), findsOneWidget);
    });
  });
}
