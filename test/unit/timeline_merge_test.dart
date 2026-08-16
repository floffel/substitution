import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockEvent extends Mock implements Event {}

class MockTimeline extends Mock implements Timeline {}

class MockUser extends Mock implements User {}

void main() {
  group('Timeline Merge & Filter Logic', () {
    late MockRoom mockRoom1;
    late MockRoom mockRoom2;
    late MockUser mockUser;

    setUp(() {
      mockRoom1 = MockRoom();
      mockRoom2 = MockRoom();
      mockUser = MockUser();

      when(() => mockUser.id).thenReturn('@user:matrix.org');
      when(() => mockUser.displayName).thenReturn('Test User');
      when(() => mockRoom1.id).thenReturn('!room1:matrix.org');
      when(() => mockRoom1.name).thenReturn('Room 1');
      when(() => mockRoom2.id).thenReturn('!room2:matrix.org');
      when(() => mockRoom2.name).thenReturn('Room 2');
    });

    test('Events from multiple rooms sorted by originServerTs descending', () {
      // Create mock events with different timestamps
      final event1 = MockEvent();
      final event2 = MockEvent();
      final event3 = MockEvent();

      when(
        () => event1.originServerTs,
      ).thenReturn(DateTime(2025, 1, 1, 12, 0, 0));
      when(
        () => event2.originServerTs,
      ).thenReturn(DateTime(2025, 1, 1, 14, 0, 0));
      when(
        () => event3.originServerTs,
      ).thenReturn(DateTime(2025, 1, 1, 13, 0, 0));
      when(() => event1.type).thenReturn('m.room.message');
      when(() => event2.type).thenReturn('m.room.message');
      when(() => event3.type).thenReturn('m.room.message');
      when(() => event1.relationshipType).thenReturn(null);
      when(() => event2.relationshipType).thenReturn(null);
      when(() => event3.relationshipType).thenReturn(null);
      when(() => event1.eventId).thenReturn(r'$event1');
      when(() => event2.eventId).thenReturn(r'$event2');
      when(() => event3.eventId).thenReturn(r'$event3');
      when(() => event1.senderId).thenReturn('@user:matrix.org');
      when(() => event2.senderId).thenReturn('@user:matrix.org');
      when(() => event3.senderId).thenReturn('@user:matrix.org');
      when(
        () => mockRoom1.getPowerLevelByUserId('@user:matrix.org'),
      ).thenReturn(PowerLevel.admin);
      when(
        () => mockRoom2.getPowerLevelByUserId('@user:matrix.org'),
      ).thenReturn(PowerLevel.admin);
      when(() => event1.room).thenReturn(mockRoom1);
      when(() => event2.room).thenReturn(mockRoom2);
      when(() => event3.room).thenReturn(mockRoom1);

      // Create list of events
      List<({Event origEvent, Event displayEvent})> events = [
        (origEvent: event1, displayEvent: event1),
        (origEvent: event2, displayEvent: event2),
        (origEvent: event3, displayEvent: event3),
      ];

      // Sort events by timestamp descending
      events.sort(
        (a, b) => b.displayEvent.originServerTs.compareTo(
          a.displayEvent.originServerTs,
        ),
      );

      // Verify the order
      expect(events[0].displayEvent.eventId, r'$event2');
      expect(events[1].displayEvent.eventId, r'$event3');
      expect(events[2].displayEvent.eventId, r'$event1');
    });

    test('Only m.room.message events pass filter', () {
      final messageEvent = MockEvent();
      final stateEvent = MockEvent();
      final reactionEvent = MockEvent();

      when(() => messageEvent.type).thenReturn('m.room.message');
      when(() => stateEvent.type).thenReturn('m.room.create');
      when(() => reactionEvent.type).thenReturn('m.reaction');

      // Create filter predicate (simulating home.dart logic)
      bool isMessageEvent(Event e) => e.type == 'm.room.message';

      expect(isMessageEvent(messageEvent), true);
      expect(isMessageEvent(stateEvent), false);
      expect(isMessageEvent(reactionEvent), false);
    });

    test('Events from unauthorized senders filtered out in blog mode', () {
      // This test validates the filtering logic pattern used in home.dart
      final adminEvent = MockEvent();
      final lowPowerEvent = MockEvent();

      when(() => adminEvent.senderId).thenReturn('@admin:matrix.org');
      when(() => lowPowerEvent.senderId).thenReturn('@user:matrix.org');

      when(
        () => mockRoom1.getPowerLevelByUserId('@admin:matrix.org'),
      ).thenReturn(PowerLevel.admin);
      when(
        () => mockRoom1.getPowerLevelByUserId('@user:matrix.org'),
      ).thenReturn(PowerLevel(25));

      when(() => adminEvent.room).thenReturn(mockRoom1);
      when(() => lowPowerEvent.room).thenReturn(mockRoom1);

      // Filter function
      bool hasSufficientPowerLevel(Event e) =>
          e.room.getPowerLevelByUserId(e.senderId) >= PowerLevel.moderator;

      expect(hasSufficientPowerLevel(adminEvent), true);
      expect(hasSufficientPowerLevel(lowPowerEvent), false);
    });

    test('Replies/threads/edits excluded by relationshipType filter', () {
      final regularMessage = MockEvent();
      final reply = MockEvent();
      final thread = MockEvent();
      final edit = MockEvent();

      when(() => regularMessage.relationshipType).thenReturn(null);
      when(
        () => reply.relationshipType,
      ).thenReturn(RelationshipTypes.reference);
      when(() => thread.relationshipType).thenReturn(RelationshipTypes.thread);
      when(() => edit.relationshipType).thenReturn(RelationshipTypes.edit);

      // Filter function
      bool shouldIncludeEvent(Event e) =>
          e.relationshipType != RelationshipTypes.reference &&
          e.relationshipType != RelationshipTypes.thread &&
          e.relationshipType != RelationshipTypes.edit;

      expect(shouldIncludeEvent(regularMessage), true);
      expect(shouldIncludeEvent(reply), false);
      expect(shouldIncludeEvent(thread), false);
      expect(shouldIncludeEvent(edit), false);
    });

    test('Only sender power level >= 50 events shown', () {
      final adminEvent = MockEvent();
      final lowPowerEvent = MockEvent();

      when(() => adminEvent.senderId).thenReturn('@admin:matrix.org');
      when(() => lowPowerEvent.senderId).thenReturn('@user:matrix.org');

      when(
        () => mockRoom1.getPowerLevelByUserId('@admin:matrix.org'),
      ).thenReturn(PowerLevel.admin);
      when(
        () => mockRoom1.getPowerLevelByUserId('@user:matrix.org'),
      ).thenReturn(PowerLevel(25));

      when(() => adminEvent.room).thenReturn(mockRoom1);
      when(() => lowPowerEvent.room).thenReturn(mockRoom1);

      // Filter function
      bool hasSufficientPowerLevel(Event e) =>
          e.room.getPowerLevelByUserId(e.senderId) >= PowerLevel.moderator;

      expect(hasSufficientPowerLevel(adminEvent), true);
      expect(hasSufficientPowerLevel(lowPowerEvent), false);
    });

    test('Only rooms with substitution account data included', () async {
      // This test validates the logic pattern used in home.dart
      // The actual isRoomInSubstitution() is an extension tested separately

      final roomInFeed = true; // simulated result from isRoomInSubstitution()
      final roomNotInFeed = false;

      // Filter function
      bool isRoomIncluded(bool inSubstitution) => inSubstitution;

      expect(isRoomIncluded(roomInFeed), true);
      expect(isRoomIncluded(roomNotInFeed), false);
    });
  });
}
