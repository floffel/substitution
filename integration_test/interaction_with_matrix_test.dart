import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/post/widgets/post.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:patrol/patrol.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait, waitUntilNotVisible;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Engagement & Interaction with Real Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      debugPrint('ENGAGEMENT: Resetting state...');
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
      debugPrint('ENGAGEMENT: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    // Helper to wait for the feed to be truly ready with content
    Future<void> waitForFeedReady(PatrolIntegrationTester $) async {
      debugPrint('ENGAGEMENT: Waiting for logic state (rooms)...');
      await fastWait($.tester, () => app.globalSubstitutionService?.roomCount != null && app.globalSubstitutionService!.roomCount > 0);
      
      debugPrint('ENGAGEMENT: Waiting for UI state (PostWidget)...');
      await fastWait($.tester, () => $(PostWidget).exists, timeout: const Duration(seconds: 60));
      
      await $.tester.pumpAndSettle();
    }

    testWidgets('Can view feed messages and interact', (tester) async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      final $ = wrapTester(tester);
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      await waitForFeedReady($);
      
      expect($(PostWidget).exists, true, reason: 'Feed must contain messages');
      
      // Verify common interaction elements are present on posts
      expect($(Icons.favorite_rounded).exists, true, reason: 'Messages should have reaction button');
      expect($(Icons.reply).exists, true, reason: 'Messages should have reply button');
      
      debugPrint('✓ ENGAGEMENT: Feed content and buttons verified');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('Can view user profile by tapping avatar', (tester) async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      final $ = wrapTester(tester);
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      await waitForFeedReady($);

      // Find an avatar and tap it
      final avatar = $(CircleAvatar).first;
      await avatar.tap();
      
      // Wait for navigation/profile to appear
      // Based on app code, this usually goes to /profile/:userId
      await fastWait($.tester, () => find.textContaining('User Profile').evaluate().isNotEmpty || find.textContaining('@').evaluate().isNotEmpty);
      
      debugPrint('✓ ENGAGEMENT: Avatar interaction triggered profile view');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('Messages from test_general room are visible', (tester) async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      final $ = wrapTester(tester);
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      await waitForFeedReady($);

      // Verify that seeded messages from test_general are present
      // The seeder sends "Hello everyone! Welcome to this test room."
      await fastWait($.tester, () => find.textContaining('Hello everyone').evaluate().isNotEmpty, timeout: const Duration(seconds: 30));
      
      expect($(find.textContaining('Hello everyone')).exists, true);
      debugPrint('✓ ENGAGEMENT: Seeded messages verified in feed');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
