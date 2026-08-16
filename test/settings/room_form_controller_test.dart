import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/settings/pages/room_form_controller.dart';
import 'package:substitution/shared/services/substitution_service.dart';

import '../helpers/test_helpers.dart';

class MockSubstitutionService extends Mock implements SubstitutionService {}

class _SyncUpdateFake extends Fake implements SyncUpdate {}

/// Pre-stubs a [MockClient] + [MockRoom] + [MockUser] for tests that
/// need a fully-loaded controller (i.e. the room is non-null so
/// kick/ban/etc. actions have something to operate on). Returns a
/// loaded [RoomFormController] ready to use.
///
/// The stubs are deliberately minimal — each test that needs more
/// (e.g. a specific room.membership return) re-stubs on top.
///
/// [members] is only used to stub `room.getParticipants()` and
/// should be either empty or a list of [MockUser]s with `membership`
/// stubbed. The controller's loadRoom filters by membership, so
/// passing unstubbed Users crashes the loader.
Future<RoomFormController> _makeLoadedController({
  required MockClient client,
  required MockRoom room,
  List<User> members = const [],
}) async {
  when(() => client.userID).thenReturn('@user:server');
  when(() => client.getRoomById('!room:server')).thenReturn(room);
  when(() => room.getState(any())).thenReturn(null);
  when(() => room.avatar).thenReturn(null);
  when(() => room.canonicalAlias).thenReturn('');
  when(() => room.name).thenReturn('Existing Room');
  when(() => room.topic).thenReturn('');
  when(() => room.getParticipants()).thenReturn(members);

  final service = MockSubstitutionService();
  when(() => service.isInitialized).thenReturn(true);
  when(() => service.init()).thenAnswer((_) async {});
  when(() => service.isSubstitutionRoom(any())).thenReturn(true);

  final controller = RoomFormController(client: client, isCreateMode: false);
  await controller.loadRoom(
    roomId: '!room:server',
    substitutionService: service,
  );
  return controller;
}

void main() {
  group('RoomFormController (create mode)', () {
    late MockClient client;
    late RoomFormController controller;

    setUp(() {
      client = MockClient();
      when(() => client.userID).thenReturn('@user:server');
      controller = RoomFormController(client: client, isCreateMode: true);
    });

    test('starts with create-mode defaults', () {
      expect(controller.isCreateMode, isTrue);
      expect(controller.isPublic, isFalse);
      expect(controller.isSubstitutionRoom, isTrue);
      expect(controller.isBlogMode, isFalse);
      expect(controller.isEncrypted, isNull);
      expect(controller.nameController.text, isEmpty);
      expect(controller.aliasController.text, isEmpty);
      expect(controller.topicController.text, isEmpty);
    });

    test('setters trigger notifyListeners', () {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.isPublic = true;
      expect(notifyCount, 1);

      controller.isBlogMode = true;
      expect(notifyCount, 2);

      controller.isSubstitutionRoom = false;
      expect(notifyCount, 3);
    });

    test('setters are no-ops when the value is unchanged', () {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.isPublic = false; // same as default
      controller.isBlogMode = false; // same as default
      expect(notifyCount, 0);
    });

    test('dispose() disposes all text controllers', () {
      // Pre-conditions: controllers are usable.
      controller.nameController.text = 'Test';
      expect(controller.nameController.text, 'Test');

      // After dispose, accessing the controllers throws.
      controller.dispose();
      expect(
        () => controller.nameController.text = 'crash',
        throwsA(isA<Error>()),
      );
    });
  });

  group('RoomFormController (edit mode)', () {
    late MockClient client;
    late MockRoom room;
    late RoomFormController controller;

    setUp(() {
      client = MockClient();
      when(() => client.userID).thenReturn('@user:server');
      room = createMockRoom(
        name: 'Existing Room',
        id: '!room:server',
        powerLevel: 100,
      );
      controller = RoomFormController(client: client, isCreateMode: false);
    });

    test('loadRoom() populates form fields from the room state', () async {
      when(() => client.getRoomById('!room:server')).thenReturn(room);
      when(() => room.getState('m.room.power_levels')).thenReturn(null);
      when(() => room.getState('m.room.join_rules')).thenReturn(null);
      when(() => room.getState('m.room.encryption')).thenReturn(null);
      when(() => room.avatar).thenReturn(null);
      when(() => room.canonicalAlias).thenReturn('#existing:server');
      when(() => room.name).thenReturn('Existing Room');
      when(() => room.topic).thenReturn('A topic');
      when(() => room.getParticipants()).thenReturn([]);

      final service = MockSubstitutionService();
      when(() => service.isInitialized).thenReturn(true);
      when(() => service.init()).thenAnswer((_) async {});
      when(() => service.isSubstitutionRoom(any())).thenReturn(true);

      await controller.loadRoom(
        roomId: '!room:server',
        substitutionService: service,
      );

      expect(controller.isLoadingRoom, isFalse);
      expect(controller.loadError, isNull);
      expect(controller.room, same(room));
      expect(controller.nameController.text, 'Existing Room');
      expect(controller.topicController.text, 'A topic');
      expect(controller.aliasController.text, 'existing');
      expect(controller.members, isEmpty);
      expect(controller.bannedMembers, isEmpty);
      verify(() => service.init()).called(1);
    });

    test(
      'loadRoom() reports a friendly error when the room is missing',
      () async {
        when(() => client.getRoomById('!missing:server')).thenReturn(null);

        await controller.loadRoom(
          roomId: '!missing:server',
          substitutionService: MockSubstitutionService(),
        );

        expect(controller.isLoadingRoom, isFalse);
        expect(controller.loadError, isNotNull);
        expect(controller.room, isNull);
      },
    );

    test(
      'loadRoom() tolerates a null SubstitutionService (test env)',
      () async {
        when(() => client.getRoomById('!room:server')).thenReturn(room);
        when(() => room.getState('m.room.power_levels')).thenReturn(null);
        when(() => room.getState('m.room.join_rules')).thenReturn(null);
        when(() => room.getState('m.room.encryption')).thenReturn(null);
        when(() => room.avatar).thenReturn(null);
        when(() => room.canonicalAlias).thenReturn('');
        when(() => room.name).thenReturn('Existing Room');
        when(() => room.topic).thenReturn('');
        when(() => room.getParticipants()).thenReturn([]);

        // No service — controller should still load and fall back to
        // the create-mode default for the substitution toggle.
        await controller.loadRoom(
          roomId: '!room:server',
          substitutionService: null,
        );

        expect(controller.room, same(room));
        expect(controller.isSubstitutionRoom, isTrue); // default
      },
    );
  });

  group('RoomFormController submit (create mode)', () {
    late MockClient client;
    late MockRoom createdRoom;
    late RoomFormController controller;

    setUp(() {
      client = MockClient();
      when(() => client.userID).thenReturn('@user:server');
      createdRoom = createMockRoom(
        name: 'New Room',
        id: '!new:server',
        powerLevel: 100,
      );
      controller = RoomFormController(client: client, isCreateMode: true);
      controller.nameController.text = 'New Room';
      controller.topicController.text = 'A topic';
    });

    test('submit() calls client.createRoom with the right params', () async {
      when(
        () => client.createRoom(
          isDirect: any(named: 'isDirect'),
          name: any(named: 'name'),
          topic: any(named: 'topic'),
          roomAliasName: any(named: 'roomAliasName'),
          visibility: any(named: 'visibility'),
          preset: any(named: 'preset'),
          invite: any(named: 'invite'),
          initialState: any(named: 'initialState'),
        ),
      ).thenAnswer((_) async => '!new:server');
      when(() => client.getRoomById('!new:server')).thenReturn(createdRoom);
      when(() => createdRoom.membership).thenReturn(Membership.join);
      when(
        () => client.waitForRoomInSync(any(), join: any(named: 'join')),
      ).thenAnswer((_) async => _SyncUpdateFake());
      when(
        () => client.setAccountDataPerRoom(any(), any(), any(), any()),
      ).thenAnswer((_) async => {});

      final service = MockSubstitutionService();
      when(() => service.isInitialized).thenReturn(true);
      when(() => service.init()).thenAnswer((_) async {});
      when(() => service.isSubstitutionRoom(any())).thenReturn(true);
      when(() => service.addRoomId(any())).thenReturn(null);
      when(() => service.triggerRefresh()).thenReturn(null);

      final ok = await controller.submit(substitutionService: service);

      expect(ok, isTrue);
      expect(controller.isSaving, isFalse);
      verify(
        () => client.createRoom(
          isDirect: false,
          name: 'New Room',
          topic: 'A topic',
          roomAliasName: null,
          visibility: any(named: 'visibility'),
          preset: any(named: 'preset'),
          invite: any(named: 'invite'),
          initialState: any(named: 'initialState'),
        ),
      ).called(1);
      verify(() => service.addRoomId('!new:server')).called(1);
      verify(() => service.triggerRefresh()).called(1);
    });

    test('submit() returns false and exposes lastError on failure', () async {
      when(
        () => client.createRoom(
          isDirect: any(named: 'isDirect'),
          name: any(named: 'name'),
          topic: any(named: 'topic'),
          roomAliasName: any(named: 'roomAliasName'),
          visibility: any(named: 'visibility'),
          preset: any(named: 'preset'),
          invite: any(named: 'invite'),
          initialState: any(named: 'initialState'),
        ),
      ).thenThrow(Exception('boom'));

      final ok = await controller.submit(
        substitutionService: MockSubstitutionService(),
      );

      expect(ok, isFalse);
      expect(controller.isSaving, isFalse);
      expect(controller.lastError, contains('boom'));
    });
  });

  group('RoomFormController member actions', () {
    late MockClient client;
    late MockRoom room;
    late MockUser member;
    late RoomFormController controller;

    setUp(() async {
      client = MockClient();
      room = createMockRoom(
        name: 'Existing Room',
        id: '!room:server',
        powerLevel: 100,
      );
      member = MockUser();
      when(() => member.id).thenReturn('@user:server');
      // Default to an empty participant list; individual tests re-stub.
      controller = await _makeLoadedController(
        client: client,
        room: room,
        members: const [],
      );
      // After loadRoom, the controller's internal members list reflects
      // what room.getParticipants() returned. For tests that need a
      // member to be present, re-stub getParticipants() *and* reset
      // the internal list before calling the action.
    });

    test(
      'kickMember() calls room.kick and refreshes the member list',
      () async {
        // Set up the room to have one member, then verify kick + refresh.
        when(() => room.getParticipants()).thenReturn([member]);
        // Trigger a refresh by calling loadRoom again so _members has
        // the right initial value.
        final service = MockSubstitutionService();
        when(() => service.isInitialized).thenReturn(true);
        when(() => service.init()).thenAnswer((_) async {});
        when(() => service.isSubstitutionRoom(any())).thenReturn(true);
        await controller.loadRoom(
          roomId: '!room:server',
          substitutionService: service,
        );
        // Now stub kick to succeed and post-kick list to be empty.
        when(() => room.kick('@user:server')).thenAnswer((_) async {});
        when(() => room.getParticipants()).thenReturn([]);

        final ok = await controller.kickMember(member);

        expect(ok, isTrue);
        verify(() => room.kick('@user:server')).called(1);
        expect(controller.members, isEmpty);
      },
    );

    test('banMember() calls room.ban and refreshes the member list', () async {
      when(() => room.ban('@user:server')).thenAnswer((_) async {});
      when(() => room.getParticipants()).thenReturn([]);

      final ok = await controller.banMember(member);

      expect(ok, isTrue);
      verify(() => room.ban('@user:server')).called(1);
      expect(controller.members, isEmpty);
    });

    test(
      'unbanMember() calls room.unban and refreshes the member list',
      () async {
        when(() => room.unban('@user:server')).thenAnswer((_) async {});
        when(() => room.getParticipants()).thenReturn([]);

        final ok = await controller.unbanMember(member);

        expect(ok, isTrue);
        verify(() => room.unban('@user:server')).called(1);
      },
    );

    test('setPowerLevel() calls room.setPower with the right level', () async {
      when(() => room.setPower(any(), any())).thenAnswer((_) async => '');
      when(() => room.getParticipants()).thenReturn([]);

      final ok = await controller.setPowerLevel(member, 50);

      expect(ok, isTrue);
      verify(() => room.setPower('@user:server', 50)).called(1);
    });

    test('actions return false and surface lastError on failure', () async {
      when(() => room.kick(any())).thenThrow(Exception('forbidden'));

      final ok = await controller.kickMember(member);

      expect(ok, isFalse);
      expect(controller.lastError, contains('forbidden'));
    });
  });

  group('RoomFormController deleteRoom', () {
    late MockClient client;
    late MockRoom room;
    late RoomFormController controller;

    setUp(() async {
      client = MockClient();
      room = createMockRoom(
        name: 'Existing Room',
        id: '!room:server',
        powerLevel: 100,
      );
      controller = await _makeLoadedController(client: client, room: room);
    });

    test('calls room.leave and returns true on success', () async {
      when(() => room.leave()).thenAnswer((_) async {});

      final ok = await controller.deleteRoom();

      expect(ok, isTrue);
      verify(() => room.leave()).called(1);
    });
  });
}
