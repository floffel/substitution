import '/post/interfaces/i_event.dart';
import '/post/widgets/display/file_display_container.dart';
import '/post/widgets/display/reactions_display.dart';
import '/post/mixins/iconpicker.dart';
import '/post/widgets/dialog_report_block.dart';
import '/shared/utils/relative_time.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';

class PostWidget extends IEventWidget {
  const PostWidget({
    super.key,
    required super.event,
    required super.displayEvent,
    this.isDetailView = false,
  });

  /// When true, hides the reply button (used on detail page where inline reply input is shown instead).
  final bool isDetailView;

  @override
  PostWidgetState createState() => PostWidgetState();
}

class PostWidgetState extends State<PostWidget> with IconPicker {
  Client get client => Provider.of<Client>(context, listen: false);

  String get roomAddr =>
      (widget.displayEvent).room.canonicalAlias.isEmpty
          ? (widget.displayEvent).room.id
          : (widget.displayEvent).room.canonicalAlias;

  Widget _buildAvatar() {
    final displayEvent = widget.displayEvent;
    if (widget.hasAvatarURL(displayEvent)) {
      final uri =
          widget.avatarURL(displayEvent)!.getDownloadUri(client).toString();
      return ClipOval(
        child: Image.network(
          uri,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (ctx, obj, stack) {
            return ClipOval(
              child: SvgPicture.network(uri, width: 40, height: 40),
            );
          },
        ),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        widget.username(displayEvent)[0].toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timestamp = relativeTime(widget.displayEvent.originServerTs);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header: Avatar, Username, Room, Timestamp ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 14.0, 12.0, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final userId = widget.displayEvent.senderId;
                    context.push('/profile/${Uri.encodeComponent(userId)}');
                  },
                  child: _buildAvatar(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap:
                        () => context.push(
                          '/feed/${roomAddr.replaceAll('#', '')}',
                        ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.username(widget.displayEvent),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.displayEvent.room.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  timestamp,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'report_block') {
                      showDialog(
                        context: context,
                        builder:
                            (_) => DialogReportBlock(
                              event: widget.event,
                              displayEvent: widget.displayEvent,
                            ),
                      );
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem<String>(
                          value: 'report_block',
                          child: Row(
                            children: [
                              const Icon(Icons.flag_outlined, size: 20),
                              const SizedBox(width: 8),
                              const Text('post.menu.report_block').tr(),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),

          // --- Content: Text or Media ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child:
                widget.displayEvent.messageType == MessageTypes.Text
                    ? Html(
                      data:
                          widget.displayEvent.formattedText.isNotEmpty
                              ? widget.displayEvent.formattedText
                              : widget.displayEvent.body,
                    )
                    : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: FileDisplayContainer(
                        event: widget.event,
                        displayEvent: widget.displayEvent,
                      ),
                    ),
          ),

          // --- Reactions ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ReactionsDisplay(event: widget.event),
          ),

          // --- Action bar ---
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 4.0),
            child: Row(
              children: [
                if (!widget.isDetailView)
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
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Reply',
                  ),
                IconButton(
                  onPressed: () async => await pickIcon(context, widget.event),
                  icon: Icon(
                    Icons.favorite_border,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'React',
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
