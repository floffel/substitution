import '/post/interfaces/i_event.dart';
import '/post/widgets/display/file_display_container.dart';
import '/post/widgets/display/reactions_display.dart';
import '/post/mixins/iconpicker.dart';
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
    return Avatar(
      mxContent: widget.avatarURL(displayEvent),
      name: widget.username(displayEvent),
      client: client,
      size: 44,
    );
  }

  IconData get _e2eIcon {
    if (widget.displayEvent.messageType == MessageTypes.BadEncrypted) {
      return Icons.no_encryption_outlined;
    }
    if (widget.displayEvent.originalSource != null) {
      return Icons.lock_outlined;
    }
    return Icons.lock_open_outlined;
  }

  Color _e2eColor(ColorScheme colorScheme) {
    if (widget.displayEvent.messageType == MessageTypes.BadEncrypted) {
      return colorScheme.error;
    }
    return colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
  }

  String get _e2eTooltip {
    if (widget.displayEvent.messageType == MessageTypes.BadEncrypted) {
      return 'post.e2e.failed'.tr();
    }
    if (widget.displayEvent.originalSource != null) {
      return 'post.e2e.encrypted'.tr();
    }
    return 'post.e2e.unencrypted'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timestamp = relativeTime(widget.displayEvent.originServerTs);
    final isTextPost = widget.displayEvent.messageType == MessageTypes.Text;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22.0),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header: Avatar, Username, Room, Timestamp ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 14.0, 8.0, 0),
            child: Row(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final userId = widget.displayEvent.senderId;
                          context.pushIfNew(
                            '/profile/${Uri.encodeComponent(userId)}',
                          );
                        },
                        child: Text(
                          widget.username(widget.displayEvent),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap:
                            () => context.pushIfNew(
                              '/feed/${roomAddr.replaceAll('#', '')}',
                            ),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.displayEvent.room.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '\u00B7',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            Text(
                              timestamp,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Tooltip(
                                message: _e2eTooltip,
                                child: Icon(
                                  _e2eIcon,
                                  size: 14,
                                  color: _e2eColor(colorScheme),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
          if (isTextPost)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Html(
                data:
                    widget.displayEvent.formattedText.isNotEmpty
                        ? widget.displayEvent.formattedText
                        : widget.displayEvent.body,
              ),
            )
          else
            // Edge-to-edge media – no horizontal padding
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: FileDisplayContainer(
                event: widget.event,
                displayEvent: widget.displayEvent,
              ),
            ),

          // --- Reactions ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 0),
            child: ReactionsDisplay(event: widget.event),
          ),

          // --- Action bar ---
          Padding(
            padding: const EdgeInsets.fromLTRB(6.0, 0, 6.0, 4.0),
            child: Row(
              children: [
                if (!widget.isDetailView)
                  _ActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Reply',
                    onPressed: () {
                      context.push(
                        Uri(
                          path: "/write/${widget.event.roomId}",
                          queryParameters: {'event': widget.event.eventId},
                        ).toString(),
                      );
                    },
                  ),
                _ActionButton(
                  icon: Icons.favorite_border_rounded,
                  tooltip: 'React',
                  onPressed: () async => await pickIcon(context, widget.event),
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

/// A small, rounded icon button for the action bar.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.all(10),
      ),
    );
  }
}
