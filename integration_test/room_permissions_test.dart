import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/settings/widgets/roomwidget.dart';
import 'package:substitution/settings/pages/room_permissions.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:go_router/go_router.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Room Permissions Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

      debugPrint('PERMISSIONS: Resetting state...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;

      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;

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

    tearDown(() async {
      debugPrint('PERMISSIONS: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets(
      'Admin can navigate to permissions and toggle blog mode',
      (tester) async {
        if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

        final $ = wrapTester(tester);
        app.main();

        if (!await patrol_helper.loginUser(
          $,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        )) {
          return;
        }

        // 1. Navigate directly to discovery/room list
        debugPrint('PERMISSIONS: Navigating to discovery...');
        final navContext = $.tester.element(find.byType(HomePage));
        navContext.push('/settings/feed');
        await $.tester.pumpAndSettle();

        // 2. Find a room where I am admin (test_general)
        debugPrint('PERMISSIONS: Looking for test_general...');
        await fastWait(
          $.tester,
          () => find.textContaining('test_general').evaluate().isNotEmpty,
        );

        // 3. Tap Permissions icon (Icons.settings) on the room tile
        debugPrint('PERMISSIONS: Tapping settings icon...');
        // Use descendant finder to get the settings icon relative to test_general
        final roomTile = find.ancestor(
          of: find.textContaining('test_general'),
          matching: find.byType(RoomWidget),
        );
        final settingsButton = find.descendant(
          of: roomTile,
          matching: find.byIcon(Icons.settings),
        );

        await $(settingsButton).tap();
        await $.tester.pumpAndSettle();

        // 4. Verify RoomPermissionsPage
        debugPrint('PERMISSIONS: Verifying RoomPermissionsPage...');
        await fastWait(
          $.tester,
          () => $(RoomPermissionsPage).exists,
          timeout: const Duration(seconds: 30),
        );
        expect($(RoomPermissionsPage).exists, true);

        // 5. Toggle Blog Mode Switch
        debugPrint('PERMISSIONS: Toggling switch...');
        final blogSwitch = $(Switch).first;
        final bool initialState = $.tester.widget<Switch>(blogSwitch).value;

        await blogSwitch.tap();
        await $.tester.pumpAndSettle();

        // 6. Verify state update or snackbar
        await fastWait($.tester, () {
          return find.textContaining('Switched to').evaluate().isNotEmpty;
        }, timeout: const Duration(seconds: 30));

        expect($.tester.widget<Switch>(blogSwitch).value, !initialState);
        debugPrint(
          '✓ PERMISSIONS: Successfully toggled and verified mode change',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
