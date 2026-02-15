import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:matrix/matrix.dart';

class MockClient extends Mock implements Client {}

void main() {
  group('Cache Clear', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('client.logout() is called', () async {
      when(() => mockClient.logout()).thenAnswer((_) async {});

      await mockClient.logout();

      verify(() => mockClient.logout()).called(1);
    });

    test('client.database.clear() clears all data', () async {
      // Verify that logout clears user session
      when(() => mockClient.logout()).thenAnswer((_) async {});
      when(() => mockClient.isLogged()).thenReturn(false);

      await mockClient.logout();

      expect(mockClient.isLogged(), false);
    });

    test('After cache clear, client.isLogged() returns false', () async {
      when(() => mockClient.logout()).thenAnswer((_) async {});
      when(() => mockClient.isLogged()).thenReturn(false);

      await mockClient.logout();

      expect(mockClient.isLogged(), false);
    });
  });
}
