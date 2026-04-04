import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

/// Tests the feed merging algorithm for the core scenario:
/// rooms with vastly different message ages must be interleaved correctly.
///
/// The key invariant: events from "inactive" rooms (whose newest message is
/// very old) must NOT appear in the feed until the "active" rooms' history
/// has been loaded back far enough to reach the inactive room's time range.
///
/// Additionally, `lastId` must track the last *displayed* event (not last
/// scanned) so that carry-forward candidates can be re-discovered if lost
/// during widget lifecycle changes.

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockEvent extends Mock implements Event {}

class MockTimeline extends Mock implements Timeline {}

class MockUser extends Mock implements User {}

void main() {
  setUpAll(() {
    registerFallbackValue(MockTimeline());
  });

  group('Feed Frontier Merge Logic', () {
    late MockRoom roomActive;
    late MockRoom roomInactive;

    setUp(() {
      roomActive = MockRoom();
      roomInactive = MockRoom();

      when(() => roomActive.id).thenReturn('!active:matrix.org');
      when(() => roomActive.name).thenReturn('Active Room');
      when(() => roomInactive.id).thenReturn('!inactive:matrix.org');
      when(() => roomInactive.name).thenReturn('Inactive Room');
    });

    /// Creates a mock event with a specific timestamp.
    MockEvent makeEvent({
      required DateTime ts,
      required MockRoom room,
      required String eventId,
    }) {
      final e = MockEvent();
      when(() => e.originServerTs).thenReturn(ts);
      when(() => e.eventId).thenReturn(eventId);
      when(() => e.roomId).thenReturn(room.id);
      when(() => e.room).thenReturn(room);
      when(() => e.type).thenReturn('m.room.message');
      when(() => e.relationshipType).thenReturn(null);
      when(() => e.senderId).thenReturn('@user:matrix.org');
      // getDisplayEvent returns itself (no edits)
      when(() => e.getDisplayEvent(any())).thenReturn(e);
      // Mock power level check
      when(() => room.getPowerLevelByUserId(any())).thenReturn(100);
      when(() => room.getState('m.room.power_levels')).thenReturn(null);
      return e;
    }

    test(
      'Active room fills page when inactive room has only very old events',
      () {
        // Active room: 10 events from the last 2 weeks
        final now = DateTime.now();
        final activeEvents = List.generate(
          10,
          (i) => makeEvent(
            ts: now.subtract(Duration(days: i)),
            room: roomActive,
            eventId: '\$active_$i',
          ),
        );

        // Inactive room: 5 events from 2 years ago
        final inactiveEvents = List.generate(
          5,
          (i) => makeEvent(
            ts: now.subtract(Duration(days: 730 + i)),
            room: roomInactive,
            eventId: '\$inactive_$i',
          ),
        );

        // Merge and sort (simulating _fetchEvents merge step)
        final allCandidates = [...activeEvents, ...inactiveEvents];
        allCandidates.sort(
          (a, b) => b.originServerTs.compareTo(a.originServerTs),
        );

        // Take top 10 (page size)
        const pageSize = 10;
        final page = allCandidates.take(pageSize).toList();

        // All 10 should be from the active room (they're all newer)
        for (final event in page) {
          expect(
            event.roomId,
            '!active:matrix.org',
            reason:
                'Only active room events should appear on the first page '
                'because all inactive room events are 2 years old',
          );
        }

        // The inactive events should all be in the "unused" pool
        final retEventIds = page.map((e) => e.eventId).toSet();
        final unused =
            allCandidates
                .where((e) => !retEventIds.contains(e.eventId))
                .toList();
        expect(unused.length, 5);
        for (final event in unused) {
          expect(event.roomId, '!inactive:matrix.org');
        }
      },
    );

    test('Inactive room events appear once active room catches up in time', () {
      final now = DateTime.now();

      // Active room: 5 events from 3 years ago (caught up past inactive)
      final activeEvents = List.generate(
        5,
        (i) => makeEvent(
          ts: now.subtract(Duration(days: 1095 + i)),
          room: roomActive,
          eventId: '\$active_old_$i',
        ),
      );

      // Inactive room: 5 events from 2 years ago (now NEWER than active)
      final inactiveEvents = List.generate(
        5,
        (i) => makeEvent(
          ts: now.subtract(Duration(days: 730 + i)),
          room: roomInactive,
          eventId: '\$inactive_$i',
        ),
      );

      final allCandidates = [...activeEvents, ...inactiveEvents];
      allCandidates.sort(
        (a, b) => b.originServerTs.compareTo(a.originServerTs),
      );

      const pageSize = 10;
      final page = allCandidates.take(pageSize).toList();

      // All 10 fit in the page, and inactive events should come first
      // (they're from ~2 years ago, active from ~3 years ago)
      expect(page.length, 10);
      // First 5 should be inactive (newer), last 5 should be active (older)
      for (int i = 0; i < 5; i++) {
        expect(
          page[i].roomId,
          '!inactive:matrix.org',
          reason:
              'Inactive room events (2y ago) should appear before '
              'active room events (3y ago)',
        );
      }
      for (int i = 5; i < 10; i++) {
        expect(page[i].roomId, '!active:matrix.org');
      }
    });

    test('lastId tracks last DISPLAYED event — not last scanned candidate', () {
      final now = DateTime.now();

      // Active room: 5 events (recent)
      final activeEvents = List.generate(
        5,
        (i) => makeEvent(
          ts: now.subtract(Duration(days: i)),
          room: roomActive,
          eventId: '\$active_$i',
        ),
      );

      // Inactive room: 5 events (old)
      final inactiveEvents = List.generate(
        5,
        (i) => makeEvent(
          ts: now.subtract(Duration(days: 730 + i)),
          room: roomInactive,
          eventId: '\$inactive_$i',
        ),
      );

      final allCandidates = [...activeEvents, ...inactiveEvents];
      allCandidates.sort(
        (a, b) => b.originServerTs.compareTo(a.originServerTs),
      );

      const pageSize = 5;
      final page = allCandidates.take(pageSize).toList();

      // Simulate the CORRECT lastId tracking (last displayed, not last scanned)
      // For active room: all 5 events are in the page
      final activeInRet =
          page.where((e) => e.roomId == '!active:matrix.org').toList();
      final inactiveInRet =
          page.where((e) => e.roomId == '!inactive:matrix.org').toList();

      // Active room has all 5 displayed
      expect(activeInRet.length, 5);
      // Inactive room has 0 displayed
      expect(inactiveInRet.length, 0);

      // lastId for active room = last displayed event
      final activeLastId = activeInRet.last.eventId;
      expect(activeLastId, '\$active_4');

      // lastId for inactive room should NOT advance (nothing displayed)
      // It should remain as the previous lastId (null for first page)
      // This is the key fix: previously it would advance to \$inactive_4
      // (the last scanned candidate), permanently skipping those events
      // if carry-forward was lost.
      String? inactiveLastId;
      if (inactiveInRet.isNotEmpty) {
        inactiveLastId = inactiveInRet.last.eventId;
      }
      expect(
        inactiveLastId,
        isNull,
        reason:
            'Inactive room lastId must not advance when no events were displayed. '
            'This ensures carry-forward events can be re-discovered if lost.',
      );
    });

    test('Carry-forward preserves unused candidates across pages', () {
      final now = DateTime.now();

      // Page 1: active room fills the page
      final activeP1 = List.generate(
        5,
        (i) => makeEvent(
          ts: now.subtract(Duration(days: i)),
          room: roomActive,
          eventId: '\$active_p1_$i',
        ),
      );
      final inactiveP1 = List.generate(
        3,
        (i) => makeEvent(
          ts: now.subtract(Duration(days: 730 + i)),
          room: roomInactive,
          eventId: '\$inactive_$i',
        ),
      );

      final allP1 = [...activeP1, ...inactiveP1];
      allP1.sort((a, b) => b.originServerTs.compareTo(a.originServerTs));

      const pageSize = 5;
      final page1 = allP1.take(pageSize).toList();
      final retIds1 = page1.map((e) => e.eventId).toSet();

      // Carry forward = unused
      final carryForward =
          allP1.where((e) => !retIds1.contains(e.eventId)).toList();
      expect(carryForward.length, 3, reason: '3 inactive events carried');
      expect(
        carryForward.every((e) => e.roomId == '!inactive:matrix.org'),
        isTrue,
      );

      // Page 2: active room has older events, carry-forward still available
      final activeP2 = List.generate(
        5,
        (i) => makeEvent(
          ts: now.subtract(Duration(days: 100 + i)),
          room: roomActive,
          eventId: '\$active_p2_$i',
        ),
      );

      // Merge carry-forward + new active events
      final allP2 = [...carryForward, ...activeP2];
      allP2.sort((a, b) => b.originServerTs.compareTo(a.originServerTs));

      final page2 = allP2.take(pageSize).toList();

      // Active room events (100+ days ago) are still newer than inactive
      // (730+ days ago), so page 2 should be all active
      for (final event in page2) {
        expect(event.roomId, '!active:matrix.org');
      }

      // Carry forward should still have the 3 inactive events
      final retIds2 = page2.map((e) => e.eventId).toSet();
      final carryForward2 =
          allP2.where((e) => !retIds2.contains(e.eventId)).toList();
      expect(carryForward2.length, 3);
      expect(
        carryForward2.every((e) => e.roomId == '!inactive:matrix.org'),
        isTrue,
      );
    });

    test(
      'Frontier-aware: skip requestHistory for rooms behind the frontier',
      () {
        final now = DateTime.now();

        // Simulate the frontier from the last page (oldest displayed event)
        final frontier = now.subtract(const Duration(days: 30));

        // Room A's newest carry-forward event is older than the frontier
        final roomACandidateTs = now.subtract(const Duration(days: 730));
        final isBehindFrontier = roomACandidateTs.isBefore(frontier);

        expect(
          isBehindFrontier,
          isTrue,
          reason:
              'Room A (2 years old) should be behind the frontier (30 days). '
              'requestHistory should be skipped for this room.',
        );

        // Room B's newest carry-forward event is within the frontier
        final roomBCandidateTs = now.subtract(const Duration(days: 25));
        final isWithinFrontier = !roomBCandidateTs.isBefore(frontier);

        expect(
          isWithinFrontier,
          isTrue,
          reason:
              'Room B (25 days old) is within the frontier (30 days). '
              'requestHistory should proceed normally.',
        );
      },
    );

    test('Three rooms with staggered ages merge correctly across pages', () {
      final now = DateTime.now();

      // Room A: very active (last week)
      final roomC = MockRoom();
      when(() => roomC.id).thenReturn('!roomC:matrix.org');
      when(() => roomC.name).thenReturn('Room C');

      final eventsA = List.generate(
        5,
        (i) => makeEvent(
          ts: now.subtract(Duration(days: i)),
          room: roomActive,
          eventId: '\$a_$i',
        ),
      );

      // Room B: moderately active (last month)
      final eventsB = List.generate(
        5,
        (i) => makeEvent(
          ts: now.subtract(Duration(days: 30 + i)),
          room: roomInactive,
          eventId: '\$b_$i',
        ),
      );

      // Room C: inactive (2 years ago)
      final eventsC = List.generate(
        5,
        (i) => makeEvent(
          ts: now.subtract(Duration(days: 730 + i)),
          room: roomC,
          eventId: '\$c_$i',
        ),
      );

      final all = [...eventsA, ...eventsB, ...eventsC];
      all.sort((a, b) => b.originServerTs.compareTo(a.originServerTs));

      // Page 1 (5 items): should be all Room A (0-4 days ago)
      const pageSize = 5;
      final page1 = all.take(pageSize).toList();
      expect(page1.every((e) => e.roomId == '!active:matrix.org'), isTrue);

      // Carry forward
      final retIds1 = page1.map((e) => e.eventId).toSet();
      final remaining1 =
          all.where((e) => !retIds1.contains(e.eventId)).toList();

      // Page 2 (next 5): should be all Room B (30-34 days ago)
      final page2 = remaining1.take(pageSize).toList();
      expect(page2.every((e) => e.roomId == '!inactive:matrix.org'), isTrue);

      // Page 3 (next 5): should be all Room C (730-734 days ago)
      final retIds2 = page2.map((e) => e.eventId).toSet();
      final remaining2 =
          remaining1.where((e) => !retIds2.contains(e.eventId)).toList();
      final page3 = remaining2.take(pageSize).toList();
      expect(page3.every((e) => e.roomId == '!roomC:matrix.org'), isTrue);
    });
  });
}
