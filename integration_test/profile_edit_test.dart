import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/settings/pages/profile.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:go_router/go_router.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Profile Editing Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      debugPrint('PROFILE_EDIT: Resetting state...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;

      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;
      
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

    tearDown(() async {
      debugPrint('PROFILE_EDIT: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets('Can change display name and save', (tester) async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      final $ = wrapTester(tester);
      app.main();
      
      if (!await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      )) {
        return;
      }

      // 1. Navigate to Profile page
      debugPrint('PROFILE_EDIT: Navigating to ProfilePage...');
      final navContext = $.tester.element(find.byType(HomePage));
      navContext.push('/settings/profile');
      await $.tester.pumpAndSettle();

      // 2. Verify ProfilePage
      expect($(ProfilePage).exists, true);
      
      // 3. Enter new display name
      final newName = 'Edited Name ${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('PROFILE_EDIT: Entering new name: $newName');
      await $(TextFormField).enterText(newName);
      await $.tester.pumpAndSettle();

      // 4. Tap Save Profile
      debugPrint('PROFILE_EDIT: Tapping Save...');
      await $(find.text('Save Profile')).tap();
      
      // 5. Wait for success snackbar or saving indicator to disappear
      debugPrint('PROFILE_EDIT: Waiting for save to complete...');
      await fastWait($.tester, () => find.text('Profile updated successfully').evaluate().isNotEmpty, timeout: const Duration(seconds: 30));
      
      expect($(find.text('Profile updated successfully')).exists, true);
      debugPrint('✓ PROFILE_EDIT: Successfully updated display name');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
