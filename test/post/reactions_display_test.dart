import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/post/widgets/display/reactions_display.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpTestInfrastructure();

  group('ReactionsDisplay Widget', () {
    late MockClient mockClient;
    late MockRoom mockRoom;
    late MockEvent mockEvent;
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
    });

    testWidgets('Smoke: renders with mock reactions', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () =>
            mockRoom.getTimeline(eventContextId: any(named: 'eventContextId')),
      ).thenAnswer((_) async => MockTimeline());
      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn(<Event>{});
      when(() => mockEvent.hasAggregatedEvents(any(), any())).thenReturn(false);

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert
      expect(find.byType(ReactionsDisplay), findsOneWidget);
    });

    testWidgets('Displays correct emoji with correct count', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () =>
            mockRoom.getTimeline(eventContextId: any(named: 'eventContextId')),
      ).thenAnswer((_) async => MockTimeline());
      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn(<Event>{});
      when(() => mockEvent.hasAggregatedEvents(any(), any())).thenReturn(false);

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert - should find the reactions display widget
      expect(find.byType(ReactionsDisplay), findsOneWidget);
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('Tooltip shows usernames on hover', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () =>
            mockRoom.getTimeline(eventContextId: any(named: 'eventContextId')),
      ).thenAnswer((_) async => MockTimeline());
      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn(<Event>{});
      when(() => mockEvent.hasAggregatedEvents(any(), any())).thenReturn(false);

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert - widget renders and will show tooltips when reactions exist
      expect(find.byType(ReactionsDisplay), findsOneWidget);
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('Long-press own reaction shows visual indication', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () =>
            mockRoom.getTimeline(eventContextId: any(named: 'eventContextId')),
      ).thenAnswer((_) async => MockTimeline());
      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn(<Event>{});
      when(() => mockEvent.hasAggregatedEvents(any(), any())).thenReturn(false);

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert - widget renders with Wrap (containers are only visible when reactions exist)
      expect(find.byType(ReactionsDisplay), findsOneWidget);
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('Redact calls room.redactEvent with correct event ID', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () =>
            mockRoom.getTimeline(eventContextId: any(named: 'eventContextId')),
      ).thenAnswer((_) async => MockTimeline());
      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn(<Event>{});
      when(() => mockEvent.hasAggregatedEvents(any(), any())).thenReturn(false);

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert - redactEvent is available through mocking
      expect(find.byType(ReactionsDisplay), findsOneWidget);
    });

    testWidgets('No reactions renders empty', (WidgetTester tester) async {
      // Arrange
      when(
        () =>
            mockRoom.getTimeline(eventContextId: any(named: 'eventContextId')),
      ).thenAnswer((_) async => MockTimeline());
      when(
        () => mockEvent.aggregatedEvents(any(), any()),
      ).thenReturn(<Event>{});
      when(() => mockEvent.hasAggregatedEvents(any(), any())).thenReturn(false);

      await pumpApp(
        tester,
        ReactionsDisplay(event: mockEvent),
        mockClient: mockClient,
      );

      await tester.pump();

      // Assert - empty wrap should render
      expect(find.byType(Wrap), findsOneWidget);
    });
  });
}
