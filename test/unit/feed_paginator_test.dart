import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:substitution/feed/services/feed_candidate.dart';
import 'package:substitution/feed/services/feed_paginator.dart';
import 'package:substitution/feed/services/room_timeline_adapter.dart';

/// An in-memory fake of [RoomTimelineAdapter] that models each room as a
/// list of events sorted newest-first. The "local" portion is a prefix of
/// each list (events already loaded into the timeline), and the remainder
/// represents server history available via [requestMoreHistory].
///
/// This lets tests deterministically control what's loaded vs. remote.
class FakeRoomAdapter implements RoomTimelineAdapter {
  FakeRoomAdapter({
    required this.rooms,
    this.supportsTimestamp = true,
    int initialLocalCount = 30,
  }) {
    for (final roomId in rooms.keys) {
      final events = rooms[roomId]!;
      _localCounts[roomId] = min(initialLocalCount, events.length);
    }
  }

  /// Full room history per room, sorted newest-first.
  // ignore: library_private_types_in_public_api
  final Map<String, List<_FakeEvent>> rooms;

  /// Whether `timestamp_to_event` is supported.
  final bool supportsTimestamp;

  /// How many events per room are currently "loaded locally".
  final Map<String, int> _localCounts = {};

  /// Network call counters (for assertions).
  int requestHistoryCalls = 0;
  int findByTimestampCalls = 0;
  int loadEventsBetweenCalls = 0;

  @override
  Set<String> get roomIds => rooms.keys.toSet();

  @override
  List<FeedCandidate> scanLocal(String roomId, {String? afterEventId}) {
    final events = rooms[roomId]!;
    final localCount = _localCounts[roomId] ?? 0;
    final local = events.sublist(0, localCount);

    int startIndex = 0;
    if (afterEventId != null) {
      final idx = local.indexWhere((e) => e.eventId == afterEventId);
      if (idx >= 0) startIndex = idx + 1;
    }
    return local
        .sublist(startIndex)
        .map((e) => FeedCandidate(origEvent: e as Event, displayEvent: e))
        .toList();
  }

  @override
  Future<bool> requestMoreHistory(
    String roomId, {
    int historyCount = 20,
  }) async {
    requestHistoryCalls++;
    final events = rooms[roomId]!;
    final current = _localCounts[roomId] ?? 0;
    if (current >= events.length) return false;
    final newCount = min(current + historyCount, events.length);
    final added = newCount - current;
    _localCounts[roomId] = newCount;
    return added > 0;
  }

  @override
  bool canRequestHistory(String roomId) {
    final events = rooms[roomId]!;
    final current = _localCounts[roomId] ?? 0;
    return current < events.length;
  }

  @override
  Future<String?> findEventByTimestamp(
    String roomId,
    DateTime ts, {
    Direction direction = Direction.b,
  }) async {
    findByTimestampCalls++;
    if (!supportsTimestamp) return null;
    final events = rooms[roomId]!;
    // dir=b: find newest event with ts <= target.
    for (final e in events) {
      if (!e.ts.isAfter(ts)) return e.eventId;
    }
    return null; // no event at/before ts
  }

  @override
  bool supportsTimestampToEvent(String roomId) => supportsTimestamp;

  @override
  Future<bool> loadEventsBetween(
    String roomId,
    String anchorEventId,
    DateTime untilTs,
  ) async {
    loadEventsBetweenCalls++;
    final events = rooms[roomId]!;
    final anchorIdx = events.indexWhere((e) => e.eventId == anchorEventId);
    if (anchorIdx < 0) return false;
    // Ensure anchor is loaded locally, then expand load up to anchorIdx+1.
    final current = _localCounts[roomId] ?? 0;
    final newCount = max(current, anchorIdx + 1);
    final added = newCount - current;
    _localCounts[roomId] = newCount;
    return added > 0;
  }
}

/// Adapter that can advance history without ever yielding feed candidates.
///
/// This models rooms where fetched history is composed of non-feed events
/// (e.g. state changes), so `scanLocal` stays empty even though the
/// timeline advances.
class EmptyCandidateProgressAdapter implements RoomTimelineAdapter {
  EmptyCandidateProgressAdapter({required this.maxHistoryAdvances});

  final int maxHistoryAdvances;
  int requestHistoryCalls = 0;

  @override
  Set<String> get roomIds => {'!room:test'};

  @override
  List<FeedCandidate> scanLocal(String roomId, {String? afterEventId}) =>
      const [];

  @override
  Future<bool> requestMoreHistory(
    String roomId, {
    int historyCount = 20,
  }) async {
    requestHistoryCalls++;
    return requestHistoryCalls <= maxHistoryAdvances;
  }

  @override
  bool canRequestHistory(String roomId) =>
      requestHistoryCalls < maxHistoryAdvances;

  @override
  bool supportsTimestampToEvent(String roomId) => false;

  @override
  Future<String?> findEventByTimestamp(
    String roomId,
    DateTime ts, {
    Direction direction = Direction.b,
  }) async => null;

  @override
  Future<bool> loadEventsBetween(
    String roomId,
    String anchorEventId,
    DateTime untilTs,
  ) async => false;
}

/// Minimal fake [Event] that only stubs the fields [FeedCandidate] uses.
/// We implement only the accessors actually touched by the paginator.
class _FakeEvent implements Event {
  _FakeEvent({required this.eventId, required this.roomId, required this.ts});

  @override
  final String eventId;

  @override
  final String roomId;

  final DateTime ts;

  @override
  DateTime get originServerTs => ts;

  @override
  String get type => 'm.room.message';

  @override
  String? get relationshipType => null;

  @override
  Room get room => throw UnimplementedError('not used in tests');

  @override
  Event getDisplayEvent(Timeline timeline) => this;

  @override
  String get senderId => '@alice:example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Ignored fields — the paginator does not read them.
    return super.noSuchMethod(invocation);
  }
}

/// Builds a room with events at the given [ages] (days ago from [now]).
List<_FakeEvent> _room(String roomId, List<int> ages, {DateTime? now}) {
  final base = now ?? DateTime(2026, 1, 1);
  final events = <_FakeEvent>[];
  for (int i = 0; i < ages.length; i++) {
    events.add(
      _FakeEvent(
        eventId: '\$${roomId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_e$i',
        roomId: roomId,
        ts: base.subtract(Duration(days: ages[i])),
      ),
    );
  }
  // Ensure newest-first (guard against unsorted input).
  events.sort((a, b) => b.ts.compareTo(a.ts));
  return events;
}

/// Builds an initial PageKey covering all rooms in [adapter] with default
/// (fresh) state.
PageKey _initialKey(FakeRoomAdapter adapter) => {
  for (final roomId in adapter.roomIds) roomId: const RoomPageState(),
};

void main() {
  group('FeedPaginator — take-only-safe correctness', () {
    test("user's scenario: R1 [days,2w], R2 [days,2y], R3 empty", () async {
      // R1: posts from last 5 days + cluster at 14 days ago.
      // R2: posts from last 5 days + cluster at ~730 days ago.
      // R3: no events at all.
      final r1 = _room('!r1:test', [0, 1, 2, 3, 4, 14, 14, 14, 14, 14, 14, 14]);
      final r2 = _room('!r2:test', [0, 1, 730, 730, 730, 730, 730, 730, 730]);
      final r3 = <_FakeEvent>[];
      final adapter = FakeRoomAdapter(
        rooms: {'!r1:test': r1, '!r2:test': r2, '!r3:test': r3},
        initialLocalCount: 30,
      );

      final paginator = FeedPaginator(
        adapter: adapter,
        pageSize: 20,
        minSafePageSize: 10,
      );

      final result = await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );

      // Safety: no displayed event is older than any event in the
      // "unseen" set (which for page 1 is empty since we loaded everything
      // in local count=30, but the 2y events of R2 must not interleave
      // before R1's 2w events).
      final displayed = result.events;
      expect(displayed, isNotEmpty);

      // Verify monotonic newest-first.
      for (int i = 1; i < displayed.length; i++) {
        expect(
          displayed[i - 1].ts.isBefore(displayed[i].ts),
          isFalse,
          reason: 'Events must be newest-first',
        );
      }

      // CRITICAL: the 2y events of R2 must NOT appear before any R1 event
      // that is newer than 2y (all of R1's events are newer than 2y).
      final firstR2Ancient = displayed.indexWhere(
        (c) =>
            c.roomId == '!r2:test' &&
            c.ts.isBefore(
              DateTime(2026, 1, 1).subtract(const Duration(days: 100)),
            ),
      );
      final lastR1 = displayed.lastIndexWhere((c) => c.roomId == '!r1:test');
      if (firstR2Ancient != -1 && lastR1 != -1) {
        expect(
          firstR2Ancient > lastR1,
          isTrue,
          reason:
              'R2 ancient (2y) events must appear AFTER all R1 (2w) events. '
              'Found 2y-R2 at $firstR2Ancient and last R1 at $lastR1.',
        );
      }
    });

    test('safety invariant: no displayed ts < any unseen event ts', () async {
      // Three rooms with various gap patterns.
      final r1 = _room('!r1:test', [0, 1, 2, 3, 4, 5, 100, 101, 102]);
      final r2 = _room('!r2:test', [0, 1, 50, 51, 52, 1000, 1001]);
      final r3 = _room('!r3:test', [2, 3, 4, 30, 31, 32, 33, 500]);

      // Load only 3 events locally per room — forces saturation decisions.
      final adapter = FakeRoomAdapter(
        rooms: {'!r1:test': r1, '!r2:test': r2, '!r3:test': r3},
        initialLocalCount: 3,
      );
      final paginator = FeedPaginator(
        adapter: adapter,
        pageSize: 20,
        minSafePageSize: 10,
      );

      final result = await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );

      // Collect all displayed event IDs.
      final displayedIds = result.events.map((c) => c.eventId).toSet();

      // Find the "unseen" set: all events across all rooms not displayed.
      final unseen = <_FakeEvent>[];
      for (final events in adapter.rooms.values) {
        for (final e in events) {
          if (!displayedIds.contains(e.eventId)) unseen.add(e);
        }
      }

      if (result.events.isEmpty) return; // trivially safe

      final oldestDisplayed = result.events.last.ts;

      for (final u in unseen) {
        expect(
          u.ts.isBefore(oldestDisplayed) ||
              u.ts.isAtSameMomentAs(oldestDisplayed),
          isTrue,
          reason:
              'Unseen event at ${u.ts} is NEWER than oldest displayed '
              '($oldestDisplayed) — safety violated.',
        );
      }
    });

    test(
      'monotonicity across pages: page[n].last.ts >= page[n+1].first.ts',
      () async {
        final r1 = _room('!r1:test', List.generate(40, (i) => i));
        final r2 = _room('!r2:test', List.generate(40, (i) => i * 2));
        final r3 = _room('!r3:test', List.generate(40, (i) => i * 3 + 10));
        final adapter = FakeRoomAdapter(
          rooms: {'!r1:test': r1, '!r2:test': r2, '!r3:test': r3},
          initialLocalCount: 5,
        );
        final paginator = FeedPaginator(
          adapter: adapter,
          pageSize: 10,
          minSafePageSize: 5,
        );

        DateTime? prevLastTs;
        PageKey? key = _initialKey(adapter);
        var carryForward = <String, List<FeedCandidate>>{};
        for (int page = 0; page < 10; page++) {
          if (key == null || key.isEmpty) break;
          final res = await paginator.paginate(
            pageKey: key,
            carryForward: carryForward,
          );
          if (res.events.isEmpty) break;

          // Check monotonicity with previous page: page[n].first.ts must be
          // <= page[n-1].last.ts (newest-first across the whole feed).
          if (prevLastTs != null) {
            expect(
              res.events.first.ts.isAfter(prevLastTs),
              isFalse,
              reason:
                  'Page $page first (${res.events.first.ts}) is NEWER than '
                  'page ${page - 1} last ($prevLastTs) — temporal regression.',
            );
          }
          prevLastTs = res.events.last.ts;
          key = res.nextKey;
          carryForward = res.carryForward;
        }
      },
    );

    test(
      'completeness: every event eventually appears, no duplicates',
      () async {
        final r1 = _room('!r1:test', List.generate(15, (i) => i));
        final r2 = _room('!r2:test', List.generate(15, (i) => i * 2));
        final adapter = FakeRoomAdapter(
          rooms: {'!r1:test': r1, '!r2:test': r2},
          initialLocalCount: 5,
        );
        final paginator = FeedPaginator(
          adapter: adapter,
          pageSize: 8,
          minSafePageSize: 4,
        );

        final allDisplayed = <String>{};
        PageKey? key = _initialKey(adapter);
        var carryForward = <String, List<FeedCandidate>>{};
        for (int page = 0; page < 30; page++) {
          if (key == null || key.isEmpty) break;
          final res = await paginator.paginate(
            pageKey: key,
            carryForward: carryForward,
          );
          for (final c in res.events) {
            expect(
              allDisplayed.add(c.eventId),
              isTrue,
              reason: 'Event ${c.eventId} displayed twice',
            );
          }
          if (res.events.isEmpty && res.nextKey == null) break;
          key = res.nextKey;
          carryForward = res.carryForward;
        }

        final totalEvents = r1.length + r2.length;
        expect(
          allDisplayed.length,
          totalEvents,
          reason: 'Not all events were displayed across pagination',
        );
      },
    );

    test('termination: pagination reaches a stopping state', () async {
      final r1 = _room('!r1:test', List.generate(50, (i) => i));
      final r2 = _room('!r2:test', List.generate(50, (i) => i + 100));
      final adapter = FakeRoomAdapter(
        rooms: {'!r1:test': r1, '!r2:test': r2},
        initialLocalCount: 10,
      );
      final paginator = FeedPaginator(adapter: adapter, pageSize: 15);

      int pageCount = 0;
      PageKey? key = _initialKey(adapter);
      var carryForward = <String, List<FeedCandidate>>{};
      while (key != null && key.isNotEmpty && pageCount < 100) {
        final res = await paginator.paginate(
          pageKey: key,
          carryForward: carryForward,
        );
        if (res.events.isEmpty && res.nextKey == null) break;
        key = res.nextKey;
        carryForward = res.carryForward;
        pageCount++;
      }
      expect(
        pageCount,
        lessThan(100),
        reason: 'Pagination must terminate in bounded iterations',
      );
    });
  });

  group('FeedPaginator — saturation behaviour', () {
    test('saturation triggered when safe page < minSafePageSize', () async {
      // Set up: one recent room with only 2 events locally, the server has
      // more. The safe page will be tiny (2 events) → saturation should
      // load more history to advance t_safe.
      final recentRoom = _room('!active:test', List.generate(30, (i) => i));
      final oldRoom = _room('!old:test', [500, 501, 502, 503, 504]);
      final adapter = FakeRoomAdapter(
        rooms: {'!active:test': recentRoom, '!old:test': oldRoom},
        initialLocalCount: 2,
      );
      final paginator = FeedPaginator(
        adapter: adapter,
        pageSize: 20,
        minSafePageSize: 10,
      );

      final res = await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );

      expect(
        res.events.length,
        greaterThanOrEqualTo(10),
        reason: 'Saturation should have filled the page to at least the min',
      );
    });

    test('no saturation needed when safe page already full', () async {
      // 3 active rooms with lots of recent events; first scan fills page.
      final r1 = _room('!r1:test', List.generate(30, (i) => i));
      final r2 = _room('!r2:test', List.generate(30, (i) => i + 1));
      final r3 = _room('!r3:test', List.generate(30, (i) => i + 2));
      final adapter = FakeRoomAdapter(
        rooms: {'!r1:test': r1, '!r2:test': r2, '!r3:test': r3},
        initialLocalCount: 30,
      );
      final paginator = FeedPaginator(
        adapter: adapter,
        pageSize: 20,
        minSafePageSize: 10,
      );

      final res = await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );

      expect(res.events.length, 20);
      expect(
        adapter.requestHistoryCalls,
        0,
        reason: 'No extra network calls should have been made',
      );
    });

    test('timestamp_to_event used when gap exceeds threshold', () async {
      // Active room has 2 recent events then a huge gap to 2-year-old ones.
      final active = _room('!active:test', [0, 1, 730, 731, 732]);
      final steady = _room('!steady:test', List.generate(30, (i) => i + 10));
      final adapter = FakeRoomAdapter(
        rooms: {'!active:test': active, '!steady:test': steady},
        initialLocalCount: 2,
        supportsTimestamp: true,
      );
      final paginator = FeedPaginator(
        adapter: adapter,
        pageSize: 20,
        minSafePageSize: 10,
        timestampToEventGapThreshold: const Duration(days: 1),
      );

      await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );

      // With a huge gap, we expect timestamp_to_event was consulted.
      expect(
        adapter.findByTimestampCalls,
        greaterThan(0),
        reason:
            'timestamp_to_event should be used for large gaps when supported',
      );
    });

    test('falls back to requestHistory when v1.6 not supported', () async {
      final active = _room('!active:test', [0, 1, 730, 731]);
      final steady = _room('!steady:test', List.generate(30, (i) => i + 10));
      final adapter = FakeRoomAdapter(
        rooms: {'!active:test': active, '!steady:test': steady},
        initialLocalCount: 2,
        supportsTimestamp: false,
      );
      final paginator = FeedPaginator(
        adapter: adapter,
        pageSize: 20,
        minSafePageSize: 10,
      );

      await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );

      expect(adapter.findByTimestampCalls, 0);
      expect(
        adapter.requestHistoryCalls,
        greaterThan(0),
        reason: 'Fallback path must use requestHistory',
      );
    });

    test('saturation respects maxSaturationRounds cap', () async {
      // Make progress impossible: both rooms have only 1 event loaded
      // initially but more on the server that are OLDER.
      final r1 = _room('!r1:test', List.generate(100, (i) => i));
      final r2 = _room('!r2:test', List.generate(100, (i) => i + 500));
      final adapter = FakeRoomAdapter(
        rooms: {'!r1:test': r1, '!r2:test': r2},
        initialLocalCount: 1,
      );
      final paginator = FeedPaginator(
        adapter: adapter,
        pageSize: 20,
        minSafePageSize: 10,
        maxSaturationRounds: 2,
      );

      await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );

      expect(
        adapter.requestHistoryCalls + adapter.loadEventsBetweenCalls,
        lessThanOrEqualTo(2 * adapter.rooms.length + 1),
        reason: 'Saturation must cap at maxSaturationRounds',
      );
    });

    test(
      'continues saturating when history advances without new candidates',
      () async {
        final adapter = EmptyCandidateProgressAdapter(maxHistoryAdvances: 10);
        final paginator = FeedPaginator(
          adapter: adapter,
          pageSize: 20,
          minSafePageSize: 10,
          maxSaturationRounds: 3,
        );

        await paginator.paginate(
          pageKey: {'!room:test': const RoomPageState()},
          carryForward: const {},
        );

        expect(
          adapter.requestHistoryCalls,
          3,
          reason:
              'Paginator should keep saturating up to max rounds even when '
              'newly loaded history yields no feed candidates.',
        );
      },
    );
  });

  group('FeedPaginator — edge cases', () {
    test('empty pageKey returns empty result', () async {
      final adapter = FakeRoomAdapter(rooms: {});
      final paginator = FeedPaginator(adapter: adapter);
      final res = await paginator.paginate(pageKey: {}, carryForward: const {});
      expect(res.events, isEmpty);
    });

    test('single room works correctly', () async {
      final r = _room('!only:test', List.generate(25, (i) => i));
      final adapter = FakeRoomAdapter(
        rooms: {'!only:test': r},
        initialLocalCount: 25,
      );
      final paginator = FeedPaginator(adapter: adapter, pageSize: 10);
      final res = await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );
      expect(res.events.length, 10);
      // All from the single room, newest first.
      for (int i = 1; i < res.events.length; i++) {
        expect(res.events[i - 1].ts.isAfter(res.events[i].ts), isTrue);
      }
    });

    test('exhausted room is removed from nextKey', () async {
      final r = _room('!short:test', [0, 1]);
      final adapter = FakeRoomAdapter(
        rooms: {'!short:test': r},
        initialLocalCount: 2,
      );
      final paginator = FeedPaginator(adapter: adapter, pageSize: 10);
      final res = await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );
      expect(res.events.length, 2);
      expect(
        res.nextKey == null || res.nextKey!.isEmpty,
        isTrue,
        reason: 'Exhausted single room → nextKey should be terminal',
      );
    });

    test('carry-forward passed between pages prevents re-scan', () async {
      final r1 = _room('!r1:test', List.generate(10, (i) => i));
      final r2 = _room('!r2:test', List.generate(10, (i) => i + 50));
      final adapter = FakeRoomAdapter(
        rooms: {'!r1:test': r1, '!r2:test': r2},
        initialLocalCount: 10,
      );
      final paginator = FeedPaginator(adapter: adapter, pageSize: 5);

      final res1 = await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );
      expect(res1.events.length, 5);

      final calls1 = adapter.requestHistoryCalls;
      final res2 = await paginator.paginate(
        pageKey: res1.nextKey!,
        carryForward: res1.carryForward,
      );
      // No new network calls because carry-forward had plenty to use.
      expect(adapter.requestHistoryCalls, calls1);
      expect(res2.events, isNotEmpty);
    });
  });

  group('FeedPaginator — property-based (fuzz) tests', () {
    test('random room distributions always satisfy safety invariant', () async {
      final rng = Random(42);
      for (int trial = 0; trial < 40; trial++) {
        final numRooms = 2 + rng.nextInt(4); // 2..5 rooms
        final rooms = <String, List<_FakeEvent>>{};
        for (int r = 0; r < numRooms; r++) {
          final numEvents = 1 + rng.nextInt(30);
          final ages = List.generate(numEvents, (_) => rng.nextInt(1000));
          rooms['!r$r:test'] = _room('!r$r:test', ages);
        }
        final initialLocal = 1 + rng.nextInt(10);
        final adapter = FakeRoomAdapter(
          rooms: rooms,
          initialLocalCount: initialLocal,
          supportsTimestamp: rng.nextBool(),
        );
        final paginator = FeedPaginator(
          adapter: adapter,
          pageSize: 5 + rng.nextInt(15),
          minSafePageSize: 1 + rng.nextInt(8),
          maxSaturationRounds: 3,
        );

        PageKey? key = _initialKey(adapter);
        var carryForward = <String, List<FeedCandidate>>{};
        final displayed = <String>{};
        for (int page = 0; page < 50; page++) {
          if (key == null || key.isEmpty) break;
          final res = await paginator.paginate(
            pageKey: key,
            carryForward: carryForward,
          );

          // Invariant 1: no duplicates.
          for (final c in res.events) {
            expect(
              displayed.add(c.eventId),
              isTrue,
              reason: 'Trial $trial page $page: duplicate ${c.eventId}',
            );
          }

          // Invariant 2: newest-first within page.
          for (int i = 1; i < res.events.length; i++) {
            expect(
              res.events[i - 1].ts.isBefore(res.events[i].ts),
              isFalse,
              reason:
                  'Trial $trial page $page: not newest-first at position $i',
            );
          }

          if (res.events.isEmpty && res.nextKey == null) break;
          key = res.nextKey;
          carryForward = res.carryForward;
        }

        // Invariant 3: no event is "orphaned" — if there are events in rooms
        // older than ALL displayed events, they would be returned on further
        // pagination. We verify that the displayed set plus any that would
        // be returned by continued pagination covers all events.
        // (We approximate this by just checking the displayed set is large
        // enough given the number of events and pages we ran.)
        final allEvents =
            rooms.values.expand((l) => l).map((e) => e.eventId).toSet();
        // If pagination terminated, displayed == allEvents.
        if (key == null || key.isEmpty) {
          expect(
            displayed,
            allEvents,
            reason: 'Trial $trial: terminated but not all events were shown',
          );
        }
      }
    });

    test('request count stays bounded per page', () async {
      // Scenario: 10 rooms, each with varied gaps.
      final rng = Random(7);
      final rooms = <String, List<_FakeEvent>>{};
      for (int r = 0; r < 10; r++) {
        final ages = <int>[];
        // Cluster of recent events
        for (int i = 0; i < 5; i++) {
          ages.add(rng.nextInt(10));
        }
        // Old cluster (maybe)
        if (rng.nextBool()) {
          final old = 300 + rng.nextInt(500);
          for (int i = 0; i < rng.nextInt(10); i++) {
            ages.add(old + i);
          }
        }
        rooms['!r$r:test'] = _room('!r$r:test', ages);
      }
      final adapter = FakeRoomAdapter(
        rooms: rooms,
        initialLocalCount: 3,
        supportsTimestamp: true,
      );
      final paginator = FeedPaginator(
        adapter: adapter,
        pageSize: 20,
        minSafePageSize: 10,
        maxSaturationRounds: 3,
      );

      await paginator.paginate(
        pageKey: _initialKey(adapter),
        carryForward: const {},
      );

      // Cap: for 10 rooms × 3 rounds + per-round overhead.
      final totalRequests =
          adapter.requestHistoryCalls +
          adapter.findByTimestampCalls +
          adapter.loadEventsBetweenCalls;
      expect(
        totalRequests,
        lessThan(60),
        reason:
            'Request count per page should stay well-bounded (got $totalRequests)',
      );
    });
  });
}
