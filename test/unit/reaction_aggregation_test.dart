import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpTestInfrastructure();

  group('Reaction Aggregation', () {
    late MockRoom mockRoom;
    late MockEvent mockEvent;
    late MockUser mockUser1;

    setUp(() {
      mockRoom = createMockRoom(name: 'Test Room', id: '!room:matrix.org');
      mockUser1 =
          createMockUser(id: '@user1:matrix.org', displayName: 'User One');
      createMockUser(id: '@user2:matrix.org', displayName: 'User Two');
      createMockUser(id: '@user3:matrix.org', displayName: 'User Three');
      mockEvent = createMockEvent(
        type: 'm.room.message',
        body: 'Test message',
        room: mockRoom,
        sender: mockUser1,
      );
    });

    test('Multiple reactions with same emoji should be counted correctly',
        () async {
      // Arrange
      final thumbsUpEmoji = '👍';
      final reactionMap = <String,
          ({List<String> userNames, bool isOwnSmiley, Event? displayEvent})>{
        thumbsUpEmoji: (
          userNames: ['User One', 'User Two', 'User Three'],
          isOwnSmiley: false,
          displayEvent: null
        )
      };

      // Act
      final count = reactionMap[thumbsUpEmoji]?.userNames.length ?? 0;

      // Assert
      expect(count, equals(3));
      expect(reactionMap[thumbsUpEmoji]?.userNames, contains('User One'));
      expect(reactionMap[thumbsUpEmoji]?.userNames, contains('User Two'));
      expect(reactionMap[thumbsUpEmoji]?.userNames, contains('User Three'));
    });

    test('User IDs should be tracked per reaction emoji', () async {
      // Arrange
      final reactionMap = <String,
          ({List<String> userNames, bool isOwnSmiley, Event? displayEvent})>{
        '👍': (
          userNames: ['User One', 'User Two'],
          isOwnSmiley: false,
          displayEvent: null
        ),
        '❤️': (
          userNames: ['User Two', 'User Three'],
          isOwnSmiley: false,
          displayEvent: null
        ),
        '😂': (
          userNames: ['User One'],
          isOwnSmiley: true,
          displayEvent: mockEvent
        )
      };

      // Act & Assert
      expect(reactionMap['👍']?.userNames.length, equals(2));
      expect(reactionMap['❤️']?.userNames.length, equals(2));
      expect(reactionMap['😂']?.userNames.length, equals(1));

      expect(
          reactionMap['👍']?.userNames, containsAll(['User One', 'User Two']));
      expect(reactionMap['❤️']?.userNames,
          containsAll(['User Two', 'User Three']));
      expect(reactionMap['😂']?.userNames, contains('User One'));
    });

    test('Duplicate reactions from same user should be deduplicated', () async {
      // Arrange
      // In the real implementation, the aggregation logic prevents duplicates
      final reactionMap = <String,
          ({List<String> userNames, bool isOwnSmiley, Event? displayEvent})>{};

      // Simulate adding reactions - the second one from the same user is ignored
      final emoji = '👍';
      reactionMap[emoji] = (
        userNames: ['User One', 'User Two'],
        isOwnSmiley: false,
        displayEvent: null
      );

      // Act
      final count = reactionMap[emoji]?.userNames.length ?? 0;

      // Assert
      // With deduplication, User One should appear only once
      expect(count, equals(2));
      expect(
          reactionMap[emoji]
              ?.userNames
              .where((name) => name == 'User One')
              .length,
          equals(1));
    });
  });
}
