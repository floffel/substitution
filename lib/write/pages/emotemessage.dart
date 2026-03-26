import '/write/widgets/room_header.dart';
import '/write/widgets/reply_preview.dart';
import '/write/widgets/send_progress_dialog.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class EmoteMessageWrite extends StatefulWidget {
  const EmoteMessageWrite({super.key, required this.roomId, this.eventId});

  final String roomId;
  final String? eventId;

  @override
  EmoteMessageWriteState createState() => EmoteMessageWriteState();
}

class EmoteMessageWriteState extends State<EmoteMessageWrite> {
  Client get client => Provider.of<Client>(context, listen: false);
  Room? get room => client.getRoomById(widget.roomId);
  Future<Event?> get event async =>
      widget.eventId == null || room == null
          ? null
          : Event.fromMatrixEvent(
            await client.getOneRoomEvent(widget.roomId, widget.eventId!),
            room!,
          );

  Future<({Event event, Event displayEvent})?> get eventData async {
    final e = await event;
    if (e == null) return null;
    final timeline = await e.room.getTimeline(eventContextId: e.eventId);
    return (event: e, displayEvent: e.getDisplayEvent(timeline));
  }

  final TextEditingController _controller = TextEditingController();
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final empty = _controller.text.trim().isEmpty;
      if (empty != _isEmpty) setState(() => _isEmpty = empty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _displayName {
    return client.userID?.split(':').first.replaceFirst('@', '') ?? 'you';
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final scavMsg = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final goRouter = GoRouter.of(context);

    String? ret;
    var eventThreadId = widget.eventId;
    bool userCancel = false;

    while (ret == null && !userCancel) {
      if (!mounted) return;

      showSendLoadingDialog(
        context,
        messageKey: 'write.textmessage.send_start',
      );

      try {
        final currentEvent = await event;
        if (currentEvent?.relationshipType == RelationshipTypes.thread) {
          eventThreadId = currentEvent?.relationshipEventId;
        }

        ret = await room!.sendEvent(
          {'msgtype': MessageTypes.Emote, 'body': text},
          threadRootEventId: eventThreadId,
          inReplyTo: currentEvent,
        );
      } catch (e) {
        debugPrint('Emote send error: $e');
        // ret stays null so the error dialog below is shown
      }

      navigator.pop();

      if (ret == null) {
        if (!mounted) break;
        userCancel = await showSendErrorDialog(
          context,
          errorMessageKey: 'write.textmessage.send_failed',
          retryKey: 'write.textmessage.buttons.resend',
          cancelKey: 'write.textmessage.buttons.send_stop',
        );
      } else {
        if (mounted) {
          scavMsg.showSnackBar(
            SnackBar(content: Text('write.textmessage.send_complete'.tr())),
          );
        }
      }
    }

    if (eventThreadId != null) {
      final answerEvent = Event.fromMatrixEvent(
        await client.getOneRoomEvent(widget.roomId, eventThreadId),
        room!,
      );
      goRouter.go(
        Uri(
          path: '/post/${answerEvent.eventId}',
          queryParameters: {'room': answerEvent.room.id},
        ).toString(),
      );
    } else if (room != null) {
      goRouter.go('/feed/${room!.id}');
    } else {
      goRouter.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final text = _controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.eventId != null || room != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.eventId != null)
                  ReplyPreviewWidget(future: eventData),
                if (room != null) ...[
                  const SizedBox(height: 4),
                  RoomHeaderWidget(room: room!),
                ],
              ],
            ),
          ),

        // Emote explanation
        Card(
          color: colorScheme.secondaryContainer,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.mood_rounded,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'write.emotemessage.explanation'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Live preview
        if (text.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '* $_displayName $text',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Text input
        Expanded(
          child: TextField(
            controller: _controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              labelText: 'write.emotemessage.input_label'.tr(),
              hintText: 'write.emotemessage.input_hint'.tr(),
              prefixText: '* $_displayName ',
              prefixStyle: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Send button
        FilledButton.icon(
          onPressed: _isEmpty ? null : _send,
          icon: const Icon(Icons.send_rounded),
          label: Text('write.textmessage.send_button'.tr()),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
