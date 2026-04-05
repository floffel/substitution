import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/shared/services/matrix_server_capabilities.dart';

void main() {
  group('MatrixServerCapabilities.compareVersions', () {
    test('compares modern v-prefixed versions', () {
      expect(
        MatrixServerCapabilities.compareVersions('v1.6', 'v1.5') > 0,
        isTrue,
      );
      expect(
        MatrixServerCapabilities.compareVersions('v1.5', 'v1.6') < 0,
        isTrue,
      );
      expect(
        MatrixServerCapabilities.compareVersions('v1.11', 'v1.6') > 0,
        isTrue,
      );
      expect(MatrixServerCapabilities.compareVersions('v1.6', 'v1.6'), 0);
    });

    test('compares legacy r-prefixed versions', () {
      expect(
        MatrixServerCapabilities.compareVersions('r0.6.0', 'r0.5.0') > 0,
        isTrue,
      );
    });

    test('v1.6 is greater than r0.5.0', () {
      expect(
        MatrixServerCapabilities.compareVersions('v1.6', 'r0.5.0') > 0,
        isTrue,
      );
    });

    test('invalid versions sort as oldest', () {
      expect(
        MatrixServerCapabilities.compareVersions('garbage', 'v1.0') < 0,
        isTrue,
      );
    });
  });

  group('MatrixServerCapabilities.homeserverOfId', () {
    test('extracts host from user ID', () {
      expect(
        MatrixServerCapabilities.homeserverOfId('@alice:matrix.org'),
        'matrix.org',
      );
    });

    test('extracts host from room ID', () {
      expect(
        MatrixServerCapabilities.homeserverOfId('!abc:example.com'),
        'example.com',
      );
    });

    test('returns null for malformed IDs', () {
      expect(MatrixServerCapabilities.homeserverOfId('no-colon'), isNull);
      expect(MatrixServerCapabilities.homeserverOfId('@user:'), isNull);
    });
  });
}
