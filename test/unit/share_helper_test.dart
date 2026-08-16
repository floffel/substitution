import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/shared/constants.dart';
import 'package:substitution/shared/utils/share_helper.dart';

void main() {
  group('ShareHelper URL generation', () {
    group('roomUrl', () {
      test('strips the leading "#" from an alias', () {
        expect(
          ShareHelper.roomUrl('#photo_art:matrix.org'),
          '${AppConstants.webBaseUrl}/feed/photo_art:matrix.org',
        );
      });

      test('passes a Matrix room ID through unchanged', () {
        expect(
          ShareHelper.roomUrl('!abc123:matrix.org'),
          '${AppConstants.webBaseUrl}/feed/!abc123:matrix.org',
        );
      });

      test('does not double-strip a single leading "#"', () {
        final url = ShareHelper.roomUrl('#foo:bar');
        expect(url, isNot(contains('/feed/#foo')));
        expect(url, '${AppConstants.webBaseUrl}/feed/foo:bar');
      });

      test('uses the web base URL constant', () {
        final url = ShareHelper.roomUrl('#x:y');
        expect(url.startsWith(AppConstants.webBaseUrl), isTrue);
      });
    });

    group('profileUrl', () {
      test('percent-encodes the @ and : in a Matrix userId', () {
        // Uri.encodeComponent encodes "@" → %40 and ":" → %3A.
        // This documents (and locks in) the actual current behavior, even
        // though those characters are not strictly required to be encoded
        // in a path segment.
        final url = ShareHelper.profileUrl('@alice:matrix.org');
        expect(url, '${AppConstants.webBaseUrl}/profile/%40alice%3Amatrix.org');
      });

      test('encodes spaces and special characters', () {
        final url = ShareHelper.profileUrl('@weird user@host:server');
        // The component is fully encoded — no raw spaces, "@", or unencoded
        // ":" in the userId segment of the URL.
        expect(
          url,
          '${AppConstants.webBaseUrl}/profile/${Uri.encodeComponent('@weird user@host:server')}',
        );
        // Verify the raw characters do not appear in the userId segment.
        final userIdSegment = url.split('/profile/').last;
        expect(userIdSegment.contains(' '), isFalse);
        expect(userIdSegment.contains('@'), isFalse);
        expect(userIdSegment.contains(':'), isFalse);
      });
    });

    group('postUrl', () {
      test('builds a room-scoped post URL', () {
        expect(
          ShareHelper.postUrl('\$event-id', '!room:matrix.org'),
          '${AppConstants.webBaseUrl}/room/${Uri.encodeComponent('!room:matrix.org')}/\$event-id',
        );
      });

      test('encodes a roomId containing a colon', () {
        final url = ShareHelper.postUrl('\$e1', '!room:server.example');
        // The literal ":" must be percent-encoded in the path.
        expect(url, contains(Uri.encodeComponent('!room:server.example')));
        // No raw ":" in the encoded roomId segment.
        expect(url, contains('!room%3Aserver.example'));
      });
    });
  });
}
