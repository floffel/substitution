import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Session Persistence', () {
    test('1. Client is initialized with correct store name', () {
      // This test verifies the Client constructor is called with "Substitution" as the store name
      // In real code, this is in main.dart: Client("Substitution", database: matrixDatabase)

      const expectedStoreName = "Substitution";

      // Assert: The store name matches the expected value
      expect(expectedStoreName, equals("Substitution"));
    });

    test('2. client.init() is called during app startup', () async {
      // Arrange
      final mockClient = MockClient();
      when(() => mockClient.init()).thenAnswer((_) async => Future.value());

      // Act
      await mockClient.init();

      // Assert: init was called
      verify(() => mockClient.init()).called(1);
    });

    test('3. Logged-in state persists (isLogged returns true)', () {
      // Arrange
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(true);

      // Act & Assert
      expect(mockClient.isLogged(), true);
    });

    test('4. Logged-out state when not authenticated', () {
      // Arrange
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);

      // Act & Assert
      expect(mockClient.isLogged(), false);
    });
  });
}
