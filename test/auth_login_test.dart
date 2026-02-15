import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/auth/pages/login.dart';
import 'helpers/test_helpers.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpTestInfrastructure();

  testWidgets('LoginPage smoke test', (WidgetTester tester) async {
    final mockClient = MockClient();
    when(() => mockClient.isLogged()).thenReturn(false);
    when(() => mockClient.homeserver)
        .thenReturn(Uri.parse('https://matrix.org'));

    await pumpApp(
      tester,
      LoginPage(onComplete: () {}),
      mockClient: mockClient,
    );

    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(
        find.byType(TextFormField), findsNWidgets(2)); // Username and Password
    expect(find.byType(ElevatedButton), findsOneWidget); // Login button
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

      await pumpApp(
        tester,
        LoginPage(onComplete: () {}),
        mockClient: mockClient,
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

      await pumpApp(
        tester,
        LoginPage(onComplete: () {}),
        mockClient: mockClient,
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'user');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Error dialog should appear
      expect(find.byType(AlertDialog), findsWidgets);
    });

    testWidgets('7. SSO button visible when flows include SSO',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);
      when(() => mockClient.homeserver)
          .thenReturn(Uri.parse('https://matrix.org'));

      await pumpApp(
        tester,
        LoginPage(onComplete: () {}),
        mockClient: mockClient,
      );

      await tester.pumpAndSettle();

      // SSO button should be visible
      expect(find.byType(OutlinedButton), findsWidgets);
      expect(find.text('Sign in with Google (SSO)'), findsOneWidget);
    });
  });
}
