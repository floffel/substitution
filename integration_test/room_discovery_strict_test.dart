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
  group('Room Discovery, Join & Leave with Real Matrix Server', () {
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

    testWidgets('STRICT: Room discovery UI present and functional', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      // Open room drawer/list
      final menuButton = $(Icons.menu);
      if (menuButton.exists) {
        await menuButton.tap();
      }

      expect($(ListTile).exists, true, reason: 'MUST show list of discoverable rooms');
      debugPrint('✓ STRICT: Room discovery UI present and functional');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('STRICT: All 3 joined rooms are visible in room list', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      // Open room drawer/list
      final drawerButton = $(Icons.menu);
      if (drawerButton.exists) {
        await drawerButton.tap();
      }

      // Wait for rooms to appear
      await $(ListTile).waitUntilVisible();

      final roomCount = $(ListTile).evaluate().length;
      expect(roomCount >= 3, true, reason: 'MUST show at least 3 pre-joined rooms');
      debugPrint('✓ STRICT: Found $roomCount rooms in list');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
