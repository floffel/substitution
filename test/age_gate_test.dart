import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:substitution/shared/pages/age_gate.dart';

Widget _buildApp(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/intro',
        builder: (context, state) => const Scaffold(body: Text('intro page')),
      ),
    ],
  );

  return EasyLocalization(
    supportedLocales: const [Locale('en', 'US')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en', 'US'),
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AgeGatePage.confirmed = false;
  });

  group('AgeGatePage Widget Tests', () {
    testWidgets('Smoke: AgeGatePage renders without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildApp(const AgeGatePage()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AgeGatePage), findsOneWidget);
    });

    testWidgets('Confirm button is present with correct key',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildApp(const AgeGatePage()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('ageGateConfirmButton')), findsOneWidget);
    });

    testWidgets('Confirm button is a FilledButton',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildApp(const AgeGatePage()));
      await tester.pump(const Duration(milliseconds: 100));

      final confirmButton = find.byKey(const Key('ageGateConfirmButton'));
      expect(tester.widget(confirmButton), isA<FilledButton>());
    });

    testWidgets('Privacy link TextButton is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildApp(const AgeGatePage()));
      await tester.pump(const Duration(milliseconds: 100));

      // There should be at least one TextButton (the privacy link)
      expect(find.byType(TextButton), findsAtLeastNWidgets(1));
    });

    testWidgets('AgeGatePage.initConfirmed loads false when not set',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await AgeGatePage.initConfirmed();
      expect(AgeGatePage.confirmed, isFalse);
    });

    testWidgets('AgeGatePage.initConfirmed loads true when previously set',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      await AgeGatePage.initConfirmed();
      expect(AgeGatePage.confirmed, isTrue);
    });

    testWidgets(
        'Tapping confirm button persists acceptance to SharedPreferences',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildApp(const AgeGatePage()));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('ageGateConfirmButton')));
      await tester.pump(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('age_confirmed'), isTrue);
      expect(AgeGatePage.confirmed, isTrue);
    });

    testWidgets('Page displays bullet points (at least 4)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildApp(const AgeGatePage()));
      await tester.pump(const Duration(milliseconds: 100));

      // Check that the bullet marker "•" appears at least 4 times
      expect(find.text('• '), findsAtLeastNWidgets(4));
    });

    testWidgets('Page is scrollable (SingleChildScrollView)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildApp(const AgeGatePage()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
