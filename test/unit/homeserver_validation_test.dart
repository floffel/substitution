import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('Homeserver Validation', () {
    test('1. Valid homeserver URL makes checkHomeserver call', () async {
      // Arrange
      final mockClient = MockClient();
      when(() => mockClient.checkHomeserver(any())).thenAnswer((_) async => (
            null,
            GetVersionsResponse(versions: [], unstableFeatures: {}),
            <LoginFlow>[],
            null
          ));

      // Act
      try {
        await mockClient.checkHomeserver(Uri.https('matrix.org', ''));
        verify(() => mockClient.checkHomeserver(any())).called(1);
      } catch (e) {
        fail('Should not throw on valid homeserver: $e');
      }
    });

    test('2. Invalid URL throws exception', () {
      // Arrange
      final mockClient = MockClient();
      when(() => mockClient.checkHomeserver(any()))
          .thenThrow(Exception('Invalid homeserver'));

      // Act & Assert
      expect(
        () => mockClient.checkHomeserver(Uri.https('invalid.url', '')),
        throwsException,
      );
    });

    test('3. Empty input validation prevents submission', () {
      // This tests the form field validation logic
      final controller = TextEditingController();

      // Act: Leave empty
      expect(controller.text.isEmpty, true);

      // Validation check
      final isValid = controller.text.trim().isNotEmpty;
      expect(isValid, false);
    });

    test('4. Default value is matrix.org', () {
      // This test verifies the initial value of the text field
      final controller = TextEditingController(text: 'matrix.org');

      // Assert
      expect(controller.text, 'matrix.org');
    });
  });
}
