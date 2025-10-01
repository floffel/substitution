import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

// TODO rename to ReactionsDisplay or smthg.
class ReactionsComponent extends StatefulWidget {
  const ReactionsComponent({super.key, required this.event});

  final Event event;

  @override
  ReactionsComponentState createState() => ReactionsComponentState();
}

class ReactionsComponentState extends State<ReactionsComponent> {
  Client get client => Provider.of<Client>(context, listen: false);

  //int numReactions = 0;

  // Map: (String smileyString, meta)
  Future<
      Map<
          String,
          ({
            List<String> userNames,
            bool isOwnSmiley,
            Event? displayEvent
          })>> get reactions async {
    print("start getting reactions");

    Map<String,
            ({List<String> userNames, bool isOwnSmiley, Event? displayEvent})>
        ret = {};

    Timeline timeline = await widget.event.room
        .getTimeline(eventContextId: widget.event.eventId);
    // TODO: we need to transfere the timeline from the previous
    //  component

    print("got timeline for event id");
    print(widget.event.eventId);
    print("has aggregated events?");
    print(
        widget.event.hasAggregatedEvents(timeline, RelationshipTypes.reaction));

    Set<Event> events =
        widget.event.aggregatedEvents(timeline, RelationshipTypes.reaction);

    print("got events");
    print(events);

    for (Event e in events) {
      // it's only a comment to this comment if it contains the event id of this comments event id

      print("checking event e:");
      print(e);

      if (e.content
              .tryGetMap<String, Object?>('m.relates_to')
              ?.tryGet<String>('event_id') ==
          widget.event.eventId) {
        Event displayEvent = e.getDisplayEvent(timeline);
        String smiley =
            displayEvent.content.tryGet<Map>('m.relates_to')?['key'] ?? '�';
        User sender = displayEvent.senderFromMemoryOrFallback;
        bool isOwnSmiley = false;

        if (client.userID == sender.id) {
          isOwnSmiley = true;
        }

        print("fetched smiley!");

        ret[smiley] = (
          userNames: [
            ...(ret[smiley]?.userNames ?? []),
            sender.displayName ?? "post.widget.reactions.unknown_sender".tr()
          ],
          isOwnSmiley: isOwnSmiley,
          displayEvent: isOwnSmiley ? displayEvent : null
        );
      }
    }

    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: reactions,
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return Text("loading comments");
          }
          // todo: show loading animation!
          return Wrap(spacing: 1.0, runSpacing: 4.0, children: [
            ...snapshot.data?.entries.map((var e) {
                  return Tooltip(
                      message: "post.widgets.reaction.sent_by"
                          .tr(args: [e.value.userNames.join(', ')]),
                      child: GestureDetector(
                          onLongPress: () {
                            if (e.value.displayEvent != null) {
                              e.value.displayEvent!.redactEvent();
                              setState(() {});
                            }
                          },
                          child: Container(
                              margin: const EdgeInsets.all(2.0),
                              decoration: e.value.isOwnSmiley
                                  ? BoxDecoration(
                                      border:
                                          Border.all(color: Colors.red[400]!),
                                      shape: BoxShape.circle)
                                  : null,
                              // TODO: extra farbe geben wenn e.value ist der eingeloggte benutzer
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                  fontSize: 24.0,
                                  fontFamily:
                                      'Apple Color Emoji', // TODO: Investigate what to use on other platforms
                                  fontFamilyFallback: ["Noto Emoji"],
                                ),
                              ))));
                }) ??
                []
          ]);
        });
  }
}
