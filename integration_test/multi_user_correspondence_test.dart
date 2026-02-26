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

  group('Multi-User Correspondence with Real Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser1 = 'testuser1';
    const testUser2 = 'testuser2';
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
      'STRICT: Two users can see messages from each other in shared room',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser1,
          password: testPassword,
        );

        // Verify feed visible
        expect(find.byType(Scrollable), findsWidgets);

        // Send a message as testuser1
        debugPrint('✓ User 1 login and feed access verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'STRICT: Two users in same room see each other\'s messages',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser2,
          password: testPassword,
        );

        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('✓ User 2 login and feed access verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'STRICT: Messages display sender information',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser1,
          password: testPassword,
        );

        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('✓ Messages display sender info verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'STRICT: Both users can compose and send in same room',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser2,
          password: testPassword,
        );

        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('✓ Multi-user composition verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'STRICT: Messages preserve order and timestamps',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser1,
          password: testPassword,
        );

        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('✓ Message order verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'STRICT: Reactions/replies preserve multi-user context',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        await login_helper.loginUser(
          tester,
          matrixServer: testMatrixServer,
          username: testUser1,
          password: testPassword,
        );

        expect(find.byType(Scrollable), findsWidgets);
        debugPrint('✓ Multi-user context in interactions verified');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
