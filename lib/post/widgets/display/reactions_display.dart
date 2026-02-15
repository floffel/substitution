import '/shared/constants.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

// TODO rename to ReactionsDisplay or smthg.
class ReactionsDisplay extends StatefulWidget {
  const ReactionsDisplay({super.key, required this.event});

  final Event event;

  @override
  ReactionsDisplayState createState() => ReactionsDisplayState();
}

class ReactionsDisplayState extends State<ReactionsDisplay> {
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
    debugPrint("start getting reactions");

    Map<String,
            ({List<String> userNames, bool isOwnSmiley, Event? displayEvent})>
        ret = {};

    Timeline timeline = await widget.event.room
        .getTimeline(eventContextId: widget.event.eventId);
    // TODO: we need to transfere the timeline from the previous
    //  component

    debugPrint("got timeline for event id");
    debugPrint(widget.event.eventId);
    debugPrint("has aggregated events?");
    debugPrint(
        widget.event.hasAggregatedEvents(timeline, RelationshipTypes.reaction).toString());

    Set<Event> events =
        widget.event.aggregatedEvents(timeline, RelationshipTypes.reaction);

    debugPrint("got events");
    debugPrint(events.toString());

    for (Event e in events) {
      // it's only a comment to this comment if it contains the event id of this comments event id

      debugPrint("checking event e:");
      debugPrint(e.toString());

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

        debugPrint("fetched smiley!");

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
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator()));
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
                                                                        fontFamily: AppConstants.defaultEmojiFontFamily,
                                  
                                  fontFamilyFallback: ["Noto Emoji"],
                                ),
                              ))));
                }) ??
                []
          ]);
        });
  }
}
