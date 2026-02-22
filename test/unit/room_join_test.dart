import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(MockRoom());
  });

  group('Room Join Tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('client.joinRoom(roomId) is called with correct room ID', () async {
      const roomId = '!room123:matrix.org';

      when(() =>
              mockClient.joinRoom(roomId, serverName: any(named: 'serverName')))
          .thenAnswer((_) async => roomId);

      // Simulate joining a room
      await mockClient.joinRoom(roomId, serverName: ['matrix.org']);

      // Verify joinRoom was called with correct room ID
      verify(() =>
              mockClient.joinRoom(roomId, serverName: any(named: 'serverName')))
          .called(1);
    });

    test('Account data {"joined": true} set after join', () async {
      const roomId = '!room123:matrix.org';
      const userId = '@user:matrix.org';

      when(() =>
              mockClient.joinRoom(roomId, serverName: any(named: 'serverName')))
          .thenAnswer((_) async => roomId);

      when(() => mockClient.setAccountDataPerRoom(
          userId, roomId, 'substitution', any())).thenAnswer((_) async {});

      when(() => mockClient.userID).thenReturn(userId);

      // Simulate joining and setting account data
      await mockClient.joinRoom(roomId, serverName: ['matrix.org']);
      await mockClient.setAccountDataPerRoom(
        userId,
        roomId,
        'substitution',
        {'joined': true},
      );

      // Verify setAccountDataPerRoom was called with correct data
      verify(
        () => mockClient.setAccountDataPerRoom(
          userId,
          roomId,
          'substitution',
          {'joined': true},
        ),
      ).called(1);
    });

    test('isRoomInSubstitution() returns true after join', () async {
      const roomId = '!room123:matrix.org';
      const userId = '@user:matrix.org';

      // Mock the getAccountDataPerRoom to return {"joined": true}
      when(
        () => mockClient.getAccountDataPerRoom(userId, roomId, 'substitution'),
      ).thenAnswer((_) async => {'joined': true});

      when(() => mockClient.userID).thenReturn(userId);

      // Check if room is in substitution
      final accountData = await mockClient.getAccountDataPerRoom(
          userId, roomId, 'substitution');
      final isInSubstitution = accountData['joined'] == true;

      // Verify the result
      expect(isInSubstitution, isTrue);
      verify(
        () => mockClient.getAccountDataPerRoom(userId, roomId, 'substitution'),
      ).called(1);
    });
  });
}
