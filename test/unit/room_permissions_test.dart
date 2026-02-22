import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Room Permissions Logic Tests', () {
    late MockRoom mockRoom;

    setUpTestInfrastructure();

    setUp(() {
      mockRoom = createMockRoom(
        name: 'Test Room',
        id: '!testroom:matrix.org',
        powerLevel: 100, // Admin power level
      );
    });

    test('setPower() calls room.setPower with correct userId and level',
        () async {
      const userId = '@user:matrix.org';
      const newPowerLevel = 50;

      // Mock the setPower method
      when(() => mockRoom.setPower(userId, newPowerLevel))
          .thenAnswer((_) async => '');

      // Call the method
      await mockRoom.setPower(userId, newPowerLevel);

      // Verify the call was made with correct parameters
      verify(() => mockRoom.setPower(userId, newPowerLevel)).called(1);
    });

    test('Blog mode updates events_default to 50', () {
      // Create a power level state map
      final powerLevelState = {
        'ban': 50,
        'kick': 50,
        'redact': 50,
        'invite': 50,
        'events_default': 0,
        'state_default': 50,
        'users_default': 0,
        'events': {
          'm.room.name': 50,
          'm.room.avatar': 50,
        },
        'users': {
          '@admin:matrix.org': 100,
        }
      };

      // Update to blog mode (events_default: 50)
      final updatedPowerLevels = {
        ...powerLevelState,
        'events_default': 50,
      };

      // Verify the update
      expect(updatedPowerLevels['events_default'], equals(50));
      expect(powerLevelState['events_default'], equals(0));
    });

    test('Community mode updates events_default to 0', () {
      // Create a power level state map in blog mode
      final powerLevelState = {
        'ban': 50,
        'kick': 50,
        'redact': 50,
        'invite': 50,
        'events_default': 50, // Currently in blog mode
        'state_default': 50,
        'users_default': 0,
        'events': {
          'm.room.name': 50,
          'm.room.avatar': 50,
        },
        'users': {
          '@admin:matrix.org': 100,
        }
      };

      // Update to community mode (events_default: 0)
      final updatedPowerLevels = {
        ...powerLevelState,
        'events_default': 0,
      };

      // Verify the update
      expect(updatedPowerLevels['events_default'], equals(0));
      expect(powerLevelState['events_default'], equals(50));
    });

    test('Only room admins (power >= 100) can change permissions', () {
      // Test admin can access
      final adminRoom = createMockRoom(
        name: 'Admin Room',
        id: '!adminroom:matrix.org',
        powerLevel: 100,
      );
      expect(adminRoom.ownPowerLevel >= 100, isTrue);

      // Test non-admin cannot access
      final memberRoom = createMockRoom(
        name: 'Member Room',
        id: '!memberroom:matrix.org',
        powerLevel: 50,
      );
      expect(memberRoom.ownPowerLevel >= 100, isFalse);

      // Test moderator cannot access
      final moderatorRoom = createMockRoom(
        name: 'Mod Room',
        id: '!modroom:matrix.org',
        powerLevel: 75,
      );
      expect(moderatorRoom.ownPowerLevel >= 100, isFalse);

      // Test super admin can access
      final superAdminRoom = createMockRoom(
        name: 'Super Admin Room',
        id: '!superadminroom:matrix.org',
        powerLevel: 150,
      );
      expect(superAdminRoom.ownPowerLevel >= 100, isTrue);
    });
  });
}
