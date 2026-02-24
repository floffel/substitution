import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'integration_test_helper.dart' show skipIfNoMatrix, waitForMatrixClient;

/// Drives the full login flow from a cold-start app state.
///
/// Handles, in order:
///   1. Age Gate  — taps [ageGateConfirmButton] if visible
///   2. Onboarding swipe — swipes through IntroductionScreen pages 0→2
///                         only if IntroductionScreen is actually rendered
///   3. Host page  — fills [hostServerInput] and taps [hostSubmitButton]
///                   only if that input is visible
///   4. Login page — fills [loginUsernameInput] / [loginPasswordInput]
///                   and taps [loginSubmitButton]
///   5. Finished page — taps [introGoButton] if present, then waits for feed
///
/// [matrixServer] defaults to `http://localhost:8008`.
///
/// If the Matrix server is not reachable, the test is marked as skipped.
Future<void> loginUser(
  WidgetTester tester, {
  String matrixServer = 'http://localhost:8008',
  String username = 'testuser1',
  String password = 'testpass123',
}) async {
  // Skip the test gracefully when no Matrix server is available (e.g. iOS CI)
  if (!await skipIfNoMatrix(matrixServer: matrixServer)) return;

  // Ensure app.main() has completed runApp() and the Matrix client is ready
  // before querying the widget tree.
  await waitForMatrixClient(tester);

  // On Android emulators, localhost points to the emulator itself.
  // To reach the host machine, we must use 10.0.2.2.
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      matrixServer.contains('localhost')) {
    matrixServer = matrixServer.replaceAll('localhost', '10.0.2.2');
    debugPrint('Android detected: Translated localhost to $matrixServer');
  }

  // ── Step 1: Age Gate ───────────────────────────────────────────────────
  debugPrint('Step 1: Checking for Age Gate, Intro, or Login fields...');
  // Wait up to 15 s for any known first screen.
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    final hasAgeGate =
        find.byKey(const Key('ageGateConfirmButton')).evaluate().isNotEmpty;
    final hasIntro = find.byType(IntroductionScreen).evaluate().isNotEmpty;
    final hasUsername =
        find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty;
    final hasHost =
        find.byKey(const Key('hostServerInput')).evaluate().isNotEmpty;
    if (hasAgeGate || hasIntro || hasUsername || hasHost) {
      debugPrint(
        'Found screen! AgeGate: $hasAgeGate, Intro: $hasIntro, Username: $hasUsername, Host: $hasHost',
      );
      break;
    }
  }

  final ageGateFinder = find.byKey(const Key('ageGateConfirmButton'));
  if (ageGateFinder.evaluate().isNotEmpty) {
    debugPrint('Tapping Age Gate confirm button...');
    await tester.tap(ageGateFinder);
    // Wait up to 10 s for the intro screen or login page to appear
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      final hasIntro = find.byType(IntroductionScreen).evaluate().isNotEmpty;
      final hasUsername =
          find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty;
      final hasHost =
          find.byKey(const Key('hostServerInput')).evaluate().isNotEmpty;
      if (hasIntro || hasUsername || hasHost) {
        debugPrint(
          'Transition after Age Gate complete. Intro: $hasIntro, Username: $hasUsername, Host: $hasHost',
        );
        break;
      }
    }
  }

  // ── Step 2: Onboarding swipe ───────────────────────────────────────────
  if (find.byType(IntroductionScreen).evaluate().isNotEmpty) {
    debugPrint('Step 2: Navigating through onboarding...');
    for (int ps = 0; ps < 4; ps++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Swiping through pages until we reach the Host page or Login page.
    // Use 8 iterations to handle up to 5 intro pages with margin.
    for (int i = 0; i < 8; i++) {
      final hasHost =
          find.byKey(const Key('hostServerInput')).evaluate().isNotEmpty;
      final hasUsername =
          find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty;
      if (hasHost || hasUsername) {
        debugPrint(
          'Reached target page at step $i. Host: $hasHost, Username: $hasUsername',
        );
        break;
      }

      debugPrint('Swiping one page carefully at step $i...');
      final pageViewFinder = find.byType(PageView);
      if (pageViewFinder.evaluate().isNotEmpty) {
        // A controlled drag of 40% of the screen width (assuming 800-1000px)
        await tester.drag(pageViewFinder.first, const Offset(-450, 0));
      } else {
        await tester.drag(
          find.byType(IntroductionScreen),
          const Offset(-450, 0),
        );
      }
      // Wait for animation to finish
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    }
    debugPrint('Onboarding navigation complete.');
  }

  // ── Step 3: Host page ─────────────────────────────────────────────────
  final hostFinder = find.byKey(const Key('hostServerInput'));
  if (hostFinder.evaluate().isNotEmpty) {
    debugPrint('Step 3: Entering host URL: $matrixServer');
    await tester.enterText(hostFinder, matrixServer);
    for (int ps = 0; ps < 4; ps++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    final submitButton = find.byKey(const Key('hostSubmitButton'));
    debugPrint('Tapping host submit button...');
    await tester.ensureVisible(submitButton);
    for (int ps = 0; ps < 4; ps++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(submitButton, warnIfMissed: false);

    // Wait up to 15 s for the login page to appear
    debugPrint('Waiting for login page to appear...');
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty) {
        debugPrint('Login page reached.');
        break;
      }
    }
  } else {
    // Host already configured — let any pending transitions settle
    debugPrint('Host page skipped (already configured or not visible).');
    for (int ps = 0; ps < 4; ps++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  // ── Step 4: Login page ─────────────────────────────────────────────────
  debugPrint('Step 4: Looking for login fields...');
  final usernameField = find.byKey(const Key('loginUsernameInput'));
  if (usernameField.evaluate().isEmpty) {
    debugPrint('CRITICAL: loginUsernameInput NOT FOUND!');
    debugPrint(
      'All visible text: ${tester.allWidgets.whereType<Text>().map((t) => t.data).join(', ')}',
    );
  }
  expect(
    usernameField,
    findsOneWidget,
    reason: 'Username field should be visible on the login page',
  );

  debugPrint('Entering username: $username');
  await tester.enterText(usernameField, username);
  for (int ps = 0; ps < 4; ps++) {
    await tester.pump(const Duration(milliseconds: 500));
  }

  debugPrint('Entering password...');
  await tester.enterText(find.byKey(const Key('loginPasswordInput')), password);
  for (int ps = 0; ps < 4; ps++) {
    await tester.pump(const Duration(milliseconds: 500));
  }

  final loginButton = find.byKey(const Key('loginSubmitButton'));
  debugPrint('Tapping login submit button...');
  await tester.ensureVisible(loginButton);
  for (int ps = 0; ps < 4; ps++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.tap(loginButton, warnIfMissed: false);

  // ── Step 5: Finished page ──────────────────────────────────────────────
  debugPrint('Step 5: Waiting for finished page (introGoButton)...');
  for (int i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byKey(const Key('introGoButton')).evaluate().isNotEmpty) {
      debugPrint('Finished page reached.');
      break;
    }
  }

  final goButton = find.byKey(const Key('introGoButton'));
  if (goButton.evaluate().isNotEmpty) {
    debugPrint('Tapping Go button...');
    await tester.tap(goButton, warnIfMissed: false);
    // Pump without pumpAndSettle to avoid stalling on the Matrix sync loop
    debugPrint('Waiting for feed (Scrollable)...');
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(Scrollable).evaluate().isNotEmpty) {
        debugPrint('Feed reached.');
        break;
      }
    }
  }
}
