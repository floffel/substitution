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
import 'helpers/integration_test_helper.dart' show fastWait;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    try {
      app.globalMatrixClient?.abortSync();
      await app.globalMatrixClient?.dispose();
    } catch (e) {
      debugPrint('TEST: Matrix client cleanup warning: $e');
    }
    app.globalMatrixClient = null;
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

  testWidgets('Substitution App - Base Patrol Integration Tests', (
    tester,
  ) async {
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
    await fastWait($.tester, () => $(MaterialApp).exists);

    // Check if we need to login
    if (app.globalMatrixClient?.isLogged() != true) {
      await patrol_helper.loginUser($);
    }

    // Verify the app is running by checking for Scrollable (Feed)
    await fastWait($.tester, () => $.tester.any(find.byType(Scrollable)));
    debugPrint('Patrol: Base check passed.');

    // Drain pending frames before tearDown disposes the Matrix client,
    // otherwise LiveTestWidgetsFlutterBinding asserts '_pendingFrame == null'.
    // Cannot use pumpAndSettle because the Matrix sync loop never settles.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
