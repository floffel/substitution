import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:substitution/main.dart' as app;
import 'package:substitution/shared/pages/age_gate.dart';
import 'integration_test_helper.dart'
    show skipIfNoMatrix, waitForMatrixClient, waitForSync, waitUntilVisible, settle;

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

  // Pump to ensure the initial widget tree is rendered
  await tester.pump(const Duration(milliseconds: 500));

  if (app.globalMatrixClient?.isLogged() == true) {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(Scrollable).evaluate().isNotEmpty) {
        debugPrint('Already logged in and on the feed page. Skipping login flow.');
        return;
      }
    }
  }

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
  // Wait for any known first screen
  try {
    await waitUntilVisible(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w.key == const Key('ageGateConfirmButton') ||
            w is IntroductionScreen ||
            w.key == const Key('loginUsernameInput') ||
            w.key == const Key('hostServerInput'),
      ),
      timeout: const Duration(seconds: 20),
    );
  } catch (_) {
    debugPrint('Warning: No known screen found after 20s');
  }

  final ageGateFinder = find.byKey(const Key('ageGateConfirmButton'));
  if (ageGateFinder.evaluate().isNotEmpty) {
    debugPrint('Tapping Age Gate confirm button...');
    try {
      await tester.ensureVisible(ageGateFinder);
      await settle(
        tester,
        count: 2,
        interval: const Duration(milliseconds: 250),
      );
    } catch (e) {
      debugPrint('ensureVisible failed: $e — tapping anyway');
    }
    await tester.tap(ageGateFinder, warnIfMissed: false);
    // Wait for the next screen
    try {
      await waitUntilVisible(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w is IntroductionScreen ||
              w.key == const Key('loginUsernameInput') ||
              w.key == const Key('hostServerInput'),
        ),
        timeout: const Duration(seconds: 15),
      );
    } catch (_) {}
  }

  // ── Step 2: Onboarding Next-button taps ───────────────────────────────
  if (find.byType(IntroductionScreen).evaluate().isNotEmpty) {
    debugPrint('Step 2: Navigating through onboarding...');
    await settle(tester, count: 2);

    for (int i = 0; i < 3; i++) {
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

      // Tap the Next button by text — trying both literal and translated
      final nextLabels = ['Next', 'intro.buttons.next'.tr()];
      bool buttonFound = false;
      for (final label in nextLabels) {
        final nextButtonFinder = find.text(label);
        if (nextButtonFinder.evaluate().isNotEmpty) {
          debugPrint('Tapping Next button with label "$label" at step $i...');
          await tester.tap(nextButtonFinder.first);
          buttonFound = true;
          break;
        }
      }

      if (!buttonFound) {
        for (final label in nextLabels) {
          final nextTextButton = find.widgetWithText(TextButton, label);
          if (nextTextButton.evaluate().isNotEmpty) {
            debugPrint(
              'Tapping Next TextButton with label "$label" at step $i (fallback)...',
            );
            await tester.tap(nextTextButton.first);
            buttonFound = true;
            break;
          }
        }
      }

      if (!buttonFound) {
        debugPrint('Next button not found at step $i — stopping early.');
        break;
      }

      await settle(
        tester,
        count: 10,
        interval: const Duration(milliseconds: 100),
      );
    }
    debugPrint('Onboarding navigation complete.');
  }

  // ── Step 3: Host page ─────────────────────────────────────────────────
  final hostFinder = find.byKey(const Key('hostServerInput'));
  if (hostFinder.evaluate().isNotEmpty) {
    debugPrint('Step 3: Entering host URL: $matrixServer');
    await tester.enterText(hostFinder, matrixServer);
    await settle(tester, count: 2);

    final submitButton = find.byKey(const Key('hostSubmitButton'));
    debugPrint('Tapping host submit button...');
    await tester.ensureVisible(submitButton);
    await settle(tester, count: 2);
    await tester.tap(submitButton, warnIfMissed: false);

    // Wait for the login page to appear
    debugPrint('Waiting for login page to appear...');
    try {
      await waitUntilVisible(
        tester,
        find.byKey(const Key('loginUsernameInput')),
        timeout: const Duration(seconds: 20),
      );
      debugPrint('Login page reached.');
    } catch (e) {
      debugPrint('Failed to reach login page: $e');
    }
  } else {
    debugPrint('Host page skipped (already configured or not visible).');
    await settle(tester, count: 2);
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
  expect(usernameField, findsOneWidget);

  debugPrint('Entering credentials for $username...');
  await tester.enterText(usernameField, username);
  await settle(tester, count: 2);

  final passwordField = find.byKey(const Key('loginPasswordInput'));
  await tester.enterText(passwordField, password);
  await settle(tester, count: 2);

  final loginButton = find.byKey(const Key('loginSubmitButton'));
  await tester.ensureVisible(loginButton);
  await settle(tester, count: 2);
  debugPrint('Tapping login submit button...');
  await tester.tap(loginButton, warnIfMissed: false);

  // ── Step 5: Finished page ──────────────────────────────────────────────
  debugPrint('Step 5: Waiting for Finished page or Feed...');
  for (int i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    final hasGo = find.byKey(const Key('introGoButton')).evaluate().isNotEmpty;
    final hasFeed = find.byType(Scrollable).evaluate().isNotEmpty;
    if (hasGo || hasFeed) break;
  }

  final goButton = find.byKey(const Key('introGoButton'));
  if (goButton.evaluate().isNotEmpty) {
    debugPrint('Finished page reached. Tapping Go button...');
    await tester.tap(goButton, warnIfMissed: false);
    // Final wait for feed
    try {
      await waitUntilVisible(
        tester,
        find.byType(Scrollable),
        timeout: const Duration(seconds: 15),
      );
      debugPrint('Feed reached after finished page.');
    } catch (_) {
      debugPrint('Warning: Feed not reached within 15s after Go');
    }
  } else if (find.byType(Scrollable).evaluate().isNotEmpty) {
    debugPrint('Feed reached without finished page.');
  }

  // Final Wait for Matrix Sync to fully settle the state
  await waitForSync(tester);
  debugPrint('Login process complete.');
}
