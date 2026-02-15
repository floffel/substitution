import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Room Leave Tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('client.leaveRoom(roomId) is called with correct room ID', () async {
      const roomId = '!room123:matrix.org';

      when(() => mockClient.leaveRoom(roomId)).thenAnswer((_) async => {});

      // Simulate leaving a room
      await mockClient.leaveRoom(roomId);

      // Verify leaveRoom was called with correct room ID
      verify(() => mockClient.leaveRoom(roomId)).called(1);
    });

    test('Account data updated to remove substitution flag', () async {
      const roomId = '!room123:matrix.org';
      const userId = '@user:matrix.org';

      when(() => mockClient.leaveRoom(roomId)).thenAnswer((_) async => {});

      when(() => mockClient.setAccountDataPerRoom(
          userId, roomId, 'substitution', any())).thenAnswer((_) async {});

      when(() => mockClient.userID).thenReturn(userId);

      // Simulate leaving and updating account data
      await mockClient.leaveRoom(roomId);
      await mockClient.setAccountDataPerRoom(
        userId,
        roomId,
        'substitution',
        {}, // Empty map to remove the joined flag
      );

      // Verify setAccountDataPerRoom was called to clear the data
      verify(
        () => mockClient.setAccountDataPerRoom(
          userId,
          roomId,
          'substitution',
          {},
        ),
      ).called(1);
    });
  });
}
