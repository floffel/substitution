import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

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
  Future<Map<String, ({List<String> userNames, bool isOwnSmiley})>>
      get reactions async {
    Map<String, ({List<String> userNames, bool isOwnSmiley})> ret = {};
    String eventId = widget.event.eventId;
    String roomId = widget.event.room.id;

    final response = await client.getRelatingEventsWithRelType(
      roomId,
      eventId,
      RelationshipTypes.reaction,
      // eventType: EventTypes.Reaction, // Using EventTypes.Reaction for specificity - REMOVED due to API change
      // limit: 100, // Default limit should be fine for reactions, but can be adjusted if needed
      dir: Direction.f, // Fetching forward, typical for reactions
    );

    // The events are in response.chunk
    for (Event e in response.chunk) {
      // The event 'e' here is a reaction event itself.
      // The smiley key is directly in e.content['m.relates_to']['key']
      String? smiley = e.content
          .tryGetMap<String, Object?>('m.relates_to')
          ?.tryGet<String>('key');
      if (smiley == null || smiley.isEmpty) {
        smiley = '�'; // Default smiley if key is not found or empty
      }

      User sender = e.senderFromMemoryOrFallback; // Reaction sender
      bool isOwnSmiley = (client.userID == sender.id);

      ret[smiley] = (
        userNames: [
          ...(ret[smiley]?.userNames ?? []),
          sender.displayName ?? "post.widget.reactions.unknown_sender".tr()
        ],
        isOwnSmiley: isOwnSmiley || (ret[smiley]?.isOwnSmiley ?? false) // if multiple reactions with same smiley, keep isOwnSmiley true if one of them is own
      );
    }
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
                      message: "post.widgets.reaction.sent_by"
                          .tr(args: [e.value.userNames.join(', ')]),
                      child: Container(
                          margin: const EdgeInsets.all(2.0),
                          decoration: e.value.isOwnSmiley
                              ? BoxDecoration(
                                  border: Border.all(color: Colors.red[400]!),
                                  shape: BoxShape.circle)
                              : null,
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
