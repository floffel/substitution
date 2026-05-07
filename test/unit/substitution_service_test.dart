import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/shared/services/substitution_service.dart';

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

void main() {
  group('SubstitutionService local refresh', () {
    late MockClient client;
    late SubstitutionService service;

    setUp(() {
      client = MockClient();

      when(() => client.onSyncStatus).thenThrow(Exception('unused in test'));
      when(() => client.rooms).thenReturn([]);

      service = SubstitutionService(client);
    });

    test(
      'keeps only joined rooms marked as substitution from local state',
      () async {
        final joinedSub = MockRoom();
        when(() => joinedSub.id).thenReturn('!joined-sub:example.org');
        when(() => joinedSub.membership).thenReturn(Membership.join);
        when(() => joinedSub.roomAccountData).thenReturn({
          'substitution': BasicEvent(
            type: 'substitution',
            content: {'joined': true},
          ),
        });

        final joinedNotSub = MockRoom();
        when(() => joinedNotSub.id).thenReturn('!joined-not-sub:example.org');
        when(() => joinedNotSub.membership).thenReturn(Membership.join);
        when(() => joinedNotSub.roomAccountData).thenReturn({
          'substitution': BasicEvent(
            type: 'substitution',
            content: {'joined': false},
          ),
        });

        final leftSub = MockRoom();
        when(() => leftSub.id).thenReturn('!left-sub:example.org');
        when(() => leftSub.membership).thenReturn(Membership.leave);
        when(() => leftSub.roomAccountData).thenReturn({
          'substitution': BasicEvent(
            type: 'substitution',
            content: {'joined': true},
          ),
        });

        when(() => client.rooms).thenReturn([joinedSub, joinedNotSub, leftSub]);

        await service.debugRefreshFromLocalRooms();

        expect(service.isSubstitutionRoom('!joined-sub:example.org'), isTrue);
        expect(
          service.isSubstitutionRoom('!joined-not-sub:example.org'),
          isFalse,
        );
        expect(service.isSubstitutionRoom('!left-sub:example.org'), isFalse);
        expect(service.roomCount, equals(1));
      },
    );

    test('removes stale room ids when local state no longer matches', () async {
      service.addRoomId('!stale:example.org');
      expect(service.isSubstitutionRoom('!stale:example.org'), isTrue);

      when(() => client.rooms).thenReturn([]);

      await service.debugRefreshFromLocalRooms();

      expect(service.isSubstitutionRoom('!stale:example.org'), isFalse);
      expect(service.roomCount, equals(0));
    });
  });
}
