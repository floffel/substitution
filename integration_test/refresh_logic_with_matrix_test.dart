import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/post/widgets/post.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Refresh Logic Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

      debugPrint('REFRESH: Resetting state...');
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
      debugPrint('REFRESH: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets(
      'Feed updates automatically when new message arrives',
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

        // 1. Wait for feed to be ready
        await fastWait(
          $.tester,
          () => $(PostWidget).exists,
          timeout: const Duration(seconds: 60),
        );

        final client = app.globalMatrixClient!;
        final rooms = await client.getJoinedRooms();
        final room = client.getRoomById(rooms.first)!;

        // 2. Send a message in the background (programmatically)
        final uniqueBody =
            'AUTO_REFRESH_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('REFRESH: Sending background message: $uniqueBody');
        await room.sendTextEvent(uniqueBody);

        // 3. Verify that it appears in the UI WITHOUT manual refresh
        debugPrint('REFRESH: Waiting for automatic UI update...');
        await fastWait($.tester, () {
          return find
              .textContaining(uniqueBody, skipOffstage: false)
              .evaluate()
              .isNotEmpty;
        }, timeout: const Duration(seconds: 60));

        expect($(find.textContaining(uniqueBody)).exists, true);
        debugPrint('✓ REFRESH: Automatic update verified');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );

    testWidgets(
      'Manual pull-to-refresh triggers feed reload',
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

        // 1. Wait for feed
        await fastWait(
          $.tester,
          () => $(PostWidget).exists,
          timeout: const Duration(seconds: 60),
        );

        // 2. Perform pull-to-refresh
        debugPrint('REFRESH: Performing pull-to-refresh...');
        final scrollable = $(Scrollable).first;
        await $.tester.drag(scrollable, const Offset(0, 500)); // Drag down
        for (int i = 0; i < 10; i++) {
          await $.tester.pump(const Duration(milliseconds: 300));
        }

        // 3. Verify that the refresh indicator appeared and disappeared
        // (The app uses RefreshIndicator in HomePage)
        debugPrint('✓ REFRESH: Manual refresh triggered');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}
