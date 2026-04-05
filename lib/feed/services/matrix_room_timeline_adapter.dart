import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

import '/shared/services/matrix_server_capabilities.dart';
import 'feed_candidate.dart';
import 'room_timeline_adapter.dart';

/// Production [RoomTimelineAdapter] backed by the Matrix SDK.
///
/// Responsibilities:
/// - Expose each room's [Timeline] for local scanning.
/// - Wrap `requestHistory` with mount-guard handling.
/// - Call `getEventByTimestamp` (Matrix v1.6+) with rate-limit retries.
/// - Surface support detection via [MatrixServerCapabilities].
///
/// One adapter instance corresponds to the current set of rooms the feed is
/// displaying. If the room set changes (e.g. user joins/leaves), build a
/// new adapter.
class MatrixRoomTimelineAdapter implements RoomTimelineAdapter {
  MatrixRoomTimelineAdapter({
    required this.client,
    required this.timelines,
    required this.capabilities,
    this.visibilityFilter,
    this.isMounted,
  });

  final Client client;

  /// Map of room ID → Timeline. The adapter does NOT own these — they're
  /// provided by [HomePage] and disposed there.
  final Map<String, Timeline> timelines;

  final MatrixServerCapabilities capabilities;

  /// Predicate deciding whether an event is visible in the feed (power-level
  /// gating for blog-mode rooms). If null, all message events are visible.
  final bool Function(Event event)? visibilityFilter;

  /// Optional liveness check — returns `false` when the owning widget has
  /// been disposed. Used to abort long-running async work.
  final bool Function()? isMounted;

  bool get _mounted => isMounted?.call() ?? true;

  @override
  Set<String> get roomIds => timelines.keys.toSet();

  @override
  List<FeedCandidate> scanLocal(String roomId, {String? afterEventId}) {
    final timeline = timelines[roomId];
    if (timeline == null) return const [];

    int startIndex = 0;
    if (afterEventId != null) {
      final idx = timeline.events.indexWhere((e) => e.eventId == afterEventId);
      if (idx >= 0) startIndex = idx + 1;
    }

    final out = <FeedCandidate>[];
    for (int i = startIndex; i < timeline.events.length; i++) {
      final e = timeline.events[i];
      if (!_isFeedPost(e)) continue;
      if (visibilityFilter != null && !visibilityFilter!(e)) continue;
      out.add(
        FeedCandidate(origEvent: e, displayEvent: e.getDisplayEvent(timeline)),
      );
    }
    return out;
  }

  static bool _isFeedPost(Event e) {
    if (e.type != EventTypes.Message) return false;
    final r = e.relationshipType;
    if (r == RelationshipTypes.reference) return false;
    if (r == RelationshipTypes.thread) return false;
    if (r == RelationshipTypes.edit) return false;
    return true;
  }

  @override
  Future<bool> requestMoreHistory(
    String roomId, {
    int historyCount = 20,
  }) async {
    final timeline = timelines[roomId];
    if (timeline == null) return false;
    if (!timeline.canRequestHistory) return false;

    final before = timeline.events.length;
    try {
      await timeline.requestHistory(historyCount: historyCount);
    } catch (e) {
      debugPrint('MatrixRoomTimelineAdapter.requestMoreHistory($roomId): $e');
      return false;
    }
    if (!_mounted) return false;
    return timeline.events.length > before;
  }

  @override
  bool canRequestHistory(String roomId) {
    final timeline = timelines[roomId];
    if (timeline == null) return false;
    return timeline.canRequestHistory;
  }

  @override
  bool supportsTimestampToEvent(String roomId) =>
      capabilities.supportsTimestampToEvent;

  /// Upper bound on rate-limit retries for a single `timestamp_to_event`
  /// call. After this many retries the call gives up and returns null so
  /// the paginator can fall back to plain `requestHistory`.
  static const int _maxRateLimitRetries = 3;

  @override
  Future<String?> findEventByTimestamp(
    String roomId,
    DateTime ts, {
    Direction direction = Direction.b,
  }) async {
    if (!capabilities.supportsTimestampToEvent) return null;

    final tsMs = ts.millisecondsSinceEpoch;
    var delayMs = 500;
    for (int attempt = 0; attempt < _maxRateLimitRetries; attempt++) {
      try {
        final resp = await client.getEventByTimestamp(roomId, tsMs, direction);
        if (!_mounted) return null;
        return resp.eventId;
      } on MatrixException catch (e) {
        if (e.errcode == 'M_NOT_FOUND') {
          // No event at/before ts in this room. Definitive answer.
          return null;
        }
        if (e.errcode == 'M_LIMIT_EXCEEDED') {
          final retryAfter = e.retryAfterMs ?? delayMs;
          debugPrint(
            'findEventByTimestamp($roomId): rate-limited, '
            'waiting ${retryAfter}ms (attempt ${attempt + 1})',
          );
          await Future.delayed(Duration(milliseconds: retryAfter));
          delayMs *= 2;
          continue;
        }
        debugPrint('findEventByTimestamp($roomId) failed: $e');
        return null;
      } catch (e) {
        debugPrint('findEventByTimestamp($roomId) unexpected: $e');
        return null;
      }
    }
    return null;
  }

  @override
  Future<bool> loadEventsBetween(
    String roomId,
    String anchorEventId,
    DateTime untilTs,
  ) async {
    final timeline = timelines[roomId];
    if (timeline == null) return false;

    // If the anchor is already in the timeline, we just need to keep
    // requesting history until the timeline extends at least to the
    // anchor's position. In practice the anchor is typically NOT yet in
    // the local timeline (otherwise we wouldn't have needed to find it),
    // so we issue a few requestHistory calls to pull it in.
    bool anchorPresent() =>
        timeline.events.any((e) => e.eventId == anchorEventId);

    if (anchorPresent()) return true;

    // Pull history in chunks until we encounter the anchor or exhaust.
    int calls = 0;
    const maxCalls = 3;
    while (calls < maxCalls && timeline.canRequestHistory && _mounted) {
      final before = timeline.events.length;
      try {
        await timeline.requestHistory(historyCount: 30);
      } catch (e) {
        debugPrint('loadEventsBetween($roomId): requestHistory failed: $e');
        return false;
      }
      if (!_mounted) return false;
      if (timeline.events.length <= before) break; // server exhausted
      if (anchorPresent()) return true;
      // Optional early exit: if we've already gone BEFORE the anchor's
      // timestamp in wall-clock terms, stop — anchor isn't in this
      // room's history (may have been redacted or unreadable).
      final oldestTs = timeline.events.last.originServerTs;
      if (oldestTs.isBefore(untilTs) &&
          oldestTs.isBefore(
            DateTime.fromMillisecondsSinceEpoch(
              untilTs.millisecondsSinceEpoch -
                  const Duration(days: 1).inMilliseconds,
            ),
          )) {
        break;
      }
      calls++;
    }

    // Whether we found the anchor or not, we loaded SOME events, which
    // advances the room's α. Return true if we made any progress.
    return true;
  }
}
