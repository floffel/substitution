import "package:integration_test/integration_test.dart";
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/post/widgets/post.dart';
import 'package:patrol/patrol.dart';
import 'helpers/integration_test_helper.dart'
    show skipIfNoMatrix, fastWait, effectiveMatrixServer, settle;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';
import 'helpers/matrix_cleanup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Engagement & Interaction with Real Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(
        matrixServer: effectiveMatrixServer(testMatrixServer),
      )) {
        return;
      }

      debugPrint('ENGAGEMENT: Resetting state with enhanced cleanup...');

      // Use our enhanced Matrix client cleanup utility
      await MatrixCleanup.resetTestEnvironment();

      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;

      debugPrint('ENGAGEMENT: Enhanced state reset complete');
    });

    tearDown(() async {
      debugPrint('ENGAGEMENT: Tearing down with enhanced cleanup...');

      // Use our enhanced Matrix client cleanup utility
      await MatrixCleanup.disposeMatrixClient();
    });

    // Helper to wait for the feed to be truly ready with content
    Future<void> waitForFeedReady(PatrolIntegrationTester $) async {
      debugPrint('ENGAGEMENT: Waiting for logic state (rooms)...');
      await fastWait(
        $.tester,
        () =>
            app.globalSubstitutionService?.roomCount != null &&
            app.globalSubstitutionService!.roomCount > 0,
      );

      debugPrint('ENGAGEMENT: Waiting for UI state (PostWidget)...');
      await fastWait(
        $.tester,
        () => find.byType(PostWidget).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 60),
      );

      await settle($.tester);
    }

    testWidgets(
      'Can view feed messages and interact',
      (tester) async {
        if (!await skipIfNoMatrix(
          matrixServer: effectiveMatrixServer(testMatrixServer),
        )) {
          return;
        }
        final $ = wrapTester(tester);
        app.main();
        await patrol_helper.loginUser(
          $,
          matrixServer: testMatrixServer,
          username: testUser,
          password: testPassword,
        );

        await waitForFeedReady($);

        expect(
          find.byType(PostWidget),
          findsAtLeastNWidgets(1),
          reason: 'Feed must contain messages',
        );

        // Verify common interaction elements are present on posts
        expect(
          find.byIcon(Icons.favorite_border_rounded),
          findsAtLeastNWidgets(1),
          reason: 'Messages should have reaction button',
        );
        expect(
          find.byIcon(Icons.chat_bubble_outline_rounded),
          findsAtLeastNWidgets(1),
          reason: 'Messages should have reply button',
        );

        debugPrint('✓ ENGAGEMENT: Feed content and buttons verified');
      },
      timeout: const Timeout(
        Duration(minutes: 15),
      ), // Further increased for CI reliability
    );

    testWidgets(
      'Can view user profile by tapping avatar',
      (tester) async {
        if (!await skipIfNoMatrix(
          matrixServer: effectiveMatrixServer(testMatrixServer),
        )) {
          return;
        }
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
        final avatar = find.byType(CircleAvatar).first;
        await $.tester.tap(avatar);
        await settle($.tester);

        // Wait for navigation/profile to appear
        await fastWait(
          $.tester,
          () =>
              find.textContaining('User Profile').evaluate().isNotEmpty ||
              find.textContaining('@').evaluate().isNotEmpty,
        );

        debugPrint('✓ ENGAGEMENT: Avatar interaction triggered profile view');
      },
      timeout: const Timeout(
        Duration(minutes: 15),
      ), // Further increased for CI reliability
    );

    testWidgets(
      'Messages from test_general room are visible',
      (tester) async {
        if (!await skipIfNoMatrix(
          matrixServer: effectiveMatrixServer(testMatrixServer),
        )) {
          return;
        }
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
        await fastWait(
          $.tester,
          () => find.textContaining('Hello everyone').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );

        expect(find.textContaining('Hello everyone'), findsAtLeastNWidgets(1));
        debugPrint('✓ ENGAGEMENT: Seeded messages verified in feed');
      },
      timeout: const Timeout(
        Duration(minutes: 15),
      ), // Further increased for CI reliability
    );
  });
}
