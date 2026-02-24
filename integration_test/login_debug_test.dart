import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:substitution/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart' show waitForMatrixClient;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Debug full login flow', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'age_confirmed': true});
    AgeGatePage.confirmed = true;
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    app.main();
    await waitForMatrixClient(tester);

    // Wait for app to fully initialize
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(IntroductionScreen).evaluate().isNotEmpty) {
        debugPrint('IntroScreen found at ${(i + 1) * 500}ms');
        break;
      }
    }
    await tester.pumpAndSettle();

    // Swipe through all intro pages until host input is visible
    for (int i = 0; i < 8; i++) {
      if (find.byKey(const Key('hostServerInput')).evaluate().isNotEmpty ||
          find.byKey(const Key('loginUsernameInput')).evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(IntroductionScreen), const Offset(-400, 0));
      await tester.pumpAndSettle();
    }

    // Enter host
    final hostInput = find.byKey(const Key('hostServerInput'));
    expect(hostInput, findsOneWidget);
    await tester.enterText(hostInput, testMatrixServer);
    await tester.pumpAndSettle();

    // Scroll the submit button into view before tapping
    final submitBtn = find.byKey(const Key('hostSubmitButton'));
    await tester.ensureVisible(submitBtn);
    await tester.pumpAndSettle();
    await tester.tap(submitBtn);
    debugPrint('Tapped submit (after ensureVisible)');

    // Wait for network + transition
    bool loginFound = false;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      final loginField = find.byKey(const Key('loginUsernameInput'));
      final alertDialog = find.byType(AlertDialog);
      if (i % 4 == 0) {
        debugPrint(
          '  ${i * 500}ms: login=${loginField.evaluate().length} alert=${alertDialog.evaluate().length}',
        );
      }
      if (loginField.evaluate().isNotEmpty) {
        loginFound = true;
        debugPrint('LOGIN FIELD FOUND at ${i * 500}ms!');
        break;
      }
    }

    debugPrint('loginFound: $loginFound');
    if (loginFound) {
      // Try the full login
      await tester.enterText(
        find.byKey(const Key('loginUsernameInput')),
        'testuser1',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('loginPasswordInput')),
        'testpass123',
      );
      await tester.pumpAndSettle();

      final loginBtn = find.byType(ElevatedButton).first;
      await tester.ensureVisible(loginBtn);
      await tester.pumpAndSettle();
      await tester.tap(loginBtn);
      debugPrint('Tapped login button');

      // Wait for login
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(Scrollable).evaluate().isNotEmpty) {
          debugPrint('FEED FOUND at ${i * 500}ms - LOGIN SUCCESS!');
          break;
        }
      }
    }
  }, timeout: const Timeout(Duration(seconds: 120)));
}
