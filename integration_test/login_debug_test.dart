import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart'
    show skipIfNoMatrix;
import 'helpers/login_helper.dart' as login_helper;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Debug full login flow', (WidgetTester tester) async {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

    SharedPreferences.setMockInitialValues({'age_confirmed': true});
    AgeGatePage.confirmed = true;
    app.main();
    
    await login_helper.loginUser(
      tester,
      matrixServer: testMatrixServer,
      username: 'testuser1',
      password: 'testpass123',
    );

    expect(find.byType(Scrollable), findsWidgets);
    debugPrint('Debug Login success confirmed.');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
