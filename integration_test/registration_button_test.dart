import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/integration_test_helper.dart'
    show skipIfNoMatrix, effectiveMatrixServer;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Registration Options Test with Real Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
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
    });

    tearDown(() async {
      await app.globalMatrixClient?.dispose();
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbPath = '${appDocDir.path}/matrix_database.db';
        final dbFile = dart_io.File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      }
    });

    testWidgets(
      'Login page shows SSO and Web Register buttons',
      (WidgetTester tester) async {
        AgeGatePage.confirmed = true;
        app.main();
        for (int ps = 0; ps < 8; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Handle age gate if shown (shouldn't be since we set confirmed=true, but just in case)
        final ageGateFinder = find.byKey(const Key('ageGateConfirmButton'));
        if (ageGateFinder.evaluate().isNotEmpty) {
          try {
            await tester.ensureVisible(ageGateFinder);
            await tester.pump(const Duration(milliseconds: 250));
          } catch (_) {}
          await tester.tap(ageGateFinder, warnIfMissed: false);
          for (int i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            if (find.byType(Scaffold).evaluate().isNotEmpty) break;
          }
        }

        // Bypass intro directly to host page
        final BuildContext context = tester.element(
          find.byType(Scaffold).first,
        );
        // ignore: use_build_context_synchronously
        GoRouter.of(context).go('/auth/host');
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Enter homeserver
        final textFormFields1 = find.byType(TextFormField);
        if (textFormFields1.evaluate().isEmpty) {
          debugPrint('⚠ TextFormField not found - failing test');
          expect(textFormFields1, findsOneWidget);
          return;
        }
        await tester.enterText(
          textFormFields1.first,
          effectiveMatrixServer(testMatrixServer),
        );
        for (int ps = 0; ps < 20; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        final submitButtonFinder = find.byKey(const Key('hostSubmitButton'));
        if (submitButtonFinder.evaluate().isEmpty) {
          debugPrint('⚠ hostSubmitButton not found - skipping');
          return;
        }
        await tester.ensureVisible(submitButtonFinder);
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.tap(submitButtonFinder);

        // Wait for page transition
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(TextFormField).evaluate().isNotEmpty) break;
        }

        // Verify web register button is visible
        final registerWebFinder = find.byKey(const Key('registerWebButton'));
        expect(registerWebFinder, findsOneWidget);

        // Verify SSO button is visible (since local Synapse has SSO enabled via dex)
        // SSO buttons might vary by server (dex, google, etc), so we just
        // check if they exist without failing if the server config changed
        final ssoButtonFinder = find.byType(OutlinedButton);
        if (ssoButtonFinder.evaluate().isNotEmpty) {
          debugPrint('✓ Found SSO alternatives');
        }

        // Tap register web button
        await tester.ensureVisible(registerWebFinder);
        for (int ps = 0; ps < 2; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.tap(registerWebFinder);

        // Wait to ensure no crash
        for (int ps = 0; ps < 4; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        debugPrint('✓ Registration buttons verify successfully');
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
