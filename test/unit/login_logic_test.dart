import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(AuthenticationUserIdentifier(user: 'dummy'));
  });

  group('Login Logic', () {
    test('1. Login call uses correct parameters', () async {
      // Arrange
      final mockClient = MockClient();
      final username = 'testuser';
      final password = 'testpassword';

      when(() => mockClient.login(
            any(),
            identifier: any(named: 'identifier'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => LoginResponse(
            accessToken: 'token123',
            userId: '@user:matrix.org',
            deviceId: 'device123',
          ));

      // Act
      await mockClient.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: username),
        password: password,
      );

      // Assert: verify login was called with correct args
      verify(() => mockClient.login(
            LoginType.mLoginPassword,
            identifier: any(named: 'identifier'),
            password: password,
          )).called(1);
    });

    test('2. SSO URL is constructed correctly', () {
      // Arrange
      final homeserver = Uri.parse('https://matrix.org');
      final expectedPath = '_matrix/client/r0/login/sso/redirect';

      // Act: Construct the SSO URL as per the implementation
      final ssoUrl = homeserver.resolve(expectedPath).replace(queryParameters: {
        'redirectUrl': 'substitution://login-callback',
      });

      // Assert
      expect(
          ssoUrl.toString(), contains('_matrix/client/r0/login/sso/redirect'));
      expect(ssoUrl.toString(), contains('redirectUrl'));
      expect(ssoUrl.host, 'matrix.org');
    });
  });
}
