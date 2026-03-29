import '/shared/constants.dart';

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

  late Future<
    Map<
      String,
      ({List<String> userNames, bool isOwnSmiley, Event? displayEvent})
    >
  >
  _reactionsFuture;

  @override
  void initState() {
    super.initState();
    _reactionsFuture = _loadReactions();
  }

  Future<
    Map<
      String,
      ({List<String> userNames, bool isOwnSmiley, Event? displayEvent})
    >
  >
  _loadReactions() async {
    Map<
      String,
      ({List<String> userNames, bool isOwnSmiley, Event? displayEvent})
    >
    ret = {};

    Timeline timeline = await widget.event.room.getTimeline(
      eventContextId: widget.event.eventId,
    );

    Set<Event> events = widget.event.aggregatedEvents(
      timeline,
      RelationshipTypes.reaction,
    );

    for (Event e in events) {
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
            sender.displayName ?? "post.widget.reactions.unknown_sender".tr(),
          ],
          isOwnSmiley: isOwnSmiley,
          displayEvent: isOwnSmiley ? displayEvent : null,
        );
      }
    }

    return ret;
  }

  void refresh() {
    setState(() {
      _reactionsFuture = _loadReactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _reactionsFuture,
      builder: (ctx, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        return Wrap(
          spacing: 1.0,
          runSpacing: 4.0,
          children: [
            ...snapshot.data?.entries.map((var e) {
                  return Tooltip(
                    message: "post.widgets.reaction.sent_by".tr(
                      args: [e.value.userNames.join(', ')],
                    ),
                    child: GestureDetector(
                      onLongPress: () {
                        if (e.value.displayEvent != null) {
                          e.value.displayEvent!.redactEvent();
                          refresh();
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2.0),
                        decoration:
                            e.value.isOwnSmiley
                                ? BoxDecoration(
                                  border: Border.all(color: Colors.red[400]!),
                                  shape: BoxShape.circle,
                                )
                                : null,
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 24.0,
                            fontFamily: AppConstants.defaultEmojiFontFamily,

                            fontFamilyFallback: ["Noto Emoji"],
                          ),
                        ),
                      ),
                    ),
                  );
                }) ??
                [],
          ],
        );
      },
    );
  }
}
