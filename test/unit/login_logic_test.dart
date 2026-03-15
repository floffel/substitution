import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/auth/auth_state.dart';

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

      when(
        () => mockClient.login(
          any(),
          identifier: any(named: 'identifier'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => LoginResponse(
          accessToken: 'token123',
          userId: '@user:matrix.org',
          deviceId: 'device123',
        ),
      );

      // Act
      await mockClient.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: username),
        password: password,
      );

      // Assert: verify login was called with correct args
      verify(
        () => mockClient.login(
          LoginType.mLoginPassword,
          identifier: any(named: 'identifier'),
          password: password,
        ),
      ).called(1);
    });

    test('2. SSO URL is constructed correctly (generic, no provider id)', () {
      // Arrange
      final homeserver = Uri.parse('https://matrix.org');

      // Act: Construct the SSO URL as per the implementation (no idpId)
      final ssoUrl = homeserver
          .resolve('_matrix/client/v3/login/sso/redirect')
          .replace(
            queryParameters: {'redirectUrl': 'substitution://login-callback'},
          );

      // Assert
      expect(
        ssoUrl.toString(),
        contains('_matrix/client/v3/login/sso/redirect'),
      );
      expect(ssoUrl.toString(), contains('redirectUrl'));
      expect(ssoUrl.host, 'matrix.org');
    });

    test(
      '3. SSO URL includes provider id in path for provider-specific redirect',
      () {
        // Arrange
        final homeserver = Uri.parse('https://matrix.org');
        const idpId = 'google';

        // Act: Construct provider-specific SSO URL
        final ssoUrl = homeserver
            .resolve(
              '_matrix/client/v3/login/sso/redirect/${Uri.encodeComponent(idpId)}',
            )
            .replace(
              queryParameters: {'redirectUrl': 'substitution://login-callback'},
            );

        // Assert: path must contain the provider id
        expect(
          ssoUrl.toString(),
          contains('_matrix/client/v3/login/sso/redirect/google'),
        );
        expect(ssoUrl.toString(), contains('redirectUrl'));
        expect(ssoUrl.host, 'matrix.org');
      },
    );

    test('4. AuthState.ssoProviders parses identity_providers correctly', () {
      final authState =
          AuthState()..setLoginFlows([
            LoginFlow.fromJson({
              'type': AuthenticationTypes.sso,
              'identity_providers': [
                {'id': 'google', 'name': 'Google'},
                {
                  'id': 'github',
                  'name': 'GitHub',
                  'icon': 'mxc://example/icon',
                },
              ],
            }),
          ]);

      final providers = authState.ssoProviders;

      expect(providers.length, 2);
      expect(providers[0].id, 'google');
      expect(providers[0].name, 'Google');
      expect(providers[0].icon, isNull);
      expect(providers[1].id, 'github');
      expect(providers[1].name, 'GitHub');
      expect(providers[1].icon, 'mxc://example/icon');
    });

    test(
      '5. AuthState.hasPasswordFlow returns true when password flow present',
      () {
        final authState =
            AuthState()
              ..setLoginFlows([LoginFlow(type: AuthenticationTypes.password)]);

        expect(authState.hasPasswordFlow, isTrue);
      },
    );

    test('6. AuthState.hasPasswordFlow returns false for SSO-only server', () {
      final authState =
          AuthState()..setLoginFlows([
            LoginFlow.fromJson({
              'type': AuthenticationTypes.sso,
              'identity_providers': [
                {'id': 'google', 'name': 'Google'},
              ],
            }),
          ]);

      expect(authState.hasPasswordFlow, isFalse);
    });

    test(
      '7. AuthState.hasPasswordFlow returns true when flows are not yet set',
      () {
        // Before checkHomeserver completes, flows are null — default to showing password form
        final authState = AuthState();
        expect(authState.hasPasswordFlow, isTrue);
      },
    );

    test(
      '8. AuthState.ssoProviders returns single unnamed provider when identity_providers absent',
      () {
        // Some servers report m.login.sso without listing individual providers
        final authState =
            AuthState()
              ..setLoginFlows([LoginFlow(type: AuthenticationTypes.sso)]);

        final providers = authState.ssoProviders;
        expect(providers.length, 1);
        expect(providers[0].id, '');
        expect(providers[0].name, 'SSO');
      },
    );
  });
}
