import 'package:matrix/matrix.dart';

/// A single post candidate in the feed, pairing the original event with its
/// currently-displayed form (the latest edit, if any).
///
/// We sort by [origEvent.originServerTs] so that editing a post does not
/// change its position in the feed.
class FeedCandidate {
  const FeedCandidate({required this.origEvent, required this.displayEvent});

  /// The original event. Its [originServerTs] is the canonical sort key.
  final Event origEvent;

  /// The event to render (may be an edit aggregate of [origEvent]).
  final Event displayEvent;

  String get eventId => origEvent.eventId;
  String get roomId => origEvent.roomId ?? origEvent.room.id;
  DateTime get ts => origEvent.originServerTs;
}

/// Per-room pagination state carried across page fetches.
class RoomPageState {
  const RoomPageState({this.lastDisplayedEventId, this.exhausted = false});

  /// The event ID of the last (oldest) event from this room that has been
  /// **displayed** (returned in a page). Used as a start marker when
  /// re-scanning the timeline on the next page. Deliberately tracks the
  /// last *displayed* (not last *scanned*) event so that if carry-forward
  /// candidates are lost (e.g. widget dispose/recreate), events can be
  /// re-discovered on the next scan instead of being permanently skipped.
  final String? lastDisplayedEventId;

  /// Whether this room has no more history to fetch from the server AND
  /// no carry-forward candidates remaining.
  final bool exhausted;

  RoomPageState copyWith({String? lastDisplayedEventId, bool? exhausted}) =>
      RoomPageState(
        lastDisplayedEventId: lastDisplayedEventId ?? this.lastDisplayedEventId,
        exhausted: exhausted ?? this.exhausted,
      );
}

/// The opaque key that identifies a page. Room IDs are kept as strings
/// (not Timeline objects) so the key survives widget lifecycle changes.
typedef PageKey = Map<String, RoomPageState>;

/// The result of fetching a single page.
class PageResult {
  const PageResult({
    required this.events,
    required this.nextKey,
    required this.carryForward,
    required this.frontier,
  });

  /// The ordered list of candidates to display (newest first).
  final List<FeedCandidate> events;

  /// The key to use for the next page fetch. `null` means all rooms are
  /// exhausted and pagination should stop.
  final PageKey? nextKey;

  /// Candidates that were loaded but didn't make it into [events] this page.
  /// Keyed by room ID. Passed back into the next fetch to avoid re-loading.
  final Map<String, List<FeedCandidate>> carryForward;

  /// The safe threshold timestamp used for this page: every displayed event
  /// has [FeedCandidate.ts] >= [frontier]. Used by the caller to decide
  /// frontier-aware loading on subsequent pages.
  final DateTime? frontier;

  bool get isTerminal => nextKey == null || nextKey!.isEmpty;
}
