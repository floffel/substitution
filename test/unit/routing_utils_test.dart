import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/shared/utils/routing_utils.dart';

void main() {
  group('preserveDestinationInIntroRedirect', () {
    test('returns null when already on /intro (no redirect needed)', () {
      expect(
        preserveDestinationInIntroRedirect(Uri.parse('/intro')),
        isNull,
      );
    });

    test('returns null when already on /auth/login', () {
      expect(
        preserveDestinationInIntroRedirect(Uri.parse('/auth/login')),
        isNull,
      );
    });

    test('returns null when already on /auth/host', () {
      expect(
        preserveDestinationInIntroRedirect(Uri.parse('/auth/host')),
        isNull,
      );
    });

    test('returns null when already on /age-gate', () {
      expect(
        preserveDestinationInIntroRedirect(Uri.parse('/age-gate')),
        isNull,
      );
    });

    test('returns null when already on /login-callback', () {
      expect(
        preserveDestinationInIntroRedirect(Uri.parse('/login-callback')),
        isNull,
      );
    });

    test('returns null when goto is already present (no nesting)', () {
      // If we already have a goto, the caller is responsible for it.
      // Adding another would be a redirect loop.
      expect(
        preserveDestinationInIntroRedirect(
          Uri.parse('/feed/photo_art:matrix.org?goto=/something'),
        ),
        isNull,
      );
    });

    test('preserves a simple path as goto', () {
      expect(
        preserveDestinationInIntroRedirect(Uri.parse('/feed/photo_art:matrix.org')),
        '/intro?goto=${Uri.encodeComponent('/feed/photo_art:matrix.org')}',
      );
    });

    test('preserves a path with a query string as goto', () {
      expect(
        preserveDestinationInIntroRedirect(
          Uri.parse('/room/!abc:server/\$event-id'),
        ),
        '/intro?goto=${Uri.encodeComponent('/room/!abc:server/\$event-id')}',
      );
    });

    test('preserves a profile deep link as goto', () {
      expect(
        preserveDestinationInIntroRedirect(
          Uri.parse('/profile/@alice:matrix.org'),
        ),
        '/intro?goto=${Uri.encodeComponent('/profile/@alice:matrix.org')}',
      );
    });

    test('preserves a chat deep link as goto', () {
      expect(
        preserveDestinationInIntroRedirect(
          Uri.parse('/chat/!room:server'),
        ),
        '/intro?goto=${Uri.encodeComponent('/chat/!room:server')}',
      );
    });

    test('preserves a settings deep link as goto', () {
      expect(
        preserveDestinationInIntroRedirect(
          Uri.parse('/settings/security'),
        ),
        '/intro?goto=${Uri.encodeComponent('/settings/security')}',
      );
    });

    test('encoded goto decodes back to the original path', () {
      // The result must round-trip: decoding the encoded goto gives back
      // the original request URI.
      final original = '/feed/photo_art:matrix.org';
      final redirect =
          preserveDestinationInIntroRedirect(Uri.parse(original));
      expect(redirect, isNotNull);

      // Parse the redirect and extract the goto parameter.
      final redirectUri = Uri.parse(redirect!);
      final encodedGoto = redirectUri.queryParameters['goto'];
      expect(encodedGoto, isNotNull);

      // Decoding must recover the original path exactly.
      final decoded = Uri.decodeComponent(encodedGoto!);
      expect(decoded, original);
    });

    test('encoded goto preserves query parameters of the original', () {
      // If the original was /write/foo?event=bar, the goto must include
      // the event=bar query so the post-edit page works.
      final original = '/write/!room:server?event=\$event-id';
      final redirect =
          preserveDestinationInIntroRedirect(Uri.parse(original));
      expect(redirect, isNotNull);

      final redirectUri = Uri.parse(redirect!);
      final decodedGoto =
          Uri.decodeComponent(redirectUri.queryParameters['goto']!);
      expect(decodedGoto, original);
    });
  });

  group('safeGotoDestination', () {
    test('returns null for null', () {
      expect(safeGotoDestination(null), isNull);
    });

    test('returns null for empty string', () {
      expect(safeGotoDestination(''), isNull);
    });

    test('accepts a simple internal path', () {
      expect(safeGotoDestination('/feed/photo_art:matrix.org'),
          '/feed/photo_art:matrix.org');
    });

    test('accepts a path with query parameters', () {
      expect(
        safeGotoDestination('/write/!room:server?event=\$event-id'),
        '/write/!room:server?event=\$event-id',
      );
    });

    test('accepts a path with a fragment', () {
      expect(safeGotoDestination('/feed/foo#section'), '/feed/foo#section');
    });

    test('rejects an external http URL', () {
      expect(safeGotoDestination('https://example.com/feed'), isNull);
    });

    test('rejects an external http URL without protocol casing tricks', () {
      expect(safeGotoDestination('HTTP://example.com'), isNull);
    });

    test('rejects a javascript: URL', () {
      expect(safeGotoDestination('javascript:alert(1)'), isNull);
    });

    test('rejects a file: URL', () {
      expect(safeGotoDestination('file:///etc/passwd'), isNull);
    });

    test('rejects a data: URL', () {
      expect(safeGotoDestination('data:text/html,<script>alert(1)</script>'),
          isNull);
    });

    test('rejects a protocol-relative URL (//example.com)', () {
      // Browsers interpret "//example.com" as a cross-origin URL.
      // We must reject it to prevent open-redirect attacks.
      expect(safeGotoDestination('//example.com/feed'), isNull);
    });

    test('rejects a triple-slash URL', () {
      expect(safeGotoDestination('///example.com'), isNull);
    });

    test('rejects /intro (would create a redirect loop)', () {
      expect(safeGotoDestination('/intro'), isNull);
    });

    test('rejects /intro with query (also a loop)', () {
      expect(safeGotoDestination('/intro?goto=/foo'), isNull);
    });

    test('rejects /auth/login', () {
      expect(safeGotoDestination('/auth/login'), isNull);
    });

    test('rejects /auth/host', () {
      expect(safeGotoDestination('/auth/host'), isNull);
    });

    test('rejects /age-gate', () {
      expect(safeGotoDestination('/age-gate'), isNull);
    });

    test('rejects /login-callback', () {
      expect(safeGotoDestination('/login-callback'), isNull);
    });

    test('rejects /feed/intro (path that contains "intro" as a segment)', () {
      // The check is on the first path segment, not substring.
      // /feed/intro is a valid room path; only /intro itself is rejected.
      expect(safeGotoDestination('/feed/intro'), '/feed/intro');
    });

    test('accepts /auth/login-foo (path that starts with /auth/ but is not the exact page)', () {
      // We only block the exact auth paths, not arbitrary paths that
      // happen to start with /auth/.
      expect(safeGotoDestination('/auth/login-foo'), '/auth/login-foo');
    });

    test('trims query string before checking auth path', () {
      // The check extracts the path part before the query.
      expect(safeGotoDestination('/auth/login?something'), isNull);
      expect(safeGotoDestination('/auth/login#frag'), isNull);
    });

    test('rejects a relative path that does not start with /', () {
      expect(safeGotoDestination('feed/foo'), isNull);
      expect(safeGotoDestination('./feed'), isNull);
      expect(safeGotoDestination('../feed'), isNull);
    });
  });
}
