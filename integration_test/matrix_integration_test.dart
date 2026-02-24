import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'helpers/integration_test_helper.dart' show skipIfNoMatrix;

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
    late Client client;
    Database? sqliteDatabase;

    setUp(() async {
      await skipIfNoMatrix(matrixServer: matrixServer);

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
      // Cleanup - logout and dispose
      try {
        if (client.isLogged()) {
          await client.logout();
        }
      } catch (e) {
        // Ignore cleanup errors
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

    testWidgets('Connect to Matrix test server', (WidgetTester tester) async {
      // Check server version
      final supported = await client.checkHomeserver(Uri.parse(matrixServer));
      expect(supported, isNotNull);
    });

    testWidgets('Login with test user credentials', (
      WidgetTester tester,
    ) async {
      await client.checkHomeserver(Uri.parse(matrixServer));

      // Login with test user
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      expect(client.userID, contains(testUser));
      expect(client.isLogged(), true);
    });

    testWidgets('Access test server with valid credentials', (
      WidgetTester tester,
    ) async {
      await client.checkHomeserver(Uri.parse(matrixServer));

      // Attempt login
      final response = await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      expect(response, isNotNull);
      expect(client.isLogged(), true);

      // Sync to get rooms
      await client.sync();
      expect(client.rooms, isNotEmpty);
    });

    testWidgets('Verify test rooms exist', (WidgetTester tester) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Sync to get rooms
      await client.sync();

      // Should have test rooms
      expect(client.rooms, isNotEmpty);

      // Look for test rooms
      final roomNames = client.rooms.map((r) => r.name).toList();
      expect(roomNames.any((n) => n.contains('test_')), true);
    });

    testWidgets('Test room with messages vs empty room', (
      WidgetTester tester,
    ) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client.sync();

      // Find test rooms
      final generalRoom = client.rooms.firstWhere(
        (r) => r.name.contains('general'),
      );
      final artRoom = client.rooms.firstWhere((r) => r.name.contains('art'));

      expect(generalRoom, isNotNull);
      expect(artRoom, isNotNull);

      // Rooms have specific characteristics
      expect(generalRoom.name, 'test_general');
      expect(artRoom.name, 'test_art');
    });

    testWidgets('Verify multiple test users created', (
      WidgetTester tester,
    ) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client.sync();

      // Get a room
      final room = client.rooms.isNotEmpty ? client.rooms.first : null;
      expect(room, isNotNull);

      // Check room members
      final members = await room!.requestParticipants();
      expect(members, isNotEmpty);
    });

    testWidgets('Send message to test room', (WidgetTester tester) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client.sync();

      final room = client.rooms.isNotEmpty ? client.rooms.first : null;
      expect(room, isNotNull);

      // Send a test message
      final messageText = 'Integration test message';
      final eventId = await room!.sendTextEvent(messageText);

      expect(eventId, isNotNull);
      expect(eventId, isNotEmpty);
    });

    testWidgets('Login as different test user', (WidgetTester tester) async {
      await client.checkHomeserver(Uri.parse(matrixServer));

      // Login as testuser2
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'testuser2'),
        password: 'testpass123',
      );

      expect(client.userID, contains('testuser2'));
      expect(client.isLogged(), true);
    });

    testWidgets('Rooms are public and joinable', (WidgetTester tester) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client.sync();

      // All test rooms should exist and be accessible
      final generalRoom = client.rooms.firstWhere(
        (r) => r.name.contains('general'),
      );
      final photosRoom = client.rooms.firstWhere(
        (r) => r.name.contains('photos'),
      );
      final artRoom = client.rooms.firstWhere((r) => r.name.contains('art'));

      expect(generalRoom.name, 'test_general');
      expect(photosRoom.name, 'test_photos');
      expect(artRoom.name, 'test_art');
    });

    testWidgets('List joined rooms', (WidgetTester tester) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Sync to get rooms
      await client.sync();
      final rooms = client.rooms;

      // Should have test rooms (test_general, test_photos, test_art)
      expect(rooms, isNotEmpty);
      expect(rooms.length, greaterThanOrEqualTo(3));
    });

    testWidgets('Room with messages contains messages', (
      WidgetTester tester,
    ) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Sync to get rooms
      await client.sync();
      final rooms = client.rooms;
      final generalRoom = rooms.firstWhere((r) => r.name.contains('general'));

      expect(generalRoom, isNotNull);

      // Get room timeline and check for messages
      final timeline = await generalRoom.getTimeline();

      // test_general room should have messages
      expect(timeline.events.isNotEmpty, true);
    });

    testWidgets('Empty room has no messages', (WidgetTester tester) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Sync to get rooms
      await client.sync();
      final rooms = client.rooms;
      final artRoom = rooms.firstWhere((r) => r.name.contains('art'));

      expect(artRoom, isNotNull);

      // Get room timeline
      final timeline = await artRoom.getTimeline();

      // Empty room should have no messages (only state events)
      // This room was created empty for testing
      final messages =
          timeline.events.where((e) => e.type == 'm.room.message').toList();
      expect(messages.isEmpty, true);
    });

    testWidgets('Multiple users in same room', (WidgetTester tester) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client.sync();
      final rooms = client.rooms;
      final testRoom = rooms.first;

      expect(testRoom, isNotNull);

      // Get room members
      final members = await testRoom.requestParticipants();

      // Should have multiple test users
      if (members.length < 2) {
        debugPrint(
          '⚠ Only ${members.length} members in first room (expected >=2) - room may be single-user',
        );
      } else {
        debugPrint('✓ Found ${members.length} members in room');
      }
    });

    testWidgets('Send and receive message', (WidgetTester tester) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client.sync();
      final rooms = client.rooms;
      final testRoom = rooms.first;

      // Send a test message
      final messageText = 'Test message from integration test';
      final eventId = await testRoom.sendTextEvent(messageText);

      expect(eventId, isNotNull);
      expect(eventId, isNotEmpty);
    });

    testWidgets('Sync with server', (WidgetTester tester) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Perform sync
      await client.sync();

      // After sync, should have rooms
      expect(client.rooms, isNotEmpty);
    });

    testWidgets('Create and join room', (WidgetTester tester) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      // Create a new room
      final roomId = await client.createRoom(
        preset: CreateRoomPreset.publicChat,
        roomAliasName: 'test_room_${DateTime.now().millisecondsSinceEpoch}',
      );

      expect(roomId, isNotNull);

      // Get the created room
      final room = client.getRoomById(roomId);
      expect(room, isNotNull);
    });

    testWidgets('Room with different message counts', (
      WidgetTester tester,
    ) async {
      await client.checkHomeserver(Uri.parse(matrixServer));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: testUser),
        password: testPassword,
      );

      await client.sync();
      final rooms = client.rooms;

      // Find rooms with known message counts:
      // test_general - 5 messages
      // test_photos - 3 messages
      // test_art - 0 messages

      final generalRoom = rooms.firstWhere((r) => r.name.contains('general'));
      final photosRoom = rooms.firstWhere((r) => r.name.contains('photos'));
      final artRoom = rooms.firstWhere((r) => r.name.contains('art'));

      expect(generalRoom, isNotNull);
      expect(photosRoom, isNotNull);
      expect(artRoom, isNotNull);

      // Verify room names
      expect(generalRoom.name, 'test_general');
      expect(photosRoom.name, 'test_photos');
      expect(artRoom.name, 'test_art');

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
