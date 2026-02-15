import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:substitution/auth/pages/host.dart';
import '../helpers/test_helpers.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpTestInfrastructure();

  group('HostPage Widget Tests', () {
    testWidgets('1. Smoke test: renders text field and submit button',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);

      await pumpApp(
        tester,
        HostPage(onComplete: () {}),
        mockClient: mockClient,
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('2. Entering URL and tapping submit calls checkHomeserver',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);
      when(() => mockClient.checkHomeserver(any())).thenAnswer((_) async => (
            null,
            GetVersionsResponse(versions: [], unstableFeatures: {}),
            <LoginFlow>[],
            null
          ));

      await pumpApp(
        tester,
        HostPage(onComplete: () {}),
        mockClient: mockClient,
      );

      await tester.enterText(find.byType(TextFormField), 'example.com');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      verify(() => mockClient.checkHomeserver(any())).called(greaterThan(0));
    });

    testWidgets('3. Successful homeserver check calls onComplete',
        (WidgetTester tester) async {
      final mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(false);
      when(() => mockClient.checkHomeserver(any())).thenAnswer((_) async => (
            null,
            GetVersionsResponse(versions: [], unstableFeatures: {}),
            <LoginFlow>[],
            null
          ));

      bool onCompleteCalled = false;

      await pumpApp(
        tester,
        HostPage(onComplete: () {
          onCompleteCalled = true;
        }),
        mockClient: mockClient,
      );

      // Use the default value and submit
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // onComplete should have been called after successful check
      expect(onCompleteCalled, true);
    });
  });
}
