import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:substitution/auth/pages/host_page.dart';
import '../helpers/matrix_test_setup.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUpTestInfrastructure();

  const matrixServer = String.fromEnvironment(
    'MATRIX_SERVER',
    defaultValue: 'http://localhost:8008',
  );

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (condition()) {
        return;
      }
    }
    fail('Timed out waiting for condition');
  }

  group('HostPage Widget Tests', () {
    late Client client;
    late MatrixTestDatabase testDatabase;

    setUp(() async {
      final dbName = 'host_page_test_${DateTime.now().millisecondsSinceEpoch}';
      configureHttpOverrides();
      testDatabase = await createMatrixTestDatabase(dbName);

      client = Client(
        dbName,
        database: testDatabase.database,
        httpClient: http.Client(),
      );
    });

    tearDown(() async {
      try {
        if (client.isLogged()) {
          await client.logout();
        }
      } catch (_) {
        // Ignore cleanup errors
      }

      await testDatabase.dispose();
      restoreHttpOverrides();
    });

    testWidgets('1. Smoke test: renders text field and submit button',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        HostPage(onComplete: () {}),
        mockClient: client,
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('2. Entering URL and tapping submit calls checkHomeserver',
        (WidgetTester tester) async {
      final serverUri = Uri.parse(matrixServer);
      var onCompleteCalled = false;

      await pumpApp(
        tester,
        HostPage(onComplete: () {
          onCompleteCalled = true;
        }),
        mockClient: client,
      );

      await tester.enterText(find.byType(TextFormField), matrixServer);
      await runWithHttpOverrides(() async {
        await tester.runAsync(() async {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
          await pumpUntil(tester, () => onCompleteCalled);
        });
      });

      expect(client.homeserver, isNotNull);
      expect(client.homeserver?.host, serverUri.host);
      expect(client.homeserver?.port, serverUri.port);
    });

    testWidgets('3. Successful homeserver check calls onComplete',
        (WidgetTester tester) async {
      bool onCompleteCalled = false;

      await pumpApp(
        tester,
        HostPage(onComplete: () {
          onCompleteCalled = true;
        }),
        mockClient: client,
      );

      await tester.enterText(find.byType(TextFormField), matrixServer);
      await runWithHttpOverrides(() async {
        await tester.runAsync(() async {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
          await pumpUntil(tester, () => onCompleteCalled);
        });
      });

      // onComplete should have been called after successful check
      expect(onCompleteCalled, true);
    });
  });
}
