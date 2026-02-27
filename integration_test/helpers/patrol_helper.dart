import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:matrix/matrix.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:substitution/main.dart' as app;
import 'integration_test_helper.dart'
    show skipIfNoMatrix, effectiveMatrixServer, fastWait, waitForMatrixClient;

/// Patrol version of the login helper.
///
/// Uses Patrol's implicit waiting combined with event-driven synchronization
/// to make the flow extremely robust and as fast as the hardware allows.
Future<bool> loginUser(
  PatrolIntegrationTester $, {
  String matrixServer = 'http://localhost:8008',
  String username = 'testuser1',
  String password = 'testpass123',
}) async {
  // 1. Skip if server not reachable
  if (!await skipIfNoMatrix(matrixServer: matrixServer)) return false;

  // 2. Wait for globalMatrixClient to be initialized
  await waitForMatrixClient($.tester);
  // Stabilization delay for SDK
  await Future.delayed(const Duration(seconds: 1));

  // 3. Wait for ANY valid starting screen (event-driven)
  debugPrint('Patrol: Waiting for app to render first screen...');
  await fastWait(
    $.tester,
    () =>
        $(Key('ageGateConfirmButton')).exists ||
        $(IntroductionScreen).exists ||
        $(Key('loginUsernameInput')).exists ||
        $(Key('hostServerInput')).exists ||
        $(Scrollable).exists,
  );

  if (app.globalMatrixClient?.isLogged() == true) {
    if ($(Scrollable).exists) {
      debugPrint(
        'Already logged in and on the feed page. Skipping login flow.',
      );
      return true;
    }
  }

  // Fast-Path: If we are already on the Host or Login page, don't try to navigate Intro
  if (!$(IntroductionScreen).exists && !$(Key('ageGateConfirmButton')).exists) {
    debugPrint('Patrol: Onboarding already bypassed, jumping to host/login');
  } else {
    // 3. Handle Age Gate (Conditional)
    if ($(Key('ageGateConfirmButton')).exists) {
      debugPrint('Patrol: Tapping Age Gate...');
      await $(Key('ageGateConfirmButton')).tap();
      await fastWait(
        $.tester,
        () =>
            $(IntroductionScreen).exists ||
            $(Key('hostServerInput')).exists ||
            $(Key('loginUsernameInput')).exists,
      );
    }

    // 4. Handle Intro Screen (Smart Navigation)
    if ($(IntroductionScreen).exists) {
      debugPrint('Patrol: Navigating through onboarding...');

      for (int i = 0; i < 3; i++) {
        if ($(Key('hostServerInput')).exists ||
            $(Key('loginUsernameInput')).exists) {
          break;
        }

        final nextButton = $(find.text('Next'));
        if (nextButton.exists) {
          await nextButton.tap();
        } else {
          final nextTranslated = $(find.text('intro.buttons.next'.tr()));
          if (nextTranslated.exists) {
            await nextTranslated.tap();
          } else {
            break;
          }
        }
        await $.tester.pump();
        await fastWait(
          $.tester,
          () => true,
          timeout: const Duration(milliseconds: 500),
        );
      }
    }
  }

  final serverUrl = effectiveMatrixServer(matrixServer);

  // 5. Host Page
  if ($(Key('hostServerInput')).exists) {
    debugPrint('Patrol: Entering host URL: $serverUrl');
    await $(Key('hostServerInput')).enterText(serverUrl);
    await $(Key('hostSubmitButton')).tap();
    // Wait up to 30s for transition to login page (network call)
    await $(
      Key('loginUsernameInput'),
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
  }

  // 6. Login Page
  debugPrint('Patrol: Entering credentials...');
  await $(Key('loginUsernameInput')).enterText(username);
  await $(Key('loginPasswordInput')).enterText(password);

  // Set up an event listener for the successful sync
  final syncCompleter = Completer<void>();
  final client = app.globalMatrixClient!;
  final subscription = client.onSyncStatus.stream.listen((status) {
    if (status.status == SyncStatus.finished) {
      if (!syncCompleter.isCompleted) syncCompleter.complete();
    }
  });

  await $(Key('loginSubmitButton')).tap();

  // 7. Event-Driven Sync Wait
  debugPrint('Event-Driven: Waiting for post-login sync event...');
  try {
    await syncCompleter.future.timeout(const Duration(seconds: 60));
    debugPrint('✓ Login event received');
  } catch (e) {
    debugPrint('⚠ Patrol: Warning - sync event not received within 60s');
  } finally {
    await subscription.cancel();
  }

  // 8. Finished Page & Feed
  final goButton = $(Key('introGoButton'));
  bool goVisible = false;
  try {
    // Wait up to 30s for the final intro page
    await goButton.waitUntilVisible(timeout: const Duration(seconds: 30));
    goVisible = true;
  } catch (_) {}

  if (goVisible) {
    debugPrint('Patrol: Tapping Go button...');
    await goButton.tap();
    await Future.delayed(const Duration(seconds: 1));
  }

  // Final rendering check - as fast as possible
  await fastWait($.tester, () => $(Scrollable).exists);
  debugPrint('Patrol: Login process complete.');
  return true;
}
