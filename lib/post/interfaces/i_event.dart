import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

// TODO: rename to IEvent
// Abstract widget / interface for comment and post, based on matrix events, therefore the name I(nterface)EventWidget
abstract class IEventWidget extends StatefulWidget {
  const IEventWidget({
    super.key,
    required this.event,
    required this.displayEvent,
    this.timeline,
  }); // displayEvent = event.getDisplayEvent(await timeline), this is mandatory b.c. of https://github.com/flutter/flutter/issues/99158 b.c. of https://web.dev/cls/
  //const PostWidget({super.key, required this.event, required this.timeline});

  // TODO: Extract everything below this point into a separate non-widget class,
  // so we can also retrieve events by event ID without needing a widget context.

  // original event, needed for gathering aggregate events if the event was edited. For gathering threads, comments etc. wich are saved on the original event and not the displayEvent what has the content that should be displayed now, we need therefore both, the original event (this one) and the display event (see below)
  final Event event;
  final Event displayEvent;
  final Timeline? timeline;

  set event(Event e) {
    event = e;
  }

  //final Timeline
  //    timeline; // TODO: Refactore code to use timeline = await event.room.getTimeline(eventContextId: event.eventId);

  //Future<Timeline> get timeline async =>
  //    await event.room.getTimeline(eventContextId: event.eventId);

  // override if needed, f.e. in comments. For querying all comments for one post
  Event get postEvent => event;

  // real Event to display, as edits might have happend
  //Future<Event> get displayEvent async => event.getDisplayEvent(await timeline);

  // Helper methods
  Uri? avatarURL(Event displayEvent) =>
      displayEvent.senderFromMemoryOrFallback.avatarUrl;
  bool hasAvatarURL(Event displayEvent) => avatarURL(displayEvent) != null;
  String username(Event displayEvent) =>
      displayEvent.senderFromMemoryOrFallback.displayName ?? "unknown";

  // get the comments to this event, either RelationshipTypes.thread or RelationshipTypes.comment
  Future<List<({Event origEvent, Event displayEvent})>> get comments async {
    List<({Event origEvent, Event displayEvent})> ret = [];

    final Timeline activeTimeline =
        timeline ?? await event.room.getTimeline(eventContextId: event.eventId);

    for (Event e in postEvent.aggregatedEvents(
      activeTimeline,
      RelationshipTypes.thread,
    )) {
      debugPrint("[comments] checking event ${e.eventId}");

      debugPrint(
        "[comments] contentvaluetry: ${e.content.tryGetMap<String, Object?>('m.relates_to')?.tryGetMap<String, Object?>('m.in_reply_to')?.tryGet<String>('event_id')}",
      );

      if (e.content
              .tryGetMap<String, Object?>('m.relates_to')
              ?.tryGetMap<String, Object?>('m.in_reply_to')
              ?.tryGet<String>('event_id') ==
          event.eventId) {
        // it's only a comment to this comment if it contains the event id of this comments event id
        ret.add((
          origEvent: e,
          displayEvent: e.getDisplayEvent(activeTimeline),
        )); // add the event to our return list
      }
    }

    // remove duplicates by event ID (Set spread doesn't work reliably when
    // getDisplayEvent returns different object instances for the same event)
    final seen = <String>{};
    ret.retainWhere((e) => seen.add(e.origEvent.eventId));
    // sort from new to old by original timestamp so edits don't change position
    ret.sort(
      (a, b) =>
          b.origEvent.originServerTs.compareTo(a.origEvent.originServerTs),
    );

    return ret;
  }
}
