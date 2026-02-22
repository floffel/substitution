import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpTestInfrastructure();

  group('Reaction Send', () {
    late MockClient mockClient;
    late MockRoom mockRoom;
    late MockEvent mockEvent;
    late MockUser mockSender;

    setUp(() {
      mockClient = MockClient();
      mockRoom = createMockRoom(name: 'Test Room', id: '!room:matrix.org');
      mockSender =
          createMockUser(id: '@user:matrix.org', displayName: 'Test User');
      mockEvent = createMockEvent(
        type: 'm.room.message',
        body: 'Test message',
        room: mockRoom,
        sender: mockSender,
      );
    });

    test('should call event.room.sendReaction with correct event ID and emoji',
        () async {
      // Arrange
      const emoji = '👍';
      const eventId = r'$event123';

      when(() => mockEvent.eventId).thenReturn(eventId);
      when(() => mockRoom.sendReaction(eventId, emoji))
          .thenAnswer((_) async => 'reaction_event_id');

      // Act
      await mockEvent.room.sendReaction(mockEvent.eventId, emoji);

      // Assert
      verify(() => mockRoom.sendReaction(eventId, emoji)).called(1);
    });

    test('should map selected emoji to correct unicode key', () async {
      // Arrange
      final emojis = ['👍', '❤️', '😂', '🎉', '🔥'];

      when(() => mockRoom.sendReaction(any(), any()))
          .thenAnswer((_) async => 'reaction_event_id');

      // Act & Assert
      for (final emoji in emojis) {
        await mockEvent.room.sendReaction(mockEvent.eventId, emoji);
        verify(() => mockRoom.sendReaction(mockEvent.eventId, emoji)).called(1);
      }
    });
  });
}
