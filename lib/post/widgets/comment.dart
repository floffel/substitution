import '/post/widgets/display/file_display_container.dart';
import '/post/widgets/display/reactions_display.dart';
import '/post/mixins/iconpicker.dart';
import '/post/interfaces/i_event.dart';
import '/post/widgets/dialog_delete_post.dart';
import '/post/widgets/dialog_report_block.dart';
import '/shared/utils/relative_time.dart';
import '/shared/extensions/go_router_extensions.dart';
import '/shared/widgets/avatar.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_html/flutter_html.dart';
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
    super.timeline,
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

  void _showCommentMenu(BuildContext context) {
    final isOwnComment = client.userID == widget.displayEvent.senderId;
    final canRedact =
        isOwnComment || widget.event.room.ownPowerLevel >= PowerLevel.moderator;

    showModalBottomSheet<void>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canRedact)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(ctx).colorScheme.error,
                    ),
                    title: Text(
                      'post.menu.delete'.tr(),
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showDialog(
                        context: context,
                        builder: (_) => DialogDeletePost(event: widget.event),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('post.menu.report_block').tr(),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      builder:
                          (_) => DialogReportBlock(
                            event: widget.event,
                            displayEvent: widget.displayEvent,
                          ),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  bool showComment = true;

  static const int maxDepth = 3;

  Widget _buildAvatar() {
    final displayEvent = widget.displayEvent;
    return Avatar(
      mxContent: widget.avatarURL(displayEvent),
      name: widget.username(displayEvent),
      client: client,
      size: 32,
      fontSize: 12,
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          !showComment
              ? () => setState(() {
                showComment = true;
              })
              : null,
      child: Container(
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
                    context.pushIfNew(
                      '/profile/${Uri.encodeComponent(userId)}',
                    );
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
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
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
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  tooltip: 'React',
                ),
                IconButton(
                  onPressed: () => _showCommentMenu(context),
                  icon: Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: 'More',
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
                  child: switch (widget.displayEvent.messageType) {
                    MessageTypes.Text => Html(
                      data:
                          widget.displayEvent.formattedText.isNotEmpty
                              ? widget.displayEvent.formattedText
                              : widget.displayEvent.body,
                    ),
                    MessageTypes.Image ||
                    MessageTypes.Video ||
                    MessageTypes.Audio => FileDisplayContainer(
                      event: widget.event,
                      displayEvent: widget.displayEvent,
                      timeline: widget.timeline,
                    ),
                    MessageTypes.BadEncrypted => Row(
                      children: [
                        Icon(
                          Icons.no_encryption_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'post.widgets.bad_encrypted'.tr(),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _ => Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'post.widgets.unsupported_message'.tr(),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  },
                ),
              ),

              // Comments – if we've reached max depth, show a "continue thread" button
              if (widget.depth >= CommentWidgetState.maxDepth)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 42.0),
                  child: TextButton.icon(
                    onPressed: () {
                      context.pushIfNew(
                        '/room/${widget.event.roomId}/${widget.event.eventId}',
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
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                  child: FutureBuilder<
                    List<({Event origEvent, Event displayEvent})>
                  >(
                    future: widget.comments,
                    builder: (ctx, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'post.widgets.comment.load_error'.tr(),

                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                          ),
                        );
                      }
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
                                        timeline: widget.timeline,
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
      ),
    );
  }
}
