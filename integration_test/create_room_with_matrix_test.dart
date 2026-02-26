import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/settings/widgets/dialogcreateroom.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait, waitUntilNotVisible;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Create Room explicitly on Follow Feeds with Matrix Server', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      debugPrint('CREATE_ROOM: Resetting state...');
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
      debugPrint('CREATE_ROOM: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets('User can create a new room and see it in the list', (tester) async {
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

      // 1. Navigate directly to discovery
      debugPrint('CREATE_ROOM: Navigating to discovery...');
      final navContext = $.tester.element(find.byType(HomePage));
      navContext.push('/settings/feed');
      await $.tester.pumpAndSettle();

      // 2. Tap Create Room button (ActionChip with Icons.add_box)
      debugPrint('CREATE_ROOM: Tapping Create Room chip...');
      // Use the translated text to find the chip
      final createLabel = 'settings.ownfeeds.buttons.create_room'.tr();
      final createChip = $(find.text(createLabel));
      await createChip.waitUntilVisible();
      await createChip.tap();
      await $.tester.pumpAndSettle();

      // 3. Verify DialogCreateRoom
      expect($(DialogCreateRoom).exists, true);
      
      // 4. Fill in room name
      final newRoomName = 'EXPLICIT_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('CREATE_ROOM: Entering room name: $newRoomName');
      
      final nameFieldFinder = find.byType(TextFormField).first;
      await $.tester.ensureVisible(nameFieldFinder);
      await $.tester.pumpAndSettle();
      
      await $.tester.enterText(nameFieldFinder, newRoomName);
      await $.tester.pumpAndSettle();

      // 5. Submit
      debugPrint('CREATE_ROOM: Tapping Create button...');
      final submitLabel = 'settings.dialog.create.submit'.tr();
      await $(find.text(submitLabel)).tap();
      
      // 6. Wait for dialog to close
      debugPrint('CREATE_ROOM: Waiting for dialog to close...');
      await waitUntilNotVisible($.tester, find.byType(DialogCreateRoom), timeout: const Duration(seconds: 30));
      
      // 7. Verify room appears in list
      debugPrint('CREATE_ROOM: Verifying room in list...');
      // Search for the room
      await $(TextField).first.enterText(newRoomName);
      await $.tester.pumpAndSettle();
      
      await fastWait($.tester, () => find.textContaining(newRoomName).evaluate().isNotEmpty, timeout: const Duration(seconds: 30));
      expect($(find.textContaining(newRoomName)).exists, true);
      
      debugPrint('✓ CREATE_ROOM: Successfully created and verified room');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
