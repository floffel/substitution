import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/shared/models/substitution_room.dart';

void main() {
  group('SubstitutionRoom', () {
    test('stores all required fields', () {
      const room = SubstitutionRoom(
        id: '!room:matrix.org',
        name: 'Test Room',
        isInsideSubstitution: true,
        joined: true,
      );

      expect(room.id, '!room:matrix.org');
      expect(room.name, 'Test Room');
      expect(room.isInsideSubstitution, true);
      expect(room.joined, true);
    });

    test('optional fields default to null', () {
      const room = SubstitutionRoom(
        id: '!r:s',
        name: 'r',
        isInsideSubstitution: false,
        joined: false,
      );

      expect(room.avatarUrl, isNull);
      expect(room.topic, isNull);
      expect(room.numJoinedMembers, isNull);
    });

    test('worldReadable defaults to false', () {
      const room = SubstitutionRoom(
        id: '!r:s',
        name: 'r',
        isInsideSubstitution: true,
        joined: true,
      );

      expect(room.worldReadable, isFalse);
    });

    test('worldReadable can be set to true', () {
      const room = SubstitutionRoom(
        id: '!r:s',
        name: 'r',
        isInsideSubstitution: true,
        joined: true,
        worldReadable: true,
      );

      expect(room.worldReadable, isTrue);
    });

    test('optional fields are preserved when provided', () {
      const room = SubstitutionRoom(
        id: '!r:s',
        name: 'Photo Art',
        avatarUrl: 'mxc://matrix.org/abc',
        isInsideSubstitution: true,
        joined: true,
        topic: 'A room for sharing art',
        numJoinedMembers: 42,
        worldReadable: true,
      );

      expect(room.avatarUrl, 'mxc://matrix.org/abc');
      expect(room.topic, 'A room for sharing art');
      expect(room.numJoinedMembers, 42);
      expect(room.worldReadable, true);
    });

    test('a non-substitution room can be marked joined=false', () {
      const room = SubstitutionRoom(
        id: '!r:s',
        name: 'Other Room',
        isInsideSubstitution: false,
        joined: false,
      );

      expect(room.isInsideSubstitution, isFalse);
      expect(room.joined, isFalse);
    });
  });
}
