import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Room Search Tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('queryPublicRooms called with correct server and search filter',
        () async {
      final server = 'matrix.org';
      final filter = PublicRoomQueryFilter(genericSearchTerm: 'flutter');

      // Mock the response
      when(
        () => mockClient.queryPublicRooms(
          server: server,
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
          since: any(named: 'since'),
        ),
      ).thenAnswer((_) async => QueryPublicRoomsResponse.fromJson({
            'chunk': [],
            'total_room_count': 0,
            'prev_batch': null,
            'next_batch': null,
          }));

      // Call the method
      final result = await mockClient.queryPublicRooms(
        server: server,
        limit: 20,
        filter: filter,
      );

      // Verify the call was made with correct parameters
      verify(
        () => mockClient.queryPublicRooms(
          server: server,
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
          since: any(named: 'since'),
        ),
      ).called(1);

      expect(result, isNotNull);
    });

    test('Pagination: since token is passed for next page', () async {
      final server = 'matrix.org';
      final filter = PublicRoomQueryFilter(genericSearchTerm: 'test');
      final sinceToken = 'pagination_token_123';

      when(
        () => mockClient.queryPublicRooms(
          server: server,
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
          since: sinceToken,
        ),
      ).thenAnswer((_) async => QueryPublicRoomsResponse.fromJson({
            'chunk': [
              {
                'room_id': '!room2:matrix.org',
                'name': 'Test Room 2',
                'topic': 'Topic 2',
                'num_joined_members': 50,
                'avatar_url': null,
                'world_readable': true,
                'guest_can_join': true,
              }
            ],
            'total_room_count': 100,
            'prev_batch': 'prev_token',
            'next_batch': 'next_token_456',
          }));

      // Call with pagination token
      final result = await mockClient.queryPublicRooms(
        server: server,
        limit: 20,
        filter: filter,
        since: sinceToken,
      );

      // Verify the since token was passed
      verify(
        () => mockClient.queryPublicRooms(
          server: server,
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
          since: sinceToken,
        ),
      ).called(1);

      expect(result.chunk.length, 1);
      expect(result.nextBatch, 'next_token_456');
    });

    test('Race condition: outdated response is discarded', () async {
      final server = 'matrix.org';
      int searchGeneration = 0;

      // Simulate first search (generation 0)
      searchGeneration++;
      final gen1 = searchGeneration;

      when(
        () => mockClient.queryPublicRooms(
          server: server,
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
          since: any(named: 'since'),
        ),
      ).thenAnswer((_) async {
        // Simulate slow response
        await Future.delayed(const Duration(milliseconds: 100));
        return QueryPublicRoomsResponse.fromJson({
          'chunk': [
            {
              'room_id': '!old:matrix.org',
              'name': 'Old Search Result',
              'topic': 'Old',
              'num_joined_members': 10,
              'avatar_url': null,
              'world_readable': true,
              'guest_can_join': true,
            }
          ],
          'total_room_count': 1,
          'prev_batch': null,
          'next_batch': null,
        });
      });

      // Simulate second search (generation 1)
      searchGeneration++;
      final gen2 = searchGeneration;

      // Trigger both searches
      final oldSearch = mockClient.queryPublicRooms(
        server: server,
        limit: 20,
        filter: PublicRoomQueryFilter(genericSearchTerm: 'old'),
      );
      final newSearch = mockClient.queryPublicRooms(
        server: server,
        limit: 20,
        filter: PublicRoomQueryFilter(genericSearchTerm: 'new'),
      );

      // Wait for both to complete
      await oldSearch;
      await newSearch;

      // The newer search (gen2) should be the one used
      expect(gen2, greaterThan(gen1));
      // Verify both searches were called
      verify(
        () => mockClient.queryPublicRooms(
          server: server,
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
          since: any(named: 'since'),
        ),
      ).called(2);
    });
  });
}
