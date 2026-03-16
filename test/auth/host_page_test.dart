import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/matrix_api_lite.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/auth/pages/host_page.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUpTestInfrastructure();

  group('HostPage Widget Tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    testWidgets('1. Smoke test: renders text field and submit button', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        HostPage(onComplete: () {}),
        mockClient: mockClient,
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('2. Entering URL and tapping submit calls checkHomeserver', (
      WidgetTester tester,
    ) async {
      // Widget treats bare hostnames as https:// URLs
      final expectedUri = Uri.https('matrix.org', '');

      // checkHomeserver succeeds — return a minimal valid record
      when(() => mockClient.checkHomeserver(any())).thenAnswer(
        (_) async => (
          null,
          GetVersionsResponse(versions: ['v1.1']),
          <LoginFlow>[],
          null,
        ),
      );

      var onCompleteCalled = false;

      await pumpApp(
        tester,
        HostPage(
          onComplete: () {
            onCompleteCalled = true;
          },
        ),
        mockClient: mockClient,
      );

      // Default controller text is 'matrix.org'; just tap submit directly.
      await tester.tap(find.byType(FilledButton));
      // Allow the async _setHost() to complete.
      await tester.pumpAndSettle();

      // checkHomeserver should have been called with the correct URI
      verify(() => mockClient.checkHomeserver(expectedUri)).called(1);
      expect(onCompleteCalled, isTrue);
    });

    testWidgets('3. Successful homeserver check calls onComplete', (
      WidgetTester tester,
    ) async {
      when(() => mockClient.checkHomeserver(any())).thenAnswer(
        (_) async => (
          null,
          GetVersionsResponse(versions: ['v1.1']),
          <LoginFlow>[],
          null,
        ),
      );

      bool onCompleteCalled = false;

      await pumpApp(
        tester,
        HostPage(
          onComplete: () {
            onCompleteCalled = true;
          },
        ),
        mockClient: mockClient,
      );

      await tester.enterText(find.byType(TextFormField), 'matrix.org');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(onCompleteCalled, isTrue);
    });
  });
}
