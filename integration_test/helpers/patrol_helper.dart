import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:matrix/matrix.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:substitution/main.dart' as app;
import 'integration_test_helper.dart' show skipIfNoMatrix, effectiveMatrixServer;

/// Patrol version of the login helper.
/// 
/// Uses Patrol's implicit waiting and intuitive finders to make the flow
/// extremely robust without manual pump loops.
Future<void> loginUser(
  PatrolIntegrationTester $, {
  String matrixServer = 'http://localhost:8008',
  String username = 'testuser1',
  String password = 'testpass123',
}) async {
  // 1. Skip if server not reachable
  if (!await skipIfNoMatrix(matrixServer: matrixServer)) return;

  // 2. Wait for app initialization (using Patrol's $ finder)
  await $(MaterialApp).waitUntilVisible();
  
  if (app.globalMatrixClient?.isLogged() == true) {
    if ($(Scrollable).exists) {
      debugPrint('Already logged in and on the feed page. Skipping login flow.');
      return;
    }
  }

  final serverUrl = effectiveMatrixServer(matrixServer);

  // 3. Handle Age Gate
  if ($(Key('ageGateConfirmButton')).exists) {
    debugPrint('Patrol: Tapping Age Gate...');
    await $(Key('ageGateConfirmButton')).tap();
  }

  // 4. Handle Intro Screen
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
    }
  }

  // 5. Host Page
  if ($(Key('hostServerInput')).exists) {
    debugPrint('Patrol: Entering host URL: $serverUrl');
    await $(Key('hostServerInput')).enterText(serverUrl);
    await $(Key('hostSubmitButton')).tap();
  }

  // 6. Login Page
  debugPrint('Patrol: Entering credentials...');
  // Patrol waits for these to appear
  await $(Key('loginUsernameInput')).enterText(username);
  await $(Key('loginPasswordInput')).enterText(password);
  await $(Key('loginSubmitButton')).tap();

  // 7. Finished Page
  final goButton = $(Key('introGoButton'));
  bool goVisible = false;
  try {
    await goButton.waitUntilVisible();
    goVisible = true;
  } catch (_) {}

  if (goVisible) {
    debugPrint('Patrol: Tapping Go button...');
    await goButton.tap();
  }

  // 8. Wait for Feed
  debugPrint('Patrol: Waiting for feed...');
  await $(Scrollable).waitUntilVisible();
  
  // Wait for Matrix Sync
  final client = app.globalMatrixClient;
  if (client != null && client.prevBatch == null) {
    debugPrint('Patrol: Waiting for initial sync...');
    try {
      await client.onSyncStatus.stream
          .firstWhere((s) => s.status == SyncStatus.finished)
          .timeout(const Duration(seconds: 60));
    } catch (_) {}
  }
  
  debugPrint('Patrol: Login complete.');
}
