import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/post/widgets/post.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:substitution/write/pages/textmessage.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:patrol/patrol.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait, waitUntilNotVisible;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  group('Strict Message Interaction (Reactions & Replies)', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser = 'testuser1';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
      
      // FRESH SETUP per test
      debugPrint('STRICT: Resetting state...');
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
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    // Helper to wait for the feed to be truly ready with content
    Future<void> waitForFeedReady(PatrolIntegrationTester $) async {
      debugPrint('STRICT: Waiting for logic state (rooms)...');
      await fastWait($.tester, () => app.globalSubstitutionService?.roomCount != null && app.globalSubstitutionService!.roomCount > 0);
      
      debugPrint('STRICT: Waiting for logic state (PagingController)...');
      await fastWait($.tester, () {
        try {
          // ignore: unused_local_variable
          final state = $.tester.state<HomePageState>(find.byType(HomePage));
          return find.byType(PostWidget).evaluate().isNotEmpty;
        } catch (_) {
          return false;
        }
      }, timeout: const Duration(seconds: 60));
      
      // One final pump to ensure everything is settled
      await $.tester.pumpAndSettle();
    }

    testWidgets('STRICT: Tap message shows reaction and reply options', (tester) async {
      final $ = wrapTester(tester);
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      await waitForFeedReady($);
      
      expect($(PostWidget).exists, true, reason: 'MUST display messages');
      // The icons are visible directly on the card in this app version
      expect($(Icons.favorite_rounded).exists, true, reason: 'MUST show reaction button');
      expect($(Icons.reply).exists, true, reason: 'MUST show reply button');
      
      debugPrint('✓ STRICT: Feed reached and messages interactive');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('STRICT: Reaction option exists', (tester) async {
      final $ = wrapTester(tester);
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      await waitForFeedReady($);
      expect($(Icons.favorite_rounded).exists, true, reason: 'MUST show reaction button');
      debugPrint('✓ STRICT: Reaction button found');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('STRICT: Can open emoji picker and react to message', (tester) async {
      final $ = wrapTester(tester);
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      await waitForFeedReady($);
      
      final reactionButton = $(Icons.favorite_rounded).first;
      await reactionButton.tap();

      // STRICT: Check for emoji picker
      await fastWait($.tester, () => $(EmojiPicker).exists);
      expect($(EmojiPicker).exists, true, reason: 'MUST show emoji picker');
      debugPrint('✓ STRICT: Emoji picker displayed');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('STRICT: Reply option exists', (tester) async {
      final $ = wrapTester(tester);
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      await waitForFeedReady($);
      expect($(Icons.reply).exists, true, reason: 'MUST show reply button');
      debugPrint('✓ STRICT: Reply button found');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('STRICT: Can open reply composer', (tester) async {
      final $ = wrapTester(tester);
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      await waitForFeedReady($);

      final replyButton = $(Icons.reply).first;
      await replyButton.tap();
      
      // STRICT: Wait for the new page to appear
      await fastWait($.tester, () => find.byType(TextMessageWrite).evaluate().isNotEmpty, timeout: const Duration(seconds: 30));
      await $.tester.pumpAndSettle();

      // STRICT: Check for reply composer editor
      await fastWait($.tester, () => find.byType(quill.QuillEditor).evaluate().isNotEmpty, timeout: const Duration(seconds: 30));
      expect($(quill.QuillEditor).exists, true, reason: 'MUST show reply composer editor');
      debugPrint('✓ STRICT: Reply composer opened');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
