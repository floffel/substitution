import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/feed/services/feed_candidate.dart';
import 'package:substitution/feed/services/feed_state_cache.dart';

class MockEvent extends Mock implements Event {}

class MockTimeline extends Mock implements Timeline {}

void main() {
  group('FeedStateCache', () {
    late FeedStateCache cache;

    setUp(() {
      cache = FeedStateCache();
    });

    test('hasCache is false when cachedItems is null', () {
      expect(cache.hasCache, isFalse);
    });

    test('hasCache is false when cachedItems is empty', () {
      cache.cachedItems = [];
      expect(cache.hasCache, isFalse);
    });

    test('hasCache is true when cachedItems has entries', () {
      final e = MockEvent();
      cache.cachedItems = [FeedCandidate(origEvent: e, displayEvent: e)];
      expect(cache.hasCache, isTrue);
    });

    test('lastPageKey uses String (room ID) keys, not Timeline objects', () {
      cache.lastPageKey = {
        '!room1:matrix.org': const RoomPageState(lastDisplayedEventId: '\$ev1'),
        '!room2:matrix.org': const RoomPageState(exhausted: true),
      };

      expect(cache.lastPageKey!.containsKey('!room1:matrix.org'), isTrue);
      expect(
        cache.lastPageKey!['!room1:matrix.org']!.lastDisplayedEventId,
        '\$ev1',
      );
      expect(cache.lastPageKey!['!room2:matrix.org']!.exhausted, isTrue);
    });

    test('carryForwardEventIds stores event IDs per room', () {
      cache.carryForwardEventIds = {
        '!room1:matrix.org': ['\$e1', '\$e2', '\$e3'],
        '!room2:matrix.org': ['\$e4'],
      };

      expect(cache.carryForwardEventIds!['!room1:matrix.org']!.length, 3);
      expect(cache.carryForwardEventIds!['!room2:matrix.org']!.first, '\$e4');
    });

    test('frontier stores DateTime correctly', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      cache.frontier = ts;
      expect(cache.frontier, ts);
    });

    test('clear() resets all fields', () {
      final e = MockEvent();
      cache.cachedItems = [FeedCandidate(origEvent: e, displayEvent: e)];
      cache.scrollOffset = 123.0;
      cache.lastPageKey = {
        '!room:matrix.org': const RoomPageState(lastDisplayedEventId: '\$ev'),
      };
      cache.firstEventIds = {'!room:matrix.org': '\$ev'};
      cache.wasPageKeyInitialized = true;
      cache.carryForwardEventIds = {
        '!room:matrix.org': ['\$e1'],
      };
      cache.frontier = DateTime.now();

      // Verify everything is set
      expect(cache.hasCache, isTrue);
      expect(cache.scrollOffset, 123.0);
      expect(cache.lastPageKey, isNotNull);
      expect(cache.firstEventIds, isNotNull);
      expect(cache.wasPageKeyInitialized, isTrue);
      expect(cache.carryForwardEventIds, isNotNull);
      expect(cache.frontier, isNotNull);

      // Clear
      cache.clear();

      // Verify everything is reset
      expect(cache.cachedItems, isNull);
      expect(cache.scrollOffset, 0.0);
      expect(cache.lastPageKey, isNull);
      expect(cache.firstEventIds, isNull);
      expect(cache.wasPageKeyInitialized, isFalse);
      expect(cache.carryForwardEventIds, isNull);
      expect(cache.frontier, isNull);
      expect(cache.hasCache, isFalse);
    });

    test('cache round-trip: lastPageKey persists room-ID-based keys', () {
      // Simulate dispose() saving state
      final key = <String, RoomPageState>{
        '!active:matrix.org': const RoomPageState(lastDisplayedEventId: '\$a5'),
        '!inactive:matrix.org': const RoomPageState(),
      };
      cache.lastPageKey = key;

      // Simulate initState() restoring state
      final restored = cache.lastPageKey!;
      expect(restored.length, 2);
      expect(restored['!active:matrix.org']!.lastDisplayedEventId, '\$a5');
      expect(restored['!inactive:matrix.org']!.lastDisplayedEventId, isNull);

      // The key is a String (room ID), not a Timeline object —
      // so it survives widget lifecycle changes where Timeline objects are
      // recreated.
      expect(restored.keys.first, isA<String>());
    });

    test(
      'cache round-trip: carryForwardEventIds survives dispose/restore cycle',
      () {
        // Simulate dispose() saving carry-forward
        cache.carryForwardEventIds = {
          '!room1:matrix.org': ['\$cf1', '\$cf2'],
          '!room2:matrix.org': ['\$cf3'],
        };

        // Simulate initState() restoring
        final restored = cache.carryForwardEventIds!;
        expect(restored['!room1:matrix.org'], ['\$cf1', '\$cf2']);
        expect(restored['!room2:matrix.org'], ['\$cf3']);
      },
    );

    test('cache round-trip: frontier survives dispose/restore cycle', () {
      final frontier = DateTime(2025, 3, 15, 10, 30);
      cache.frontier = frontier;

      // Simulate restore
      expect(cache.frontier, frontier);
      expect(cache.frontier!.year, 2025);
      expect(cache.frontier!.month, 3);
    });
  });
}
