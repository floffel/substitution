import 'package:flutter/foundation.dart' show debugPrint;
import 'package:matrix/matrix.dart';

/// Non-widget view of a Matrix [Event] (and its [Timeline], if known).
///
/// Centralizes the helper logic that used to live on [IEventWidget]
/// (avatar URL, username, comments) so the same code can be used outside
/// a widget tree — for example, from a service that resolves an event
/// by ID and needs to render a preview.
///
/// A widget can either:
/// - hold an [EventView] directly (the modern path), or
/// - extend [IEventWidget], which exposes the same helpers as instance
///   methods that delegate to an internal [EventView] (backward-compat
///   path — see `lib/post/interfaces/i_event.dart`).
class EventView {
  EventView({
    required this.event,
    required this.displayEvent,
    this.timeline,
  });

  /// The original Matrix event (used for aggregating comments, edits,
  /// reactions, etc.).
  final Event event;

  /// The event that should actually be displayed — may differ from
  /// [event] when the event has been edited. The Matrix SDK's
  /// `getDisplayEvent(timeline)` returns this.
  final Event displayEvent;

  /// The timeline this event belongs to, if known. May be `null` —
  /// in that case helpers that need a timeline (e.g. [comments]) will
  /// fetch it lazily from the room.
  final Timeline? timeline;

  /// The event that comments are attached to. Overridden in
  /// [CommentWidget] to point at the parent post; defaults to [event]
  /// (i.e. self).
  Event get postEvent => event;

  // ── Avatar / username helpers ─────────────────────────────────────

  /// mxc:// URI of the sender's avatar, or `null` if unset.
  Uri? avatarURL() => displayEvent.senderFromMemoryOrFallback.avatarUrl;

  /// `true` if the sender has an avatar URL set.
  bool hasAvatarURL() => avatarURL() != null;

  /// Sender's display name, falling back to `"unknown"` when the
  /// sender's profile is not (yet) cached.
  String username() =>
      displayEvent.senderFromMemoryOrFallback.displayName ?? 'unknown';

  // ── Comments ──────────────────────────────────────────────────────

  /// Aggregated comments (threads or replies) for [postEvent].
  ///
  /// Returns the original event + the display event for each comment,
  /// sorted from newest to oldest by `originServerTs` so edits don't
  /// shuffle the visible order.
  Future<List<({Event origEvent, Event displayEvent})>> get comments async {
    final ret = <({Event origEvent, Event displayEvent})>[];

    final activeTimeline =
        timeline ??
        await event.room.getTimeline(eventContextId: event.eventId);

    for (final e in postEvent.aggregatedEvents(
      activeTimeline,
      RelationshipTypes.thread,
    )) {
      debugPrint('[comments] checking event ${e.eventId}');
      debugPrint(
        '[comments] contentvaluetry: '
        '${e.content.tryGetMap<String, Object?>('m.relates_to')?.tryGetMap<String, Object?>('m.in_reply_to')?.tryGet<String>('event_id')}',
      );

      if (e.content
              .tryGetMap<String, Object?>('m.relates_to')
              ?.tryGetMap<String, Object?>('m.in_reply_to')
              ?.tryGet<String>('event_id') ==
          event.eventId) {
        // It's only a comment to this event if it carries the in-reply-to
        // relation pointing back at us.
        ret.add((
          origEvent: e,
          displayEvent: e.getDisplayEvent(activeTimeline),
        ));
      }
    }

    // Deduplicate by eventId — `getDisplayEvent` can return a different
    // object instance for the same event on repeated calls, so a Set
    // spread wouldn't catch them.
    final seen = <String>{};
    ret.retainWhere((e) => seen.add(e.origEvent.eventId));
    ret.sort(
      (a, b) => b.origEvent.originServerTs.compareTo(a.origEvent.originServerTs),
    );

    return ret;
  }
}
