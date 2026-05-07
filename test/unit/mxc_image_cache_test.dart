import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/shared/widgets/mxc_image.dart';

void main() {
  group('MxcImage cache helpers', () {
    setUp(() {
      MxcImage.debugClearCaches();
    });

    test('memory cache read reorders key as most-recently-used', () {
      MxcImage.debugPutInMemoryCache('a', Uint8List.fromList([1]));
      MxcImage.debugPutInMemoryCache('b', Uint8List.fromList([2]));

      expect(MxcImage.debugGetFromMemoryCache('a'), isNotNull);

      MxcImage.debugPutInMemoryCache('c', Uint8List.fromList([3]));

      expect(MxcImage.debugGetFromMemoryCache('b'), isNotNull);
      expect(MxcImage.debugGetFromMemoryCache('a'), isNotNull);
      expect(MxcImage.debugMemoryEntryCount(), equals(3));
    });

    test('in-flight dedupe runs loader only once', () async {
      var runs = 0;

      Future<Uint8List> loader() async {
        runs++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return Uint8List.fromList([4, 5, 6]);
      }

      final future1 = MxcImage.debugRunCoalesced('same-key', loader);
      final future2 = MxcImage.debugRunCoalesced('same-key', loader);

      final result = await Future.wait([future1, future2]);

      expect(runs, equals(1));
      expect(result.first, equals(result.last));
    });
  });
}
