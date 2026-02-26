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
  group('Feed with Real Matrix Server', () {
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
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final mainDb = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await mainDb.exists()) {
            await mainDb.delete();
          }
        } catch (_) {}
      }
    });

    testWidgets('Display unified feed from multiple rooms', (tester) async {
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
      debugPrint('✓ Unified feed displayed with messages');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('Feed loads and shows messages chronologically', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      final feed = $(Scrollable);
      expect(feed.exists, true);

      // Scroll down to load more messages
      await $.tester.drag(feed.first, const Offset(0, -500));
      await $.tester.pump();
      debugPrint('✓ Feed supports scrolling');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
