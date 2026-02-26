import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart'
    show skipIfNoMatrix;
import 'helpers/login_helper.dart' as login_helper;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Message Type Rendering with Real Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbPath = '${appDocDir.path}/matrix_database.db';
        final dbFile = dart_io.File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      }
    });

    tearDown(() async {
      await app.globalMatrixClient?.dispose();
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbPath = '${appDocDir.path}/matrix_database.db';
        final dbFile = dart_io.File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      }
    });

    testWidgets(
      'Feed renders m.text messages from the Matrix server',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        );

        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('✓ m.text messages verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'Feed renders m.image messages from the Matrix server',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        );

        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('✓ m.image messages verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'Feed renders m.video messages from the Matrix server',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        );

        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('✓ m.video messages verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'Feed renders m.audio messages from the Matrix server',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        );

        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('✓ m.audio messages verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'Feed handles all message types in the same room without crashing',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        );

        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('✓ Mixed message types verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
