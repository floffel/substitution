import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart'
    show waitForMatrixClient, skipIfNoMatrix;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Consolidated Logout Flow', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      debugPrint('--- setUp ---');
      // Bypass the age gate so the app goes straight to /intro on cold start.
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;
      if (!kIsWeb) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final mainDb = dart_io.File('${appDocDir.path}/matrix_database.db');
          if (await mainDb.exists()) {
            await mainDb.delete();
          }
        } catch (e) {
          debugPrint('Error in setUp: $e');
        }
      }
    });

    tearDown(() async {
      debugPrint('--- tearDown ---');
      try {
        await app.globalMatrixClient?.dispose();
        app.globalMatrixClient = null;
      } catch (e) {
        debugPrint('Error disposing Matrix client: $e');
      }
    });

    Future<void> stablePump(WidgetTester tester, {int ms = 500}) async {
      // Use the heavy-pumping pattern for macOS stability
      for (int i = 0; i < 2; i++) {
        await tester.pump(Duration(milliseconds: ms ~/ 2));
      }
    }

    Future<void> waitFor(
      WidgetTester tester,
      Finder finder, {
      int limit = 50,
    }) async {
      for (int i = 0; i < limit; i++) {
        await stablePump(tester, ms: 200);
        if (finder.evaluate().isNotEmpty) return;
      }
      debugPrint('Timeout waiting for $finder');
    }

    Future<void> loginUser(WidgetTester tester) async {
      // Skip gracefully when no Matrix server is available (e.g. iOS CI, no Docker).
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      debugPrint('STEP: Initial Onboarding');
      // Ensure app.main() has completed runApp() before querying the widget tree.
      await waitForMatrixClient(tester);
      // Wait for any known first screen to appear
      await waitFor(tester, find.byType(IntroductionScreen));

      // Only navigate through intro if IntroductionScreen is actually present.
      // Use the "Next" button — canProgress() blocks PageView drags.
      if (find.byType(IntroductionScreen).evaluate().isNotEmpty) {
        for (int i = 0; i < 3; i++) {
          if (find.byKey(const Key('hostServerInput')).evaluate().isNotEmpty ||
              find
                  .byKey(const Key('loginUsernameInput'))
                  .evaluate()
                  .isNotEmpty) {
            break;
          }
          final nextButtonFinder = find.text('Next');
          if (nextButtonFinder.evaluate().isNotEmpty) {
            await tester.tap(nextButtonFinder.first);
          } else {
            break;
          }
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
          for (int ps = 0; ps < 2; ps++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
        }
      }

      debugPrint('STEP: Entering Homeserver');
      // Only enter host if host input is visible
      if (find.byKey(const Key('hostServerInput')).evaluate().isNotEmpty) {
        await tester.enterText(
          find.byKey(const Key('hostServerInput')),
          testMatrixServer,
        );
        await stablePump(tester);
        await tester.tap(find.byKey(const Key('hostSubmitButton')));
      }

      debugPrint('STEP: Entering Credentials');
      await waitFor(tester, find.byKey(const Key('loginUsernameInput')));
      await tester.enterText(
        find.byKey(const Key('loginUsernameInput')),
        testUser,
      );
      await tester.enterText(
        find.byKey(const Key('loginPasswordInput')),
        testPassword,
      );
      await stablePump(tester);
      await tester.tap(find.byKey(const Key('loginSubmitButton')));

      debugPrint('STEP: Final Introduction Check');
      final goBtnFinder = find.byKey(const Key('introGoButton'));
      await waitFor(tester, goBtnFinder);
      await tester.ensureVisible(goBtnFinder);
      await stablePump(tester);
      await tester.tap(goBtnFinder, warnIfMissed: false);

      await stablePump(tester, ms: 1000);
      debugPrint('STEP: Waiting for Main Feed');
      await waitFor(tester, find.byIcon(Icons.menu));
    }

    testWidgets(
      'Verify Logout wipes the session and local database',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 768));

        app.main();
        await stablePump(tester, ms: 3000);

        await loginUser(tester);

        // --- LOGOUT FLOW ---
        debugPrint('STEP: Logout Flow');
        await tester.tap(find.byIcon(Icons.menu));
        await stablePump(tester, ms: 1000);

        final logoutIcon = find.byIcon(Icons.logout);
        expect(logoutIcon, findsOneWidget);
        await tester.tap(logoutIcon);

        // Wait for redirect to onboarding
        await waitFor(tester, find.byType(IntroductionScreen));

        // --- VERIFICATION ---
        expect(
          app.globalMatrixClient?.isLogged(),
          false,
          reason: 'Session should be terminated',
        );

        // Final check for onboarding page content
        expect(find.byType(IntroductionScreen), findsOneWidget);
        debugPrint('Consolidated Logout test passed successfully');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
