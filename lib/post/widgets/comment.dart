import '/post/widgets/display/file_display_container.dart';
import '/post/widgets/display/reactions_display.dart';
import '/post/mixins/iconpicker.dart';
import '/post/interfaces/i_event.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';

// like post but smaller
class CommentWidget extends IEventWidget {
  const CommentWidget({
    super.key,
    required super.event,
    required super.displayEvent,
    required this.postEvent,
    this.depth = 0,
  });

  // "original" event of the post, for querying replys. Timeline is the same, so we don't need an additional postTimeline
  @override
  final Event postEvent;

  final int depth;

  @override
  CommentWidgetState createState() => CommentWidgetState();
}

class CommentWidgetState extends State<CommentWidget> with IconPicker {
  Client get client => Provider.of<Client>(context, listen: false);

  bool showComment = true;

  static const int maxDepth = 3;

  @override
  Widget build(BuildContext context) {
    // Return standard visual padding.
    // Left padding provides the indentation tree effect.
    final double leftPad = widget.depth == 0 ? 16.0 : 12.0;
    final double rightPad = widget.depth == 0 ? 16.0 : 4.0;

    // TODO: a lot is duplicated from post.dart. Would be nice to have it in one widget or extend one or so...
    return Container(
      padding: EdgeInsets.fromLTRB(leftPad, 8.0, rightPad, 8.0),
      decoration: !showComment ? BoxDecoration(color: Colors.grey[100]!) : null,
      child: Column(
        children: [
          GestureDetector(
            onTap:
                () => setState(() {
                  showComment = !showComment;
                }),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final userId = widget.displayEvent.senderId;
                    context.push('/profile/${Uri.encodeComponent(userId)}');
                  },
                  child:
                      widget.hasAvatarURL(
                            widget.displayEvent,
                          ) // TODO: refactor to hasAvatarURL be a get
                          ? Image.network(
                            widget
                                .avatarURL((widget.displayEvent))!
                                .getDownloadUri(client)
                                .toString(),
                            width: 40,
                            height: 40,
                            errorBuilder: (ctx, obj, stack) {
                              // todo: find a way to check if we have a svg beforehand!
                              return SvgPicture.network(
                                widget
                                    .avatarURL((widget.displayEvent))!
                                    .getDownloadUri(client)
                                    .toString(),
                                width: 40,
                                height: 40,
                              );
                            },
                          )
                          : CircleAvatar(
                            child: Text(
                              widget.username(widget.displayEvent)[0],
                            ),
                          ), // // TODO: refactor to username be a get
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(widget.username(widget.displayEvent)),
                  ),
                ),
                IconButton(
                  onPressed:
                      () async => {
                        context.push(
                          Uri(
                            path: "/write/${widget.event.roomId}",
                            queryParameters: {'event': widget.event.eventId},
                          ).toString(),
                        ),
                      },
                  icon: const Icon(Icons.reply),
                ),
                IconButton(
                  onPressed:
                      () async => await pickIcon(
                        context,
                        widget.event,
                        postEvent: widget.postEvent,
                      ),
                  icon: const Icon(Icons.favorite_rounded),
                ),
              ],
            ),
          ),
          if (showComment) ...[
            GestureDetector(
              onTap:
                  () => setState(() {
                    showComment = !showComment;
                  }),
              child:
                  (widget.displayEvent).messageType == MessageTypes.Text
                      ? Row(
                        children: [
                          Expanded(
                            child: Html(
                              data:
                                  (widget.displayEvent).formattedText.isNotEmpty
                                      ? (widget.displayEvent).formattedText
                                      : (widget.displayEvent).body,
                            ),
                          ),
                        ],
                      )
                      : FileDisplayContainer(
                        event: widget.event,
                        displayEvent: widget.displayEvent,
                      ),
            ),

            // Comments – if we've reached max depth, show a "continue thread" button instead of loading more children
            if (widget.depth >= CommentWidgetState.maxDepth)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton.icon(
                  onPressed: () {
                    GoRouter.of(context).push(
                      '/post/${widget.event.eventId}?room=${widget.event.roomId}',
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('post.continue_thread'.tr()),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(width: 1.0, color: Color(0xFFBFBFBF)),
                  ),
                ),
                child: FutureBuilder(
                  future: widget.comments,
                  builder: (ctx, snapshot) {
                    return Column(
                      children:
                          ListTile.divideTiles(
                            context: context,
                            tiles: <Widget>[
                              ...snapshot.data?.map((e) {
                                    return CommentWidget(
                                      event: e.origEvent,
                                      displayEvent: e.displayEvent,
                                      postEvent: widget.postEvent,
                                      depth: widget.depth + 1,
                                    );
                                  }).toList() ??
                                  [],
                            ],
                          ).toList(),
                    );
                  },
                ),
              ),

            ReactionsDisplay(event: widget.event),
          ],
        ],
      ),
    );
  }
}
