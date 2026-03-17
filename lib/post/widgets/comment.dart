import '/post/widgets/display/file_display_container.dart';
import '/post/widgets/display/reactions_display.dart';
import '/post/mixins/iconpicker.dart';
import '/post/interfaces/i_event.dart';
import '/shared/utils/relative_time.dart';
import '/shared/extensions/go_router_extensions.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';

/// Callback signature for when a user taps reply on a comment.
/// [event] is the comment event being replied to, [username] is the display name.
typedef OnReplyCallback = void Function(Event event, String username);

// like post but smaller
class CommentWidget extends IEventWidget {
  const CommentWidget({
    super.key,
    required super.event,
    required super.displayEvent,
    required this.postEvent,
    this.depth = 0,
    this.onReply,
  });

  // "original" event of the post, for querying replys. Timeline is the same, so we don't need an additional postTimeline
  @override
  final Event postEvent;

  final int depth;

  /// Called when the user taps the reply button on this comment.
  /// If null, the reply button navigates to the write page instead.
  final OnReplyCallback? onReply;

  @override
  CommentWidgetState createState() => CommentWidgetState();
}

class CommentWidgetState extends State<CommentWidget> with IconPicker {
  Client get client => Provider.of<Client>(context, listen: false);

  bool showComment = true;

  static const int maxDepth = 3;

  Widget _buildAvatar() {
    final displayEvent = widget.displayEvent;
    if (widget.hasAvatarURL(displayEvent)) {
      final uri =
          widget.avatarURL(displayEvent)!.getDownloadUri(client).toString();
      return ClipOval(
        child: Image.network(
          uri,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (ctx, obj, stack) {
            return ClipOval(
              child: SvgPicture.network(uri, width: 32, height: 32),
            );
          },
        ),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      child: Text(
        widget.username(widget.displayEvent)[0].toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _handleReply() {
    if (widget.onReply != null) {
      widget.onReply!(widget.event, widget.username(widget.displayEvent));
    } else {
      context.push(
        Uri(
          path: "/write/${widget.event.roomId}",
          queryParameters: {'event': widget.event.eventId},
        ).toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timestamp = relativeTime(widget.displayEvent.originServerTs);

    final double leftPad = widget.depth == 0 ? 16.0 : 12.0;
    final double rightPad = widget.depth == 0 ? 16.0 : 4.0;

    return Container(
      padding: EdgeInsets.fromLTRB(leftPad, 8.0, rightPad, 8.0),
      decoration:
          !showComment
              ? BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8.0),
              )
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header: Avatar, Username, Timestamp, Actions ---
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final userId = widget.displayEvent.senderId;
                  context.pushIfNew('/profile/${Uri.encodeComponent(userId)}');
                },
                child: _buildAvatar(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          final userId = widget.displayEvent.senderId;
                          context.pushIfNew(
                            '/profile/${Uri.encodeComponent(userId)}',
                          );
                        },
                        child: Text(
                          widget.username(widget.displayEvent),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap:
                          () => setState(() {
                            showComment = !showComment;
                          }),
                      child: Text(
                        timestamp,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _handleReply,
                icon: Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: 'Reply',
              ),
              IconButton(
                onPressed:
                    () async => await pickIcon(
                      context,
                      widget.event,
                      postEvent: widget.postEvent,
                    ),
                icon: Icon(
                  Icons.favorite_border,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: 'React',
              ),
            ],
          ),
          if (showComment) ...[
            // --- Content ---
            GestureDetector(
              onTap:
                  () => setState(() {
                    showComment = !showComment;
                  }),
              child: Padding(
                padding: const EdgeInsets.only(left: 42.0),
                child:
                    widget.displayEvent.messageType == MessageTypes.Text
                        ? Html(
                          data:
                              widget.displayEvent.formattedText.isNotEmpty
                                  ? widget.displayEvent.formattedText
                                  : widget.displayEvent.body,
                        )
                        : FileDisplayContainer(
                          event: widget.event,
                          displayEvent: widget.displayEvent,
                        ),
              ),
            ),

            // Comments – if we've reached max depth, show a "continue thread" button
            if (widget.depth >= CommentWidgetState.maxDepth)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 42.0),
                child: TextButton.icon(
                  onPressed: () {
                    context.pushIfNew(
                      '/post/${widget.event.eventId}?room=${widget.event.roomId}',
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text('post.continue_thread'.tr()),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(left: 16.0),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      width: 2.0,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
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
                                      onReply: widget.onReply,
                                    );
                                  }).toList() ??
                                  [],
                            ],
                          ).toList(),
                    );
                  },
                ),
              ),

            // --- Reactions ---
            Padding(
              padding: const EdgeInsets.only(left: 42.0),
              child: ReactionsDisplay(event: widget.event),
            ),
          ],
        ],
      ),
    );
  }
}
