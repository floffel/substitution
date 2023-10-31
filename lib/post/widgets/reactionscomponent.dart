import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

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
  Future<Map<String, ({List<String> userNames, bool isOwnSmiley})>>
      get reactions async {
    Map<String, ({List<String> userNames, bool isOwnSmiley})> ret = {};

    Timeline timeline = await widget.event.room
        .getTimeline(eventContextId: widget.event.eventId);

    for (Event e in widget.event
        .aggregatedEvents(timeline, RelationshipTypes.reaction)) {
      // it's only a comment to this comment if it contains the event id of this comments event id

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

        ret[smiley] = (
          userNames: [
            ...(ret[smiley]?.userNames ?? []),
            sender.displayName ?? 'unknown'
          ],
          isOwnSmiley: isOwnSmiley
        );
      }
    }

    // TODO: set the length so we can prevent scrolling issues when scrolling up with the sized box
    /*setState((){
      numReactions = ret.length;      
    });*/

    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: reactions,
        builder: (ctx, snapshot) {
          return Wrap(spacing: 1.0, runSpacing: 4.0, children: [
            ...snapshot.data?.entries.map((var e) {
                  return Tooltip(
                      message:
                          "send by ${e.value.userNames.join(', ')}", // todo int
                      child: Container(
                          margin: const EdgeInsets.all(2.0),
                          decoration: e.value.isOwnSmiley
                              ? BoxDecoration(
                                  border: Border.all(color: Colors.red[400]!),
                                  shape: BoxShape.circle)
                              : null,
                          // TODO: extra farbe geben wenn e.value ist der eingeloggte benutzer
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 24.0,
                              fontFamily:
                                  'Apple Color Emoji', // Investigate what to use on other platforms
                              fontFamilyFallback: ["Noto Emoji"],
                            ),
                          )));
                }) ??
                []
          ]);
        });
  }
}
