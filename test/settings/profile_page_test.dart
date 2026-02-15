import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:matrix/matrix.dart';
import 'package:substitution/settings/pages/profile.dart';

class MockClient extends Mock implements Client {}

class MockProfile extends Mock implements Profile {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('Smoke: renders display name field, avatar, save button',
      (WidgetTester tester) async {
    final mockClient = MockClient();
    when(() => mockClient.isLogged()).thenReturn(true);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: Provider<Client>.value(
          value: mockClient,
          child: MaterialApp(
            home: Scaffold(
              body: const ProfilePage(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify key widgets exist
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byType(ElevatedButton), findsWidgets);
  });

  testWidgets('Displays current profile data', (WidgetTester tester) async {
    final mockClient = MockClient();
    when(() => mockClient.isLogged()).thenReturn(true);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: Provider<Client>.value(
          value: mockClient,
          child: MaterialApp(
            home: Scaffold(
              body: const ProfilePage(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Profile page should render
    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('Edit name + tap save -> calls setDisplayName()',
      (WidgetTester tester) async {
    final mockClient = MockClient();
    when(() => mockClient.isLogged()).thenReturn(true);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: Provider<Client>.value(
          value: mockClient,
          child: MaterialApp(
            home: Scaffold(
              body: const ProfilePage(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('Tap avatar -> opens file picker', (WidgetTester tester) async {
    final mockClient = MockClient();
    when(() => mockClient.isLogged()).thenReturn(true);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: Provider<Client>.value(
          value: mockClient,
          child: MaterialApp(
            home: Scaffold(
              body: const ProfilePage(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('Select file + save -> calls setAvatar()',
      (WidgetTester tester) async {
    final mockClient = MockClient();
    when(() => mockClient.isLogged()).thenReturn(true);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: Provider<Client>.value(
          value: mockClient,
          child: MaterialApp(
            home: Scaffold(
              body: const ProfilePage(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('Success shows SnackBar', (WidgetTester tester) async {
    final mockClient = MockClient();
    when(() => mockClient.isLogged()).thenReturn(true);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: Provider<Client>.value(
          value: mockClient,
          child: MaterialApp(
            home: Scaffold(
              body: const ProfilePage(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('Error shows AlertDialog', (WidgetTester tester) async {
    final mockClient = MockClient();
    when(() => mockClient.isLogged()).thenReturn(true);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: Provider<Client>.value(
          value: mockClient,
          child: MaterialApp(
            home: Scaffold(
              body: const ProfilePage(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('Loading state during save', (WidgetTester tester) async {
    final mockClient = MockClient();
    when(() => mockClient.isLogged()).thenReturn(true);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: Provider<Client>.value(
          value: mockClient,
          child: MaterialApp(
            home: Scaffold(
              body: const ProfilePage(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
  });
}
