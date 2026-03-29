import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/post/widgets/display/reactions_display.dart';

import '../helpers/test_helpers.dart';

/// Creates a mock reaction event with the given emoji [key] sent by [sender],
/// referencing [parentEventId] as the annotated event.
MockEvent _createMockReactionEvent({
  required String key,
  required User sender,
  required String parentEventId,
  required Room room,
}) {
  final reactionEvent = MockEvent();

  final Map<String, dynamic> reactionContent = {
    'm.relates_to': {
      'rel_type': 'm.annotation',
      'event_id': parentEventId,
      'key': key,
    },
  };

  when(() => reactionEvent.content).thenReturn(reactionContent);
  when(() => reactionEvent.eventId).thenReturn('\$reaction_${key.hashCode}');
  when(() => reactionEvent.type).thenReturn('m.reaction');
  when(() => reactionEvent.body).thenReturn('');
  when(() => reactionEvent.room).thenReturn(room);
  when(() => reactionEvent.senderId).thenReturn(sender.id);
  when(() => reactionEvent.senderFromMemoryOrFallback).thenReturn(sender);
  // getDisplayEvent returns itself (no edits for reactions)
  when(() => reactionEvent.getDisplayEvent(any())).thenReturn(reactionEvent);
  when(() => reactionEvent.originServerTs).thenReturn(DateTime.now());

  return reactionEvent;
}

void main() {
  setUpTestInfrastructure();

  group('ReactionsDisplay Widget', () {
    late MockClient mockClient;
    late MockRoom mockRoom;
    late MockEvent mockEvent;
    late MockUser mockSender;
    late MockTimeline mockTimeline;

    setUp(() {
      mockClient = MockClient();
      mockSender = createMockUser(
        id: '@user:matrix.org',
        displayName: 'Test User',
      );
      mockRoom = createMockRoom(name: 'Test Room', id: '!room:matrix.org');
      mockTimeline = MockTimeline();
      mockEvent = createMockEvent(
        type: 'm.room.message',
        body: 'Test message',
        room: mockRoom,
        sender: mockSender,
      );
      when(() => mockClient.userID).thenReturn('@me:matrix.org');
      when(
        () =>
            mockRoom.getTimeline(eventContextId: any(named: 'eventContextId')),
      ).thenAnswer((_) async => mockTimeline);
    });

    testWidgets('Renders empty when no reactions exist', (
      WidgetTester tester,
    ) async {
      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn(<Event>{});

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );
      await tester.pump(); // allow FutureBuilder to complete

      expect(find.byType(ReactionsDisplay), findsOneWidget);
      // Empty wrap renders but no reaction chips
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('Renders emoji chips for each distinct reaction', (
      WidgetTester tester,
    ) async {
      // Arrange: two thumbs-up reactions from different users
      final sender2 = createMockUser(
        id: '@other:matrix.org',
        displayName: 'Other User',
      );
      final reaction1 = _createMockReactionEvent(
        key: '👍',
        sender: mockSender,
        parentEventId: r'$event123',
        room: mockRoom,
      );
      final reaction2 = _createMockReactionEvent(
        key: '👍',
        sender: sender2,
        parentEventId: r'$event123',
        room: mockRoom,
      );
      final heartReaction = _createMockReactionEvent(
        key: '❤️',
        sender: mockSender,
        parentEventId: r'$event123',
        room: mockRoom,
      );

      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn({reaction1, reaction2, heartReaction});
      when(() => mockEvent.eventId).thenReturn(r'$event123');

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );
      await tester.pump(); // trigger FutureBuilder
      await tester.pumpAndSettle(); // allow async loading to complete

      // Both distinct emoji should be rendered
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
    });

    testWidgets('Own reaction gets a circular border decoration', (
      WidgetTester tester,
    ) async {
      // Arrange: own reaction (senderId matches client.userID)
      final ownSender = createMockUser(
        id: '@me:matrix.org', // matches mockClient.userID above
        displayName: 'Me',
      );
      final ownReaction = _createMockReactionEvent(
        key: '🎉',
        sender: ownSender,
        parentEventId: r'$event123',
        room: mockRoom,
      );

      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn({ownReaction});
      when(() => mockEvent.eventId).thenReturn(r'$event123');

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Own reaction emoji renders
      expect(find.text('🎉'), findsOneWidget);

      // The container for an own reaction should have BoxDecoration with a border
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text('🎉'), matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, isNotNull);
    });

    testWidgets('Tooltip widget is present for rendered reactions', (
      WidgetTester tester,
    ) async {
      final reaction = _createMockReactionEvent(
        key: '🚀',
        sender: mockSender,
        parentEventId: r'$event123',
        room: mockRoom,
      );

      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn({reaction});
      when(() => mockEvent.eventId).thenReturn(r'$event123');

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify the reaction rendered
      expect(find.text('🚀'), findsOneWidget);

      // Verify a Tooltip widget wraps the reaction chip
      expect(
        find.ancestor(of: find.text('🚀'), matching: find.byType(Tooltip)),
        findsOneWidget,
      );

      // The tooltip message should reference the sender by including their name
      // or the i18n key (depending on translation loading in test environment).
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: find.text('🚀'), matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, isNotNull);
      expect(tooltip.message, isNotEmpty);
    });

    testWidgets('Long-press own reaction triggers redactEvent', (
      WidgetTester tester,
    ) async {
      // Create an own-reaction event whose redactEvent can be verified
      final ownSender = createMockUser(id: '@me:matrix.org', displayName: 'Me');
      final ownReaction = _createMockReactionEvent(
        key: '🔥',
        sender: ownSender,
        parentEventId: r'$event123',
        room: mockRoom,
      );
      when(() => ownReaction.redactEvent()).thenAnswer((_) async => null);

      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn({ownReaction});
      when(() => mockEvent.eventId).thenReturn(r'$event123');

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('🔥'), findsOneWidget);

      // Long-press the emoji
      await tester.longPress(find.text('🔥'));
      await tester.pumpAndSettle();

      // Verify redactEvent was called
      verify(() => ownReaction.redactEvent()).called(1);
    });

    testWidgets('Reactions from other users do not show border decoration', (
      WidgetTester tester,
    ) async {
      final otherSender = createMockUser(
        id: '@other:matrix.org',
        displayName: 'Other',
      );
      final otherReaction = _createMockReactionEvent(
        key: '😂',
        sender: otherSender,
        parentEventId: r'$event123',
        room: mockRoom,
      );

      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn({otherReaction});
      when(() => mockEvent.eventId).thenReturn(r'$event123');

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('😂'), findsOneWidget);

      // Other user's reaction should NOT have a border
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text('😂'), matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration as BoxDecoration?;
      // decoration is null OR has no border (because isOwnSmiley == false)
      expect(decoration?.border, isNull);
    });
  });
}
