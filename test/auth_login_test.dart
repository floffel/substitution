import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/auth/auth_state.dart';
import 'package:substitution/auth/pages/login.dart';
import 'helpers/test_helpers.dart';

class MockClient extends Mock implements Client {}

// ---------------------------------------------------------------------------
// Real-world login flow fixtures (captured from live servers, no network I/O
// in tests). These reflect what GET /_matrix/client/v3/login actually returns.
// ---------------------------------------------------------------------------

/// matrix.org — password + SSO, but SSO has no identity_providers array.
/// The server uses delegated OIDC / OAuth-aware flow without listing providers.
List<LoginFlow> matrixOrgFlows() => [
      LoginFlow(type: AuthenticationTypes.password),
      LoginFlow.fromJson({
        'type': AuthenticationTypes.sso,
        'oauth_aware_preferred': true,
        'org.matrix.msc3824.delegated_oidc_compatibility': true,
      }),
      LoginFlow(type: 'm.login.token'),
    ];

/// tchncs.de — password + SSO with 5 named identity providers.
/// A good real-world example of a server with multiple SSO options.
List<LoginFlow> tchncsDe_Flows() => [
      LoginFlow.fromJson({
        'type': AuthenticationTypes.sso,
        'identity_providers': [
          {'id': 'oidc-github', 'name': 'Github', 'brand': 'github'},
          {
            'id': 'oidc-codeberg',
            'name': 'Codeberg',
            'icon': 'mxc://tchncs.de/be844d7d5d5b715ccf8166a2d3bcdb59033565b8'
          },
          {'id': 'oidc-gitlab', 'name': 'GitLab', 'brand': 'gitlab'},
          {'id': 'oidc-google', 'name': 'Google', 'brand': 'google'},
          {
            'id': 'oidc-zitadel',
            'name': 'Zitadel',
            'icon': 'mxc://tchncs.de/6e1b75462f840851e39600964f48433cd4b04692'
          },
        ],
      }),
      LoginFlow(type: 'm.login.token'),
      LoginFlow(type: AuthenticationTypes.password),
    ];

void main() {
  setUpTestInfrastructure();

  testWidgets('LoginPage smoke test — password-only server shows form',
      (WidgetTester tester) async {
    final mockClient = MockClient();
    when(() => mockClient.isLogged()).thenReturn(false);
    when(() => mockClient.homeserver)
        .thenReturn(Uri.parse('https://matrix.org'));

    final authState = AuthState()
      ..setLoginFlows([
        LoginFlow(type: AuthenticationTypes.password),
      ]);

    await pumpApp(
      tester,
      LoginPage(onComplete: () {}),
      mockClient: mockClient,
      authState: authState,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // Username + Password
    expect(find.byType(ElevatedButton), findsOneWidget); // Login button
    expect(find.byType(OutlinedButton), findsNothing); // No SSO buttons
  });

  group('Login Page - Additional Behavior Tests', () {
    testWidgets('2. Enter credentials + tap login -> calls client.login()',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);
      when(() => mockClient.homeserver)
          .thenReturn(Uri.parse('https://matrix.org'));
      when(() => mockClient.login(
            any(),
            identifier: any(named: 'identifier'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => Future.value());

      final authState = AuthState()
        ..setLoginFlows([
          LoginFlow(type: AuthenticationTypes.password),
        ]);

      await pumpApp(
        tester,
        LoginPage(onComplete: () {}),
        mockClient: mockClient,
        authState: authState,
      );

      // Enter username and password
      await tester.enterText(find.byType(TextFormField).at(0), 'testuser');
      await tester.enterText(find.byType(TextFormField).at(1), 'testpass');

      // Tap login button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(); // Single pump to allow method to execute

      // Verify login was called
      verify(() => mockClient.login(
            any(),
            identifier: any(named: 'identifier'),
            password: any(named: 'password'),
          )).called(greaterThan(0));
    });

    testWidgets('4. Failed login shows error dialog',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);
      when(() => mockClient.homeserver)
          .thenReturn(Uri.parse('https://matrix.org'));
      when(() => mockClient.login(
            any(),
            identifier: any(named: 'identifier'),
            password: any(named: 'password'),
          )).thenThrow(Exception('Invalid credentials'));

      final authState = AuthState()
        ..setLoginFlows([
          LoginFlow(type: AuthenticationTypes.password),
        ]);

      await pumpApp(
        tester,
        LoginPage(onComplete: () {}),
        mockClient: mockClient,
        authState: authState,
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'user');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Error dialog should appear
      expect(find.byType(AlertDialog), findsWidgets);
    });

    testWidgets('7a. SSO-only server: shows SSO buttons, hides password fields',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);
      when(() => mockClient.homeserver)
          .thenReturn(Uri.parse('https://matrix.org'));

      // Server supports only SSO with two providers
      final authState = AuthState()
        ..setLoginFlows([
          LoginFlow.fromJson({
            'type': AuthenticationTypes.sso,
            'identity_providers': [
              {'id': 'google', 'name': 'Google'},
              {'id': 'github', 'name': 'GitHub'},
            ],
          }),
        ]);

      await pumpApp(
        tester,
        LoginPage(onComplete: () {}),
        mockClient: mockClient,
        authState: authState,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Password fields and login button should be hidden
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);

      // One SSO button per provider
      expect(find.byKey(const Key('ssoButton_google')), findsOneWidget);
      expect(find.byKey(const Key('ssoButton_github')), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(2));
    });

    testWidgets('7b. Server supporting both password and SSO shows all buttons',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);
      when(() => mockClient.homeserver)
          .thenReturn(Uri.parse('https://matrix.org'));

      final authState = AuthState()
        ..setLoginFlows([
          LoginFlow(type: AuthenticationTypes.password),
          LoginFlow.fromJson({
            'type': AuthenticationTypes.sso,
            'identity_providers': [
              {'id': 'google', 'name': 'Google'},
            ],
          }),
        ]);

      await pumpApp(
        tester,
        LoginPage(onComplete: () {}),
        mockClient: mockClient,
        authState: authState,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Password fields visible
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);

      // SSO button also visible
      expect(find.byKey(const Key('ssoButton_google')), findsOneWidget);
    });

    testWidgets(
        '7c. Before checkHomeserver completes (null flows) shows password form by default',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);
      when(() => mockClient.homeserver)
          .thenReturn(Uri.parse('https://matrix.org'));

      // AuthState with no flows set yet
      final authState = AuthState();

      await pumpApp(
        tester,
        LoginPage(onComplete: () {}),
        mockClient: mockClient,
        authState: authState,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show password form by default (safe fallback)
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
      // No SSO buttons yet
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Real-world server fixture tests
  //
  // These use captured JSON responses from real servers (no network calls)
  // to verify that LoginPage renders the correct buttons for actual homeserver
  // configurations.
  // -------------------------------------------------------------------------
  group('Real-world server login flow fixtures', () {
    testWidgets(
        'matrix.org — shows password form + one generic SSO button (no named providers)',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);
      when(() => mockClient.homeserver)
          .thenReturn(Uri.parse('https://matrix.org'));

      // matrix.org reports m.login.sso without identity_providers — our
      // AuthState fallback produces a single unnamed "SSO" provider.
      final authState = AuthState()..setLoginFlows(matrixOrgFlows());

      await pumpApp(
        tester,
        LoginPage(onComplete: () {}),
        mockClient: mockClient,
        authState: authState,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Password form is present
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Exactly one SSO button (the unnamed fallback)
      expect(find.byType(OutlinedButton), findsOneWidget);
      // Its key uses the empty id from the fallback provider
      expect(find.byKey(const Key('ssoButton_')), findsOneWidget);
    });

    testWidgets(
        'tchncs.de — shows password form + 5 named SSO buttons (GitHub, Codeberg, GitLab, Google, Zitadel)',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);
      when(() => mockClient.homeserver)
          .thenReturn(Uri.parse('https://tchncs.de'));

      final authState = AuthState()..setLoginFlows(tchncsDe_Flows());

      await pumpApp(
        tester,
        LoginPage(onComplete: () {}),
        mockClient: mockClient,
        authState: authState,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Password form is present (tchncs.de supports both)
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Exactly 5 SSO buttons — one per identity provider
      expect(find.byType(OutlinedButton), findsNWidgets(5));

      // Each provider has its own button with the correct key
      expect(find.byKey(const Key('ssoButton_oidc-github')), findsOneWidget);
      expect(find.byKey(const Key('ssoButton_oidc-codeberg')), findsOneWidget);
      expect(find.byKey(const Key('ssoButton_oidc-gitlab')), findsOneWidget);
      expect(find.byKey(const Key('ssoButton_oidc-google')), findsOneWidget);
      expect(find.byKey(const Key('ssoButton_oidc-zitadel')), findsOneWidget);
    });
  });
}
