import 'package:flutter/material.dart';
import 'package:substitution/post/widgets/filecomponent.dart';

import 'package:matrix/matrix.dart';

import 'package:provider/provider.dart';
import 'package:substitution/post/interfaces/ievent.dart';

import 'package:go_router/go_router.dart';

import 'package:flutter_html/flutter_html.dart';

import 'package:substitution/post/widgets/reactionscomponent.dart';

import 'package:substitution/post/mixins/iconpicker.dart';

// like post but smaller
class CommentWidget extends IEventWidget {
  const CommentWidget(
      {super.key,
      required super.event,
      required super.displayEvent,
      required this.postEvent});

  // "original" event of the post, for querying replys. Timeline is the same, so we don't need an additional postTimeline
  @override
  final Event postEvent;

  @override
  CommentWidgetState createState() => CommentWidgetState();
}

class CommentWidgetState extends State<CommentWidget> with IconPicker {
  Client get client => Provider.of<Client>(context, listen: false);

  bool showComment = true;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(16.0),
        decoration: !showComment
            ? BoxDecoration(
                color: Colors.grey[100]!,
              )
            : null,
        child: Column(children: [
          GestureDetector(
              onTap: () => setState(() {
                    showComment = !showComment;
                  }), //Navigator.of(context, rootNavigator: true).pushNamed('/post/', arguments: (fes.$1, fes.$2)),
              child: Row(children: [
                widget.hasAvatarURL(widget
                        .displayEvent) // TODO: refactor to hasAvatarURL be a get
                    ? Image.network(
                        width: 40,
                        height: 40,
                        widget
                            .avatarURL(widget
                                .displayEvent)! // TODO: refactor to avatarURL be a get
                            .getDownloadLink(client)
                            .toString())
                    : CircleAvatar(
                        child: Text(widget.username(widget.displayEvent)[
                            0])), // // TODO: refactor to username be a get
                Expanded(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(widget.username(widget.displayEvent)))),
                IconButton(
                  onPressed: () async => {
                    context.push(Uri(
                            path: "/write/${widget.event.roomId}",
                            queryParameters: {'event': widget.event.eventId})
                        .toString())
                  },
                  icon: const Icon(Icons.reply),
                ),
                IconButton(
                  onPressed: () async => await pickIcon(context, widget.event,
                      postEvent: widget.postEvent),
                  icon: const Icon(Icons.favorite_rounded),
                )
              ])),
          if (showComment) ...[
            GestureDetector(
              onTap: () => setState(() {
                showComment = !showComment;
              }), //Navigator.of(context, rootNavigator: true).pushNamed('/post/', arguments: (fes.$1, fes.$2)),
              child: (widget.displayEvent).messageType == MessageTypes.Text
                  ? Row(children: [
                      Expanded(
                          child: Html(
                              data:
                                  (widget.displayEvent).formattedText.isNotEmpty
                                      ? (widget.displayEvent).formattedText
                                      : (widget.displayEvent).body))
                    ])
                  : FileComponent(
                      event: widget.event, displayEvent: widget.displayEvent),
            ),

            // Comments
            Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(width: 1.0, color: Color(0xFFBFBFBF)),
                  ),
                ),
                child: FutureBuilder(
                    future: widget.comments,
                    builder: (ctx, snapshot) {
                      return /* Expanded( child:*/ Column(
                          children: ListTile.divideTiles(
                              context: context,
                              tiles: <Widget>[
                            ...snapshot.data?.map((var e) {
                                  return CommentWidget(
                                      event: e.origEvent,
                                      displayEvent: e.displayEvent,
                                      postEvent: widget.postEvent);
                                }) ??
                                []
                          ]).toList());
                    })),

            ReactionsComponent(event: widget.event)
          ]
        ]));
  }
}
