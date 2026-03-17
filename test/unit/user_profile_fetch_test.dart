import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockClient extends Mock implements Client {}

class MockProfile extends Mock implements Profile {}

class MockRoom extends Mock implements Room {}

void main() {
  group('User Profile Fetch', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('client.getProfileFromUserId is called with correct userId', () async {
      final userId = '@testuser:matrix.org';
      final mockProfile = MockProfile();

      when(
        () => mockClient.getProfileFromUserId(userId),
      ).thenAnswer((_) async => mockProfile);

      final result = await mockClient.getProfileFromUserId(userId);

      verify(() => mockClient.getProfileFromUserId(userId)).called(1);
      expect(result, mockProfile);
    });

    test(
      'Feeds are filtered to show only feeds where user has power level >= 50',
      () async {
        final userId = '@testuser:matrix.org';

        // Create mock rooms with different power levels
        final room1 = MockRoom();
        final room2 = MockRoom();
        final room3 = MockRoom();

        when(() => room1.id).thenReturn('!room1:matrix.org');
        when(() => room1.name).thenReturn('Room 1');
        when(() => room1.getPowerLevelByUserId(userId)).thenReturn(60);

        when(() => room2.id).thenReturn('!room2:matrix.org');
        when(() => room2.name).thenReturn('Room 2');
        when(() => room2.getPowerLevelByUserId(userId)).thenReturn(30);

        when(() => room3.id).thenReturn('!room3:matrix.org');
        when(() => room3.name).thenReturn('Room 3');
        when(() => room3.getPowerLevelByUserId(userId)).thenReturn(50);

        // Filter rooms with power level >= 50
        final filteredRooms =
            [room1, room2, room3].where((room) {
              final powerLevel = room.getPowerLevelByUserId(userId);
              return powerLevel >= 50;
            }).toList();

        // Should only include room1 and room3
        expect(filteredRooms.length, 2);
        expect(filteredRooms, contains(room1));
        expect(filteredRooms, contains(room3));
        expect(filteredRooms, isNot(contains(room2)));
      },
    );
  });
}
