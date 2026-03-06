import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:substitution/post/widgets/post.dart';
import 'package:substitution/profile/pages/user_profile.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Profile View Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

      debugPrint('PROFILE_VIEW: Resetting state...');
      try {
        app.globalMatrixClient?.abortSync();
        await app.globalMatrixClient?.dispose();
      } catch (e) {
        debugPrint('TEST: Matrix client cleanup warning: $e');
      }
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
      debugPrint('PROFILE_VIEW: Tearing down...');
      try {
        app.globalMatrixClient?.abortSync();
        await app.globalMatrixClient?.dispose();
      } catch (e) {
        debugPrint('TEST: Matrix client cleanup warning: $e');
      }
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets(
      'Can navigate from feed to profile and back to room feed',
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

        // 1. Wait for feed content
        debugPrint('PROFILE_VIEW: Waiting for feed content...');
        await fastWait(
          $.tester,
          () => $(PostWidget).exists,
          timeout: const Duration(seconds: 60),
        );

        // 2. Tap on avatar
        debugPrint('PROFILE_VIEW: Tapping avatar...');
        final avatar = $(CircleAvatar).first;
        await avatar.tap();
        await $.tester.pumpAndSettle();

        // 3. Verify UserProfilePage
        debugPrint('PROFILE_VIEW: Verifying UserProfilePage...');
        await fastWait(
          $.tester,
          () => $(UserProfilePage).exists,
          timeout: const Duration(seconds: 30),
        );
        expect($(UserProfilePage).exists, true);

        // Verify user ID is present (contains @testuser1)
        expect($(find.textContaining('@$testUser')).exists, true);

        // 4. Tap on a room in the profile (if any)
        // The profile page lists rooms where the user has power level >= 50
        debugPrint('PROFILE_VIEW: Looking for rooms in profile...');
        final roomTile = $(ListTile);
        if (roomTile.exists) {
          debugPrint('PROFILE_VIEW: Tapping room in profile...');
          await roomTile.first.tap();
          await $.tester.pumpAndSettle();

          // 5. Verify navigation back to a feed (HomePage but with roomId)
          debugPrint('PROFILE_VIEW: Verifying navigation to room feed...');
          await fastWait(
            $.tester,
            () => $(HomePage).exists,
            timeout: const Duration(seconds: 30),
          );
          expect($(HomePage).exists, true);
        }

        debugPrint('✓ PROFILE_VIEW: Navigation flow verified');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}
