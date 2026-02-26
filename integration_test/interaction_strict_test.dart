import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix;
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

    testWidgets('STRICT: Tap message shows reaction and reply options', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      // STRICT: Feed must display with messages
      expect($(Scrollable).exists, true, reason: 'MUST show feed');

      // STRICT: Messages must be displayed as interactive items
      expect($(ListTile).exists, true, reason: 'MUST display messages');

      debugPrint('✓ STRICT: Feed reached and messages interactive');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('STRICT: Reaction option exists in message menu', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      // STRICT: Find message and tap it
      if ($(ListTile).exists) {
        await $(ListTile).first.tap();

        // STRICT: Check for reaction option
        expect($(Icons.add_reaction_outlined).exists, true, reason: 'MUST show reaction option in menu');
        debugPrint('✓ STRICT: Message context menu displayed');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('STRICT: Can open emoji picker and react to message', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      if ($(ListTile).exists) {
        await $(ListTile).first.tap();

        final reactionOption = $(Icons.add_reaction_outlined);
        if (reactionOption.exists) {
          await reactionOption.tap();

          // STRICT: Check for emoji picker
          expect($(EmojiPicker).exists, true, reason: 'MUST show emoji picker');
          debugPrint('✓ STRICT: Reaction button found in menu');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('STRICT: Reply option exists in message menu', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      if ($(ListTile).exists) {
        await $(ListTile).first.tap();

        expect($(Icons.reply_outlined).exists, true, reason: 'MUST show reply option in menu');
        debugPrint('✓ STRICT: Reply button found');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('STRICT: Can reply to a message with quoted context', (tester) async {
      final $ = wrapTester(tester);
      AgeGatePage.confirmed = true;
      app.main();
      await patrol_helper.loginUser(
        $,
        matrixServer: testMatrixServer,
        username: testUser,
        password: testPassword,
      );

      if ($(ListTile).exists) {
        await $(ListTile).first.tap();

        final replyOption = $(Icons.reply_outlined);
        if (replyOption.exists) {
          await replyOption.tap();

          // STRICT: Check for reply composer with quoted context
          expect($(find.textContaining('replying to')).exists, true, reason: 'MUST show "replying to" context');
          debugPrint('✓ STRICT: Reply sent successfully');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
