import '/post/interfaces/i_event.dart';
import '/post/widgets/display/file_display_container.dart';
import '/post/widgets/display/location_display.dart';
import '/post/widgets/display/reactions_display.dart';
import '/shared/widgets/mxc_image.dart';
import '/post/mixins/iconpicker.dart';
import '/post/widgets/dialog_report_block.dart';
import '/post/widgets/dialog_delete_post.dart';
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
    this.timeline,
  });

  /// When true, hides the reply button (used on detail page where inline reply input is shown instead).
  final bool isDetailView;

  /// Optional pre-loaded timeline from the feed.  Passed to
  /// [ReactionsDisplay] to avoid creating a separate timeline per post.
  final Timeline? timeline;

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
    final messageType = widget.displayEvent.messageType;
    final isTextPost = messageType == MessageTypes.Text;
    final isEmotePost = messageType == MessageTypes.Emote;
    final isLocationPost = messageType == MessageTypes.Location;
    final isVoicePost =
        messageType == MessageTypes.Audio &&
        (widget.displayEvent.content['org.matrix.msc3245.voice'] != null);
    final isStickerPost = widget.displayEvent.type == EventTypes.Sticker;
    final isGenericFile = messageType == MessageTypes.File;
    final isMediaPost =
        messageType == MessageTypes.Image ||
        messageType == MessageTypes.Video ||
        (messageType == MessageTypes.Audio && !isVoicePost);
    final isBadEncrypted = messageType == MessageTypes.BadEncrypted;
    final isUnsupportedPost =
        !isTextPost &&
        !isEmotePost &&
        !isLocationPost &&
        !isVoicePost &&
        !isStickerPost &&
        !isGenericFile &&
        !isMediaPost &&
        !isBadEncrypted;

    // Emote posts get a special borderless inline layout instead of the card.
    if (isEmotePost) {
      return _EmotePostRow(
        event: widget.event,
        displayEvent: widget.displayEvent,
        isDetailView: widget.isDetailView,
        client: client,
        timestamp: timestamp,
        e2eIcon: _e2eIcon,
        e2eColor: _e2eColor(colorScheme),
        e2eTooltip: _e2eTooltip,
        roomAddr: roomAddr,
        timeline: widget.timeline,
      );
    }

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
                    } else if (value == 'delete') {
                      showDialog(
                        context: context,
                        builder: (_) => DialogDeletePost(event: widget.event),
                      );
                    } else if (value == 'edit') {
                      context.push(
                        Uri(
                          path:
                              '/edit/${widget.event.roomId}/${widget.event.eventId}',
                        ).toString(),
                      );
                    }
                  },
                  itemBuilder: (context) {
                    final isOwnPost =
                        client.userID == widget.displayEvent.senderId;
                    final canRedact =
                        isOwnPost || (widget.event.room.ownPowerLevel >= 50);
                    return [
                      if (isOwnPost &&
                          widget.displayEvent.messageType == MessageTypes.Text)
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: 20),
                              const SizedBox(width: 8),
                              const Text('post.menu.edit').tr(),
                            ],
                          ),
                        ),
                      if (canRedact)
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'post.menu.delete'.tr(),
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ),
                        ),
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
                    ];
                  },
                ),
              ],
            ),
          ),

          // --- Content: Text, Media, Location, Voice, Sticker, or File ---
          // Note: Emote posts are handled above via early return (_EmotePostRow).
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
          else if (isLocationPost)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
              child: LocationDisplay(event: widget.displayEvent),
            )
          else if (isVoicePost)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: _VoicePostPreview(event: widget.displayEvent),
            )
          else if (isStickerPost)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
              child: _StickerPreview(
                event: widget.displayEvent,
                client: client,
              ),
            )
          else if (isGenericFile)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: _GenericFilePreview(event: widget.displayEvent),
            )
          else if (isMediaPost)
            // Edge-to-edge media – no horizontal padding
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: FileDisplayContainer(
                event: widget.event,
                displayEvent: widget.displayEvent,
              ),
            )
          else if (isBadEncrypted)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.no_encryption_outlined,
                    size: 20,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'post.widgets.bad_encrypted'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isUnsupportedPost)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'post.widgets.unsupported_message'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // --- Edited indicator ---
          if (widget.event.eventId != widget.displayEvent.eventId)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'edited',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // --- Reactions ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 0),
            child: ReactionsDisplay(
              event: widget.event,
              timeline: widget.timeline,
            ),
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

/// Borderless inline layout for emote (m.emote) posts.
///
/// Renders as a flat row without a card wrapper so the action feels like an
/// ambient status update in the feed rather than a regular post.
class _EmotePostRow extends StatefulWidget {
  const _EmotePostRow({
    required this.event,
    required this.displayEvent,
    required this.isDetailView,
    required this.client,
    required this.timestamp,
    required this.e2eIcon,
    required this.e2eColor,
    required this.e2eTooltip,
    required this.roomAddr,
    this.timeline,
  });

  final Event event;
  final Event displayEvent;
  final bool isDetailView;
  final Client client;
  final String timestamp;
  final IconData e2eIcon;
  final Color e2eColor;
  final String e2eTooltip;
  final String roomAddr;
  final Timeline? timeline;

  @override
  _EmotePostRowState createState() => _EmotePostRowState();
}

class _EmotePostRowState extends State<_EmotePostRow> with IconPicker {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayEvent = widget.displayEvent;

    final senderName =
        displayEvent.senderFromMemoryOrFallback.displayName ??
        displayEvent.senderId;
    final avatarUri = displayEvent.senderFromMemoryOrFallback.avatarUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thin left accent line
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: colorScheme.secondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Avatar
          GestureDetector(
            onTap: () {
              context.pushIfNew(
                '/profile/${Uri.encodeComponent(displayEvent.senderId)}',
              );
            },
            child: Avatar(
              mxContent: avatarUri,
              name: senderName,
              client: widget.client,
              size: 32,
              fontSize: 13,
            ),
          ),

          const SizedBox(width: 10),

          // Text + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emote text: bold username + italic action
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: senderName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: displayEvent.body,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 2),

                // Sub-row: room · timestamp · e2e  +  action buttons
                Row(
                  children: [
                    GestureDetector(
                      onTap:
                          () => context.pushIfNew(
                            '/feed/${widget.roomAddr.replaceAll('#', '')}',
                          ),
                      child: Text(
                        displayEvent.room.name,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '\u00B7',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      widget.timestamp,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Tooltip(
                        message: widget.e2eTooltip,
                        child: Icon(
                          widget.e2eIcon,
                          size: 11,
                          color: widget.e2eColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Reaction button
                    SizedBox(
                      height: 28,
                      width: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 15,
                        icon: const Icon(Icons.favorite_border_rounded),
                        color: colorScheme.onSurfaceVariant,
                        tooltip: 'React',
                        onPressed:
                            () async => await pickIcon(context, widget.event),
                      ),
                    ),
                    // Reply button
                    if (!widget.isDetailView) ...[
                      const SizedBox(width: 2),
                      SizedBox(
                        height: 28,
                        width: 28,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 15,
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          color: colorScheme.onSurfaceVariant,
                          tooltip: 'Reply',
                          onPressed: () {
                            context.push(
                              Uri(
                                path: '/write/${widget.event.roomId}',
                                queryParameters: {
                                  'event': widget.event.eventId,
                                },
                              ).toString(),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),

                // Reactions
                ReactionsDisplay(
                  event: widget.event,
                  timeline: widget.timeline,
                ),
              ],
            ),
          ),

          // Overflow menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 16,
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
              } else if (value == 'delete') {
                showDialog(
                  context: context,
                  builder: (_) => DialogDeletePost(event: widget.event),
                );
              }
            },
            itemBuilder: (context) {
              final client = Provider.of<Client>(context, listen: false);
              final isOwnPost = client.userID == displayEvent.senderId;
              final canRedact =
                  isOwnPost || (widget.event.room.ownPowerLevel >= 50);
              return [
                if (canRedact)
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'post.menu.delete'.tr(),
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ),
                  ),
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
              ];
            },
          ),
        ],
      ),
    );
  }
}

/// Displays a voice message post with play controls.
class _VoicePostPreview extends StatelessWidget {
  const _VoicePostPreview({required this.event});

  final Event event;

  String get _durationText {
    final ms =
        event.content.tryGetMap<String, Object?>(
          'org.matrix.msc1767.audio',
        )?['duration'];
    if (ms is int && ms > 0) {
      final d = Duration(milliseconds: ms);
      final min = d.inMinutes.toString().padLeft(2, '0');
      final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$min:$sec';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            color: colorScheme.onSecondaryContainer,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'post.voice_message'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                if (_durationText.isNotEmpty)
                  Text(
                    _durationText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer.withValues(
                        alpha: 0.7,
                      ),
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.play_circle_outline_rounded,
            color: colorScheme.onSecondaryContainer,
            size: 32,
          ),
        ],
      ),
    );
  }
}

/// Displays a sticker post (m.sticker event type).
class _StickerPreview extends StatelessWidget {
  const _StickerPreview({required this.event, required this.client});

  final Event event;
  final Client client;

  @override
  Widget build(BuildContext context) {
    final url = event.content.tryGet<String>('url');
    if (url == null) return const SizedBox.shrink();
    final uri = Uri.tryParse(url);
    if (uri == null) return const SizedBox.shrink();

    return SizedBox(
      width: 120,
      height: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: MxcImage(
          uri: uri,
          client: client,
          fit: BoxFit.contain,
          isThumbnail: true,
          errorBuilder:
              (context, _) => const Icon(Icons.sticky_note_2_rounded, size: 64),
        ),
      ),
    );
  }
}

/// Displays a generic file attachment (m.file) with a download prompt.
class _GenericFilePreview extends StatelessWidget {
  const _GenericFilePreview({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filename =
        event.content.tryGet<String>('filename') ??
        event.content.tryGet<String>('body') ??
        'file';
    final info = event.content.tryGetMap<String, Object?>('info');
    final size = info?['size'];
    String? sizeText;
    if (size is int) {
      if (size < 1024) {
        sizeText = '$size B';
      } else if (size < 1024 * 1024) {
        sizeText = '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        sizeText = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sizeText != null)
                  Text(
                    sizeText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.download_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 24,
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
