import 'package:matrix/matrix.dart';

import 'feed_candidate.dart';
import 'room_timeline_adapter.dart';

/// Pure algorithmic engine that produces a newest-first, globally-sorted page
/// of posts across multiple Matrix rooms.
///
/// # Correctness guarantee
///
/// For every page returned, every displayed event's timestamp is strictly
/// greater than every **unseen** event's timestamp. Equivalently:
///
///     ∀ displayed event e, ∀ unseen event u:  ts(e) > ts(u)
///
/// This is the **safety invariant**. It ensures that paging through the feed
/// never produces a temporal "leak" where an old event from one room slips in
/// before a newer event from another room.
///
/// # Algorithm: take-only-safe + on-demand saturation
///
/// 1. Scan each room locally and merge carry-forward candidates.
/// 2. Let α_i = oldest loaded candidate timestamp for room i (or ∞ if empty
///    and the room might have more history; or −∞ if the room is exhausted).
/// 3. Define **t_safe** = max over all non-exhausted rooms of α_i.
/// 4. Take all candidates with ts ≥ t_safe, sorted newest-first, up to page
///    size. These are provably the newest unseen posts.
/// 5. If the safe page is too small (< [minSafePageSize]), perform
///    **on-demand saturation**: fetch more history for the "blocking" room
///    (the one with the highest α_i) to advance t_safe backward. Use
///    `timestamp_to_event` to efficiently skip large temporal gaps.
/// 6. Re-compute safe page and repeat up to [maxSaturationRounds] times.
///
/// # Why this is correct
///
/// Matrix's `/messages?dir=b` endpoint returns events in strictly reverse
/// chronological order. So for each room i, every event in the server's
/// remaining history has ts < α_i. If we never display events with
/// ts < t_safe = max(α_i), then for any unseen event u in any room i:
///
///     ts(u) < α_i ≤ t_safe ≤ ts(e)  for every displayed e
///
/// ∎
class FeedPaginator {
  FeedPaginator({
    required this.adapter,
    this.pageSize = 20,
    this.minSafePageSize = 10,
    this.maxSaturationRounds = 3,
    this.timestampToEventGapThreshold = const Duration(days: 1),
  });

  /// Matrix SDK abstraction for room timeline operations.
  final RoomTimelineAdapter adapter;

  /// Target number of events per page. Pages may be smaller when not enough
  /// candidates are available even after saturation.
  final int pageSize;

  /// Minimum safe page size that triggers on-demand saturation. Below this
  /// threshold we fetch more history for the blocking room.
  final int minSafePageSize;

  /// Upper bound on saturation loop iterations per page, to cap network use.
  final int maxSaturationRounds;

  /// If the gap between α_blocking and α_secondary exceeds this threshold
  /// AND the server supports v1.6, use `timestamp_to_event` to skip the gap.
  /// For smaller gaps, traditional `requestHistory` is cheaper.
  final Duration timestampToEventGapThreshold;

  /// Produces one page of feed events.
  ///
  /// [pageKey] tracks per-room pagination state from the previous page (or
  /// `null`/empty to start fresh). [carryForward] holds candidates that were
  /// loaded but not displayed on the previous page; passing them back avoids
  /// re-loading.
  Future<PageResult> paginate({
    required PageKey pageKey,
    required Map<String, List<FeedCandidate>> carryForward,
  }) async {
    // ── Step 1: Collect per-room candidate pools ────────────────────────
    final pools = _collectInitialPools(pageKey, carryForward);

    // ── Step 2: Iterate safe-page extraction + on-demand saturation ─────
    List<FeedCandidate> safePage = const [];
    DateTime? tSafe;
    int rounds = 0;
    while (true) {
      tSafe = _computeSafeThreshold(pools);
      safePage = _extractSafePage(pools, tSafe);

      final needSaturation =
          safePage.length < minSafePageSize && rounds < maxSaturationRounds;
      if (!needSaturation) break;

      final advanced = await _saturateBlockingRoom(pools, tSafe);
      if (!advanced) break; // Nothing more to fetch; stop even if under min.
      rounds++;
    }

    // ── Step 3: Compute carry-forward and next key ──────────────────────
    final displayedIds = safePage.map((c) => c.eventId).toSet();
    final nextCarryForward = <String, List<FeedCandidate>>{};
    final nextKey = <String, RoomPageState>{};

    for (final entry in pools.entries) {
      final roomId = entry.key;
      final pool = entry.value;

      final unused =
          pool.candidates
              .where((c) => !displayedIds.contains(c.eventId))
              .toList();
      if (unused.isNotEmpty) {
        nextCarryForward[roomId] = unused;
      }

      // Update lastDisplayedEventId to the oldest event from this room that
      // we just displayed (if any). Otherwise keep the previous marker.
      final displayedFromRoom =
          safePage.where((c) => c.roomId == roomId).toList();
      final newLastId =
          displayedFromRoom.isNotEmpty
              ? displayedFromRoom.last.eventId
              : pool.lastDisplayedEventId;

      final isExhausted = !adapter.canRequestHistory(roomId) && unused.isEmpty;
      if (!isExhausted) {
        nextKey[roomId] = RoomPageState(
          lastDisplayedEventId: newLastId,
          exhausted: false,
        );
      }
    }

    return PageResult(
      events: safePage,
      nextKey: nextKey.isEmpty ? null : nextKey,
      carryForward: nextCarryForward,
      frontier: tSafe,
    );
  }

  // ─── Internal helpers ─────────────────────────────────────────────────

  /// Gathers initial candidates per room (carry-forward + local scan).
  Map<String, _RoomPool> _collectInitialPools(
    PageKey pageKey,
    Map<String, List<FeedCandidate>> carryForward,
  ) {
    final pools = <String, _RoomPool>{};

    for (final entry in pageKey.entries) {
      final roomId = entry.key;
      final state = entry.value;
      if (state.exhausted) continue;

      final seen = <String>{};
      final candidates = <FeedCandidate>[];

      // Start with carry-forward (preserves events fetched but not displayed).
      final carried = carryForward[roomId] ?? const [];
      for (final c in carried) {
        if (seen.add(c.eventId)) candidates.add(c);
      }

      // Then scan locally from the last-displayed marker.
      final scanned = adapter.scanLocal(
        roomId,
        afterEventId: state.lastDisplayedEventId,
      );
      for (final c in scanned) {
        if (seen.add(c.eventId)) candidates.add(c);
      }

      // Sort newest-first so α_i = candidates.last.ts.
      candidates.sort((a, b) => b.ts.compareTo(a.ts));

      pools[roomId] = _RoomPool(
        roomId: roomId,
        candidates: candidates,
        seenEventIds: seen,
        lastDisplayedEventId: state.lastDisplayedEventId,
      );
    }

    return pools;
  }

  /// Computes t_safe = max(α_i) across all rooms that are not exhausted
  /// past the frontier. Returns `null` only if every room is provably
  /// exhausted (no candidates AND canRequestHistory == false).
  DateTime? _computeSafeThreshold(Map<String, _RoomPool> pools) {
    DateTime? maxAlpha;
    for (final pool in pools.values) {
      // A room is exhausted past the frontier iff it has no candidates
      // AND no more server history. Such rooms cannot constrain t_safe.
      if (pool.candidates.isEmpty) {
        if (adapter.canRequestHistory(pool.roomId)) {
          // Unknown room with potentially-newer events — we cannot prove
          // anything, so t_safe = +∞ (no event is safe to display).
          return _positiveInfinity;
        }
        continue; // exhausted, skip
      }
      final alpha = pool.candidates.last.ts;
      if (maxAlpha == null || alpha.isAfter(maxAlpha)) {
        maxAlpha = alpha;
      }
    }
    return maxAlpha;
  }

  /// Extracts all candidates with ts >= tSafe, sorted newest-first, up to
  /// [pageSize].
  List<FeedCandidate> _extractSafePage(
    Map<String, _RoomPool> pools,
    DateTime? tSafe,
  ) {
    if (tSafe == null) {
      // All rooms exhausted with no candidates → empty page.
      return const [];
    }
    if (tSafe == _positiveInfinity) {
      // Some room has unknown state → we can't safely display anything yet.
      return const [];
    }

    final merged = <FeedCandidate>[];
    for (final pool in pools.values) {
      for (final c in pool.candidates) {
        if (!c.ts.isBefore(tSafe)) merged.add(c);
      }
    }
    merged.sort((a, b) => b.ts.compareTo(a.ts));
    if (merged.length > pageSize) return merged.sublist(0, pageSize);
    return merged;
  }

  /// Advances t_safe by loading more history in the blocking room (the one
  /// with the newest α_i). Returns `true` if at least one new candidate was
  /// added, `false` if saturation cannot progress (blocking room exhausted).
  Future<bool> _saturateBlockingRoom(
    Map<String, _RoomPool> pools,
    DateTime? tSafe,
  ) async {
    // Find the blocking room(s): rooms whose α_i equals t_safe and whose
    // history might still advance. In the multi-blocker case, we saturate
    // all blockers in parallel to converge faster.
    if (tSafe == null || tSafe == _positiveInfinity) {
      // Edge case: some rooms have no candidates but canRequestHistory=true.
      // Fetch history for ALL such rooms (in parallel) to seed candidates.
      final seedRoomIds =
          pools.values
              .where((p) => p.candidates.isEmpty)
              .map((p) => p.roomId)
              .where((id) => adapter.canRequestHistory(id))
              .toList();
      if (seedRoomIds.isEmpty) return false;
      return _fetchHistoryParallel(pools, seedRoomIds, targetTs: null);
    }

    // Identify blockers: rooms where α_i == t_safe (tied max).
    final blockers = <String>[];
    for (final pool in pools.values) {
      if (pool.candidates.isEmpty) continue;
      if (pool.candidates.last.ts == tSafe &&
          adapter.canRequestHistory(pool.roomId)) {
        blockers.add(pool.roomId);
      }
    }
    if (blockers.isEmpty) return false;

    // Compute α_2 (second-highest α), the target to advance to.
    DateTime? alpha2;
    for (final pool in pools.values) {
      if (pool.candidates.isEmpty) continue;
      if (blockers.contains(pool.roomId)) continue;
      final alpha = pool.candidates.last.ts;
      if (alpha2 == null || alpha.isAfter(alpha2)) alpha2 = alpha;
    }

    return _fetchHistoryParallel(pools, blockers, targetTs: alpha2);
  }

  /// Fetches more history for each room in [roomIds] concurrently. If
  /// [targetTs] is non-null and the server supports `timestamp_to_event`,
  /// uses the optimized gap-skipping path. Returns `true` if any room
  /// gained new candidates.
  Future<bool> _fetchHistoryParallel(
    Map<String, _RoomPool> pools,
    List<String> roomIds, {
    required DateTime? targetTs,
  }) async {
    final futures = roomIds.map((roomId) {
      return _fetchHistoryForRoom(pools[roomId]!, targetTs: targetTs);
    });
    final results = await Future.wait(futures);
    return results.any((r) => r);
  }

  /// Advances a single room's candidate pool by fetching more history.
  /// Returns `true` if candidates were added.
  Future<bool> _fetchHistoryForRoom(
    _RoomPool pool, {
    required DateTime? targetTs,
  }) async {
    final roomId = pool.roomId;
    final currentAlpha =
        pool.candidates.isEmpty ? null : pool.candidates.last.ts;

    // Decide between timestamp_to_event and plain requestHistory.
    final useTimestampToEvent =
        targetTs != null &&
        currentAlpha != null &&
        adapter.supportsTimestampToEvent(roomId) &&
        currentAlpha.difference(targetTs) > timestampToEventGapThreshold;

    if (useTimestampToEvent) {
      final anchorId = await adapter.findEventByTimestamp(
        roomId,
        targetTs,
        direction: Direction.b,
      );
      if (anchorId == null) {
        // 404 or unsupported → fall back to plain history request.
        final ok = await adapter.requestMoreHistory(
          roomId,
          historyCount: pageSize,
        );
        if (!ok) return false;
      } else {
        // Load events between anchor (exclusive) and current α (exclusive).
        final ok = await adapter.loadEventsBetween(
          roomId,
          anchorId,
          currentAlpha,
        );
        if (!ok) {
          // Fall back to history request.
          final okHist = await adapter.requestMoreHistory(
            roomId,
            historyCount: pageSize,
          );
          if (!okHist) return false;
        }
      }
    } else {
      final ok = await adapter.requestMoreHistory(
        roomId,
        historyCount: pageSize,
      );
      if (!ok) return false;
    }

    // Re-scan to pick up the newly loaded events.
    final scanned = adapter.scanLocal(
      roomId,
      afterEventId: pool.lastDisplayedEventId,
    );
    int added = 0;
    for (final c in scanned) {
      if (pool.seenEventIds.add(c.eventId)) {
        pool.candidates.add(c);
        added++;
      }
    }
    if (added == 0) return false;

    pool.candidates.sort((a, b) => b.ts.compareTo(a.ts));
    return true;
  }

  /// Sentinel value for "unknown tail timestamp" (room may have newer
  /// unseen events). Used internally only.
  static final DateTime _positiveInfinity = DateTime.fromMillisecondsSinceEpoch(
    8640000000000000,
  );
}

/// Internal per-room mutable state during a single paginate() call.
class _RoomPool {
  _RoomPool({
    required this.roomId,
    required this.candidates,
    required this.seenEventIds,
    required this.lastDisplayedEventId,
  });

  final String roomId;
  final List<FeedCandidate> candidates;
  final Set<String> seenEventIds;
  final String? lastDisplayedEventId;
}
