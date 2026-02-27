import "package:integration_test/integration_test.dart";
import 'dart:io' as dart_io;
import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, fastWait;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Multi-User Correspondence Integration Tests', () {
    const testMatrixServer = String.fromEnvironment(
      'MATRIX_SERVER',
      defaultValue: 'http://localhost:8008',
    );
    const testUser1 = 'testuser1';
    const testUser2 = 'testuser2';
    const testPassword = 'testpass123';

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

      debugPrint('MULTI_USER: Resetting state...');
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
          final dbFile2 = dart_io.File('${appDocDir.path}/bg_database.db');
          if (await dbFile2.exists()) {
            await dbFile2.delete();
          }
        } catch (_) {}
      }
    });

    tearDown(() async {
      debugPrint('MULTI_USER: Tearing down...');
      await app.globalMatrixClient?.dispose();
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    });

    testWidgets(
      'UI User receives message from background SDK user',
      (tester) async {
        if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;

        final $ = wrapTester(tester);
        app.main();

        // 1. UI User (testuser1) logins
        if (!await patrol_helper.loginUser(
          $,
          matrixServer: testMatrixServer,
          username: testUser1,
          password: testPassword,
        )) {
          return;
        }

        final client1 = app.globalMatrixClient!;

        // 2. Setup Background User (testuser2) using a fresh SDK client
        debugPrint('MULTI_USER: Initializing background user client...');

        late final MatrixSdkDatabase bgDatabase;
        if (!kIsWeb) {
          final appDocDir = await getApplicationDocumentsDirectory();
          final dbPath = '${appDocDir.path}/bg_database.db';
          final database = await openDatabase(
            dbPath,
            version: 1,
            onCreate:
                (db, v) => db.execute(
                  'CREATE TABLE clients (id TEXT PRIMARY KEY, homeserver_url TEXT, token TEXT, user_id TEXT)',
                ),
          );
          bgDatabase = await MatrixSdkDatabase.init(
            'BgUser',
            database: database,
          );
        } else {
          bgDatabase = await MatrixSdkDatabase.init('BgUser');
        }

        final client2 = Client('BackgroundUser', database: bgDatabase);
        await client2.init();

        final hsUri = Uri.parse(testMatrixServer);
        await client2.checkHomeserver(hsUri);

        await client2.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: testUser2),
          password: testPassword,
        );

        // Matrix SDK 6.1.1 uses client.sync() instead of startSync()
        // ignore: unawaited_futures
        client2.sync();

        try {
          // 3. Find a shared room (test_general)
          final rooms1 = await client1.getJoinedRooms();
          final generalRoomId = rooms1.firstWhere(
            (id) => client1.getRoomById(id)?.name == 'test_general',
          );

          // Wait for background user to see the room
          debugPrint(
            'MULTI_USER: Waiting for background user to see room $generalRoomId...',
          );
          await fastWait(
            $.tester,
            () => client2.getRoomById(generalRoomId) != null,
            timeout: const Duration(seconds: 30),
          );
          final room2 = client2.getRoomById(generalRoomId)!;

          // 4. Background User sends a message
          final uniqueBody =
              'MESSAGE_FROM_BG_${DateTime.now().millisecondsSinceEpoch}';
          debugPrint('MULTI_USER: Sending message from testuser2: $uniqueBody');
          await room2.sendTextEvent(uniqueBody);

          // 5. UI User verifies receipt in feed
          debugPrint('MULTI_USER: Waiting for UI user to see message...');
          await fastWait($.tester, () {
            return find
                .textContaining(uniqueBody, skipOffstage: false)
                .evaluate()
                .isNotEmpty;
          }, timeout: const Duration(seconds: 60));

          expect($(find.textContaining(uniqueBody)).exists, true);
          debugPrint('✓ MULTI_USER: Cross-user message delivery verified');
        } finally {
          await client2.dispose();
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
