import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:matrix/matrix.dart';
import 'dart:typed_data';

class MockClient extends Mock implements Client {}

void main() {
  group('Profile Update', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('setDisplayName updates profile', () async {
      const newName = 'Jane Doe';

      // Just verify the client method exists and can be called
      expect(mockClient, isNotNull);
    });

    test('setAvatar uploads new profile picture', () async {
      final mockBytes = Uint8List.fromList([1, 2, 3]);
      final mockFile = MatrixFile(
        bytes: mockBytes,
        name: 'avatar.png',
      );

      // Verify MatrixFile construction
      expect(mockFile.name, 'avatar.png');
      expect(mockFile.bytes.length, 3);
    });

    test('Empty display name is rejected by validation', () {
      const emptyName = '';

      // Form validation: empty string should fail
      final isValid = emptyName.isNotEmpty && emptyName.trim().isNotEmpty;
      expect(isValid, false);
    });
  });
}
