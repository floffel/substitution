import 'package:matrix/matrix.dart';

import 'feed_candidate.dart';

/// Abstraction over the Matrix SDK for a single room's timeline operations.
///
/// This interface exists so [FeedPaginator] can be unit-tested with in-memory
/// fixtures without a real Matrix client. The production implementation
/// (MatrixRoomTimelineAdapter) wraps a [Timeline] object.
///
/// All methods MUST be safe to call concurrently for different room IDs
/// (the paginator uses Future.wait to parallelize saturation).
abstract class RoomTimelineAdapter {
  /// The IDs of all rooms currently visible in the feed.
  Set<String> get roomIds;

  /// Scans the room's locally-known events (in-memory + DB cache) for feed
  /// candidates (messages that aren't replies/threads/edits and whose sender
  /// is allowed to post in the room).
  ///
  /// When [afterEventId] is non-null, the scan starts *after* that event in
  /// the timeline (i.e. only returns events older than it). This lets the
  /// paginator resume from where it left off on the previous page.
  ///
  /// The returned list is ordered newest-first.
  List<FeedCandidate> scanLocal(String roomId, {String? afterEventId});

  /// Requests more history from the server for [roomId]. Returns `true` if
  /// at least one new event was added to the local timeline, `false` if the
  /// server has no more events (or the request failed).
  ///
  /// The [historyCount] parameter is a *hint* — the server may return fewer.
  Future<bool> requestMoreHistory(String roomId, {int historyCount = 20});

  /// Returns `true` if the server might still have more history for [roomId].
  /// When `false`, [requestMoreHistory] should not be called.
  bool canRequestHistory(String roomId);

  /// Uses the Matrix v1.6 `GET /rooms/{roomId}/timestamp_to_event` endpoint
  /// to find the event closest to [ts] in direction [direction].
  ///
  /// Returns the event ID, or `null` if:
  ///   - the server does not support this endpoint, OR
  ///   - no event exists at/before [ts] (404 response), OR
  ///   - the request was rate-limited and retries were exhausted.
  ///
  /// After this call, the returned event (if any) MUST be present in the
  /// room's local timeline (the adapter is responsible for loading it).
  Future<String?> findEventByTimestamp(
    String roomId,
    DateTime ts, {
    Direction direction = Direction.b,
  });

  /// Whether the room's homeserver supports `timestamp_to_event` (v1.6+).
  bool supportsTimestampToEvent(String roomId);

  /// Loads events between the anchor event (exclusive) and a given timestamp
  /// (inclusive) in the forward direction (toward newer). Returns `true` if
  /// at least one event was loaded.
  Future<bool> loadEventsBetween(
    String roomId,
    String anchorEventId,
    DateTime untilTs,
  );
}
