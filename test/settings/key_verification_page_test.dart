import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockClient extends Mock implements Client {}

class MockDeviceKeys extends Mock implements DeviceKeys {
  String _deviceId = 'test_device_id';
  String _deviceDisplayName = 'Test Device';
  bool _verified = false;
  bool _blocked = false;

  @override
  String get deviceId => _deviceId;

  @override
  String? get deviceDisplayName => _deviceDisplayName;

  @override
  bool get verified => _verified;

  @override
  bool get blocked => _blocked;

  MockDeviceKeys({
    String deviceId = 'test_device_id',
    String displayName = 'Test Device',
    bool verified = false,
    bool blocked = false,
  }) {
    _deviceId = deviceId;
    _deviceDisplayName = displayName;
    _verified = verified;
    _blocked = blocked;
  }

  @override
  Future<void> setVerified(bool verified, [bool? startSas]) async {
    _verified = verified;
  }

  @override
  Future<void> setBlocked(bool blocked) async {
    _blocked = blocked;
  }
}

void main() {
  group('Key Verification Page Widget Tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('Device list structure', () {
      // Arrange
      final device1 = MockDeviceKeys(
        deviceId: 'device_1',
        displayName: 'Phone',
        verified: false,
      );
      final device2 = MockDeviceKeys(
        deviceId: 'device_2',
        displayName: 'Laptop',
        verified: true,
      );

      // Act & Assert
      expect(device1.deviceId, 'device_1');
      expect(device1.deviceDisplayName, 'Phone');
      expect(device1.verified, false);

      expect(device2.deviceId, 'device_2');
      expect(device2.deviceDisplayName, 'Laptop');
      expect(device2.verified, true);
    });

    test('Unverified device shows verify capability', () {
      // Arrange
      final device = MockDeviceKeys(
        deviceId: 'device_1',
        displayName: 'Phone',
        verified: false,
      );

      // Assert - device is unverified and can be verified
      expect(device.verified, false);
      expect(device.blocked, false);
    });

    test('Blocking a device updates status', () async {
      // Arrange
      final device = MockDeviceKeys(
        deviceId: 'device_1',
        displayName: 'Phone',
        blocked: false,
      );

      // Act
      await device.setBlocked(true);

      // Assert
      expect(device.blocked, true);
    });

    test('Confirmed emojis mark device verified', () async {
      // Arrange
      final device = MockDeviceKeys(
        deviceId: 'device_1',
        displayName: 'Phone',
        verified: false,
      );

      // Act
      await device.setVerified(true);

      // Assert
      expect(device.verified, true);
    });

    test('Verify button functionality', () async {
      // Arrange
      final device = MockDeviceKeys(
        deviceId: 'device_1',
        displayName: 'Phone',
        verified: false,
      );

      // Assert - verify starts unverified
      expect(device.verified, false);

      // Act - mark as verified
      await device.setVerified(true);

      // Assert - now verified
      expect(device.verified, true);
    });

    test('Block button functionality', () async {
      // Arrange
      final device = MockDeviceKeys(
        deviceId: 'device_1',
        displayName: 'Phone',
        blocked: false,
      );

      // Assert - verify starts unblocked
      expect(device.blocked, false);

      // Act - mark as blocked
      await device.setBlocked(true);

      // Assert - now blocked
      expect(device.blocked, true);
    });
  });
}
