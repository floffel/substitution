import '/post/interfaces/i_event.dart';
import '/post/widgets/display/file_display_container.dart';
import '/post/widgets/display/reactions_display.dart';
import '/post/mixins/iconpicker.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PostWidget extends IEventWidget {
  const PostWidget(
      {super.key, required super.event, required super.displayEvent});

  @override
  PostWidgetState createState() => PostWidgetState();
}

class PostWidgetState extends State<PostWidget> with IconPicker {
  Client get client => Provider.of<Client>(context, listen: false);

  String get roomAddr => (widget.displayEvent).room.canonicalAlias.isEmpty
      ? (widget.displayEvent).room.id
      : (widget.displayEvent).room.canonicalAlias;

  // TODO: use PagedListView for loading more comments
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: GestureDetector(
                      onTap: () => setState(() {
                            context
                                .push('/feed/${roomAddr.replaceAll('#', '')}');
                          }),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () {
                            final userId = widget.displayEvent.senderId;
                            context.push(
                                '/profile/${Uri.encodeComponent(userId)}');
                          },
                          child: widget.hasAvatarURL((widget.displayEvent))
                              ? Image.network(
                                  widget
                                      .avatarURL((widget.displayEvent))!
                                      .getDownloadUri(client)
                                      .toString(),
                                  width: 40,
                                  height: 40, errorBuilder: (ctx, obj, stack) {
                                  // todo: find a way to check if we have a svg beforehand!
                                  return SvgPicture.network(
                                    widget
                                        .avatarURL((widget.displayEvent))!
                                        .getDownloadUri(client)
                                        .toString(),
                                    width: 40,
                                    height: 40,
                                  );
                                })
                              : CircleAvatar(
                                  child: Text(
                                      widget.username(widget.displayEvent)[0])),
                        ),
                        Expanded(
                            child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(children: [
                                  Text(widget.username((widget.displayEvent))),
                                  Text(
                                      "$roomAddr: ${(widget.displayEvent).room.name}"),
                                ]))),
                      ]))),
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
                onPressed: () async => await pickIcon(context, widget.event),
                icon: const Icon(Icons.favorite_rounded),
              ),
            ]),
            (widget.displayEvent).messageType == MessageTypes.Text
                ? Row(children: [
                    Expanded(
                        child: Html(
                            data: (widget.displayEvent).formattedText.isNotEmpty
                                ? (widget.displayEvent).formattedText
                                : (widget.displayEvent).body))
                  ])
                : FileDisplayContainer(
                    event: widget.event, displayEvent: widget.displayEvent),
            ReactionsDisplay(event: widget.event)
          ]))
    ]);
  }
}
