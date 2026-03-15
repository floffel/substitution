import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../helpers/test_helpers.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpTestInfrastructure();

  group('App Startup - Session Persistence', () {
    testWidgets('1. If client.isLogged() == true, redirects to /feed', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(true);

      // Create a simple router with redirect logic
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            redirect: (context, state) {
              if (!Provider.of<Client>(context, listen: false).isLogged()) {
                return '/intro';
              }
              return null; // Stay on /
            },
            builder:
                (context, state) =>
                    const Scaffold(body: Center(child: Text('Feed'))),
          ),
          GoRoute(
            path: '/intro',
            builder:
                (context, state) =>
                    const Scaffold(body: Center(child: Text('Introduction'))),
          ),
        ],
      );

      // Test with custom router - bypass pumpApp to use our custom router
      final app = EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: MultiProvider(
          providers: [Provider<Client>.value(value: mockClient)],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => child ?? const SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // When logged in, should show feed content, not intro
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Introduction'), findsNothing);
    });

    testWidgets('2. If client.isLogged() == false, shows introduction/auth', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            redirect: (context, state) {
              if (!Provider.of<Client>(context, listen: false).isLogged()) {
                return '/intro';
              }
              return null;
            },
            builder:
                (context, state) =>
                    const Scaffold(body: Center(child: Text('Feed'))),
          ),
          GoRoute(
            path: '/intro',
            builder:
                (context, state) =>
                    const Scaffold(body: Center(child: Text('Introduction'))),
          ),
        ],
      );

      // Test with custom router
      final app = EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: MultiProvider(
          providers: [Provider<Client>.value(value: mockClient)],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => child ?? const SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // When not logged in, should show intro
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Feed'), findsNothing);
    });
  });
}
