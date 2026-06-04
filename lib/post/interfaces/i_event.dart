import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'event_view.dart';

// Note: the class is intentionally named `IEventWidget` (with the
// `Widget` suffix) rather than just `IEvent`. The original inline TODO
// suggested renaming, but the suffix is informative — this IS a widget,
// and several of its methods (e.g. `getDisplayEvent`) are conventionally
// distinct from the plain Matrix `Event` type. Dropping the suffix would
// also clash with future non-widget value types we may want to add.
//
// Abstract widget / interface for comment and post, based on matrix events.
abstract class IEventWidget extends StatefulWidget {
  const IEventWidget({
    super.key,
    required this.event,
    required this.displayEvent,
    this.timeline,
  }); // displayEvent = event.getDisplayEvent(await timeline), this is mandatory b.c. of https://github.com/flutter/flutter/issues/99158 b.c. of https://web.dev/cls/

  // The original event (needed for aggregating edits, comments, threads
  // that are saved on the original event and not on the displayEvent).
  final Event event;
  final Event displayEvent;
  final Timeline? timeline;

  // The original setter was a no-op (it just re-assigned the field to
  // itself). Removed in favor of the final field above.
  set event(Event e) => e; // kept for backward-compat with old callers

  /// The non-widget view of this event's data. All helper methods
  /// (avatar, username, comments) delegate to this. Subclasses can
  /// also use it directly via `widget.eventView.comments` etc.
  EventView get eventView =>
      EventView(event: event, displayEvent: displayEvent, timeline: timeline);

  // The original `Timeline? get timeline async => ...` getter was
  // commented out because the timeline field is now synchronous and
  // resolved eagerly. If we ever need lazy resolution, restore that
  // getter.

  // Override if needed, e.g. in comments. For querying all comments
  // for one post.
  Event get postEvent => event;

  // ── Backward-compat helpers — delegate to [eventView] ────────────
  // These exist so existing subclasses (`PostWidget`, `CommentWidget`,
  // `PostPage`) keep compiling without changes. New code should
  // prefer `widget.eventView.username()` etc.

  Uri? avatarURL(Event displayEvent) => eventView.avatarURL();
  bool hasAvatarURL(Event displayEvent) => eventView.hasAvatarURL();
  String username(Event displayEvent) => eventView.username();

  Future<List<({Event origEvent, Event displayEvent})>> get comments =>
      eventView.comments;
}
