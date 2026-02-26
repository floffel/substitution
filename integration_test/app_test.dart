import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Substitution App - Base Patrol Integration Tests', (tester) async {
    final $ = wrapTester(tester);

    // Setup logic inside the test body
    SharedPreferences.setMockInitialValues({'age_confirmed': true});
    AgeGatePage.confirmed = true;
    if (!kIsWeb) {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDocDir.path}/matrix_database.db';
      final dbFile = dart_io.File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    }

    // Start the app
    app.main();

    // App starts and displays home page
    debugPrint('Patrol: Starting app check...');
    await $(MaterialApp).waitUntilVisible();
    
    // Check if we need to login
    if (app.globalMatrixClient?.isLogged() != true) {
      await patrol_helper.loginUser($);
    }

    // Verify the app is running by checking for Scrollable (Feed)
    expect($.tester.any(find.byType(Scrollable)), true);
    debugPrint('Patrol: Base check passed.');
  });
}
