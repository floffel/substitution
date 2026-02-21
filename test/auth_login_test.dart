import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/auth/auth_state.dart';
import 'package:substitution/auth/pages/login.dart';
import 'helpers/test_helpers.dart';

class MockClient extends Mock implements Client {}

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
}
