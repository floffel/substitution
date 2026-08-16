import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/shared/utils/servers.dart';

class MockClient extends Mock implements Client {}

void main() {
  group('getSubstitutionServers', () {
    late MockClient client;

    setUp(() {
      client = MockClient();
      when(() => client.userID).thenReturn('@alice:matrix.org');
    });

    test('returns the account-data map on success', () async {
      final fake = <String, Object?>{'matrix.org': null};
      when(
        () => client.getAccountData(any(), any()),
      ).thenAnswer((_) async => fake);

      final result = await getSubstitutionServers(client);
      expect(result, fake);
    });

    test(
      'returns an empty map when the call throws (first-time user)',
      () async {
        // First-time users have no account data yet, so getAccountData
        // throws. The helper must not crash the UI.
        when(
          () => client.getAccountData(any(), any()),
        ).thenThrow(Exception('M_NOT_FOUND'));

        final result = await getSubstitutionServers(client);
        expect(result, isEmpty);
      },
    );

    test('returns an empty map when account data is malformed', () async {
      when(
        () => client.getAccountData(any(), any()),
      ).thenThrow(FormatException('bad json'));

      final result = await getSubstitutionServers(client);
      expect(result, isEmpty);
    });

    test('queries under the "substitution.servers" account-data key', () async {
      when(
        () => client.getAccountData(any(), any()),
      ).thenAnswer((_) async => <String, Object?>{});

      await getSubstitutionServers(client);

      final captured =
          verify(
            () => client.getAccountData(captureAny(), captureAny()),
          ).captured;
      expect(captured, hasLength(2));
      expect(captured[0], '@alice:matrix.org');
      expect(captured[1], substitutionServersAccountDataKey);
    });
  });

  group('setSubstitutionServers', () {
    late MockClient client;

    setUp(() {
      client = MockClient();
      when(() => client.userID).thenReturn('@alice:matrix.org');
    });

    test('writes the map under the substitution.servers key', () async {
      when(
        () => client.setAccountData(any(), any(), any()),
      ).thenAnswer((_) async => {});

      final servers = <String, Object?>{
        'matrix.org': null,
        'example.com': null,
      };
      await setSubstitutionServers(client, servers);

      final captured =
          verify(
            () =>
                client.setAccountData(captureAny(), captureAny(), captureAny()),
          ).captured;
      expect(captured, hasLength(3));
      expect(captured[0], '@alice:matrix.org');
      expect(captured[1], substitutionServersAccountDataKey);
      expect(captured[2], servers);
    });

    test('propagates errors from the underlying client', () async {
      when(
        () => client.setAccountData(any(), any(), any()),
      ).thenThrow(Exception('network down'));

      expect(
        () => setSubstitutionServers(client, <String, Object?>{}),
        throwsException,
      );
    });
  });
}
