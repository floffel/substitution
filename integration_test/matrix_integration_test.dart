import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix, effectiveMatrixServer;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  // Get test server details from environment variables
  const matrixServer = String.fromEnvironment(
    'MATRIX_SERVER',
    defaultValue: 'http://localhost:8008',
  );
  const testUser = 'testuser1';
  const testPassword = 'testpass123';

  group('Matrix Server Integration Tests', () {
    Client? client;
    Database? sqliteDatabase;

    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: effectiveMatrixServer(matrixServer))) return;

      // Initialize SQLite database
      late final MatrixSdkDatabase database;

      if (!kIsWeb) {
        // Get the application documents directory for tests
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbPath =
            '${appDocDir.path}/matrix_test_${DateTime.now().millisecondsSinceEpoch}.db';

        // Open the SQLite database
        sqliteDatabase = await openDatabase(
          dbPath,
          version: 1,
          onCreate: (db, version) {
            // Create the database tables
            return db.execute('''
              CREATE TABLE clients (
                id TEXT PRIMARY KEY,
                homeserver_url TEXT,
                token TEXT,
                user_id TEXT
              )
            ''');
          },
        );

        database = await MatrixSdkDatabase.init(
          'integration_test_${DateTime.now().millisecondsSinceEpoch}',
          database: sqliteDatabase,
        );
      } else {
        // Web support: use default (IndexedDB)
        database = await MatrixSdkDatabase.init(
          'integration_test_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      client = Client(
        'integration_test_${DateTime.now().millisecondsSinceEpoch}',
        database: database,
      );
    });

    tearDown(() async {
      if (client == null) return;
      // Cleanup - logout, dispose, and close database
      try {
        if (client!.isLogged()) {
          await client!.logout();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
      try {
        await client!.dispose();
      } catch (e) {
        // Ignore dispose errors
      }

      // Close SQLite database
      if (sqliteDatabase != null && !kIsWeb) {
        try {
          await sqliteDatabase!.close();
        } catch (e) {
          // Ignore database close errors
        }
      }
    });

    // Internal helper to find rooms by various identifiers
    Room? findRoom(String search) {
      if (client == null) return null;
      for (final room in client!.rooms) {
        final localizedName = room.getLocalizedName();
        final name = room.name;
        final alias = room.canonicalAlias;
        if (localizedName.contains(search) || 
            name.contains(search) || 
            alias.contains(search)) {
          return room;
        }
      }
      return null;
    }

    testWidgets('Connect to Matrix test server', (WidgetTester tester) async {
      if (client == null) return;
      // Check server version
      final supported = await client!.checkHomeserver(
        Uri.parse(effectiveMatrixServer(matrixServer)),
      );
      expect(supported, isNotNull);
    });

    testWidgets('Login with test user credentials', (
      WidgetTester tester,
    ) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));

      // Login with test user
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      expect(client!.userID, contains(testUser));
      expect(client!.isLogged(), true);
    });

    testWidgets('Access test server with valid credentials', (
      WidgetTester tester,
    ) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));

      // Attempt login
      final response = await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      expect(response, isNotNull);
      expect(client!.isLogged(), true);

      // Sync to get rooms
      await client!.sync();
      expect(client!.rooms, isNotEmpty);
    });

    testWidgets('Verify test rooms exist', (WidgetTester tester) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Sync to get rooms
      await client!.sync();

      // Should have test rooms
      expect(client!.rooms, isNotEmpty);

      // Look for test rooms
      final hasTestRoom = client!.rooms.any((r) {
        final ln = r.getLocalizedName();
        final n = r.name;
        final a = r.canonicalAlias;
        return ln.contains('test_') || n.contains('test_') || a.contains('test_');
      });
      expect(hasTestRoom, true);
    });

    testWidgets('Test room with messages vs empty room', (
      WidgetTester tester,
    ) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client!.sync();

      // Find test rooms using robust helper
      final generalRoom = findRoom('general');
      final artRoom = findRoom('art');

      expect(generalRoom, isNotNull);
      expect(artRoom, isNotNull);
    });

    testWidgets('Verify multiple test users created', (
      WidgetTester tester,
    ) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client!.sync();

      // Get a room
      final room = client!.rooms.isNotEmpty ? client!.rooms.first : null;
      expect(room, isNotNull);

      // Check room members
      final members = await room!.requestParticipants();
      expect(members, isNotEmpty);
    });

    testWidgets('Send message to test room', (WidgetTester tester) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client!.sync();

      final room = client!.rooms.isNotEmpty ? client!.rooms.first : null;
      expect(room, isNotNull);

      // Send a test message
      final messageText = 'Integration test message';
      final eventId = await room!.sendTextEvent(messageText);

      expect(eventId, isNotNull);
      expect(eventId, isNotEmpty);
    });

    testWidgets('Login as different test user', (WidgetTester tester) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));

      // Login as testuser2
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'testuser2'),
        password: 'testpass123',
      );

      expect(client!.userID, contains('testuser2'));
      expect(client!.isLogged(), true);
    });

    testWidgets('Rooms are public and joinable', (WidgetTester tester) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Robust room discovery with retries
      Room? generalRoom, photosRoom, artRoom;
      for (int i = 0; i < 5; i++) {
        await client!.sync();
        generalRoom = findRoom('general');
        photosRoom = findRoom('photos');
        artRoom = findRoom('art');
        
        if (generalRoom != null && photosRoom != null && artRoom != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      if (generalRoom == null || photosRoom == null || artRoom == null) {
        throw Exception('Test rooms not found. \n'
            'Rooms: ${client!.rooms.map((e) => "${e.id}: '${e.name}' | '${e.getLocalizedName()}' (${e.canonicalAlias})").toList()}');
      }

      expect(generalRoom, isNotNull);
      expect(photosRoom, isNotNull);
      expect(artRoom, isNotNull);
    });

    testWidgets('List joined rooms', (WidgetTester tester) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Sync to get rooms
      await client!.sync();
      final rooms = client!.rooms;

      // Should have test rooms
      expect(rooms, isNotEmpty);
      expect(rooms.length, greaterThanOrEqualTo(3));
    });

    testWidgets('Room with messages contains messages', (
      WidgetTester tester,
    ) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Sync to get rooms
      await client!.sync();
      final generalRoom = findRoom('general');

      expect(generalRoom, isNotNull);

      // Get room timeline and check for messages
      final timeline = await generalRoom!.getTimeline();

      // test_general room should have messages
      expect(timeline.events.isNotEmpty, true);
    });

    testWidgets('Empty room should have no messages', (WidgetTester tester) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Sync to get rooms
      await client!.sync();
      final artRoom = findRoom('art');

      expect(artRoom, isNotNull);

      // Get room timeline
      final timeline = await artRoom!.getTimeline();

      // Empty room should have no messages (only state events)
      final messages =
          timeline.events.where((e) => e.type == 'm.room.message').toList();
      expect(messages.isEmpty, true);
    });

    testWidgets('Multiple users in same room', (WidgetTester tester) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client!.sync();
      final generalRoom = findRoom('general');

      expect(generalRoom, isNotNull);

      // Get room members
      final members = await generalRoom!.requestParticipants();

      // Should have multiple test users
      expect(members.length, greaterThanOrEqualTo(2));
    });

    testWidgets('Send and receive message', (WidgetTester tester) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client!.sync();
      final testRoom = findRoom('general');
      expect(testRoom, isNotNull);

      // Send a test message
      final messageText = 'Test message from integration test';
      final eventId = await testRoom!.sendTextEvent(messageText);

      expect(eventId, isNotNull);
      expect(eventId, isNotEmpty);
    });

    testWidgets('Sync with server', (WidgetTester tester) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Perform sync
      await client!.sync();

      // After sync, should have rooms
      expect(client!.rooms, isNotEmpty);
    });

    testWidgets('Create and join room', (WidgetTester tester) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Create a new room
      final roomId = await client!.createRoom(
        preset: CreateRoomPreset.publicChat,
        roomAliasName: 'test_room_${DateTime.now().millisecondsSinceEpoch}',
      );

      expect(roomId, isNotNull);

      // Get the created room
      final room = client!.getRoomById(roomId);
      expect(room, isNotNull);
    });

    testWidgets('Room with different message counts', (
      WidgetTester tester,
    ) async {
      if (client == null) return;
      await client!.checkHomeserver(Uri.parse(effectiveMatrixServer(matrixServer)));
      await client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Robust room discovery with retries
      Room? generalRoom, photosRoom, artRoom;
      for (int i = 0; i < 5; i++) {
        await client!.sync();
        generalRoom = findRoom('general');
        photosRoom = findRoom('photos');
        artRoom = findRoom('art');
        
        if (generalRoom != null && photosRoom != null && artRoom != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      if (generalRoom == null || photosRoom == null || artRoom == null) {
        throw Exception('Test rooms not found. \n'
            'Rooms: ${client!.rooms.map((e) => "${e.id}: '${e.name}' | '${e.getLocalizedName()}' (${e.canonicalAlias})").toList()}');
      }

      // Get timelines for all rooms
      final generalTimeline = await generalRoom.getTimeline();
      final photosTimeline = await photosRoom.getTimeline();
      final artTimeline = await artRoom.getTimeline();

      // Verify message presence
      expect(generalTimeline.events.isNotEmpty, true);
      expect(photosTimeline.events.isNotEmpty, true);
      final artMessages =
          artTimeline.events.where((e) => e.type == 'm.room.message').toList();
      expect(artMessages.isEmpty, true);
    });
  });
}
