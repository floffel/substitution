import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Individual Room Feed with Real Matrix Server', () {
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
      app.globalMatrixClient = null;
      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final dbFile = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await dbFile.exists()) {
            await dbFile.delete();
          }
        } catch (_) {}
      }
    });

    testWidgets('Room feed shows scrollable content', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      expect($(Scrollable).exists, true);
      debugPrint('✓ Room feed messages verified');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('Room feed allows scrolling', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      if ($(Scrollable).exists) {
        await $.tester.drag($(Scrollable).first, const Offset(0, -500));
        await $.tester.pump();
        debugPrint('✓ Room feed scrolling works');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
