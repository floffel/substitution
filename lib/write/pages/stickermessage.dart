import '/write/widgets/room_header.dart';
import '/write/widgets/reply_preview.dart';
import '/write/widgets/send_progress_dialog.dart';
import '/shared/widgets/mxc_image.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class StickerMessageWrite extends StatefulWidget {
  const StickerMessageWrite({super.key, required this.roomId, this.eventId});

  final String roomId;
  final String? eventId;

  @override
  StickerMessageWriteState createState() => StickerMessageWriteState();
}

class StickerMessageWriteState extends State<StickerMessageWrite> {
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

  ImagePackImageContent? _selectedSticker;
  String? _selectedStickerKey;
  String? _selectedPackName;

  Future<void> _send(ImagePackImageContent sticker, String stickerKey) async {
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

        final url = sticker.url.toString();
        ret = await room!.sendEvent(
          {
            'body': stickerKey,
            'url': url,
            if (sticker.info != null) 'info': sticker.info,
          },
          type: EventTypes.Sticker,
          threadRootEventId: eventThreadId,
          inReplyTo: currentEvent,
        );
      } catch (e) {
        debugPrint('Sticker send error: $e');
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

    final packs =
        room != null ? room!.getImagePacks(ImagePackUsage.sticker) : {};
    final hasStickers = packs.isNotEmpty;

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

        if (!hasStickers) ...[
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'write.stickermessage.no_stickers'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children:
                  packs.entries.map((packEntry) {
                    final packSlug = packEntry.key;
                    final pack = packEntry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                          child: Text(
                            pack.displayName ?? packSlug,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: pack.images.length,
                          itemBuilder: (context, index) {
                            final imageKey = pack.images.keys.elementAt(index);
                            final image = pack.images[imageKey]!;
                            final isSelected =
                                _selectedStickerKey == imageKey &&
                                _selectedPackName == packSlug;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedSticker = image;
                                  _selectedStickerKey = imageKey;
                                  _selectedPackName = packSlug;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? colorScheme.primary
                                            : Colors.transparent,
                                    width: 2,
                                  ),
                                  color:
                                      isSelected
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHighest,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: MxcImage(
                                  uri: image.url,
                                  client: client,
                                  fit: BoxFit.contain,
                                  isThumbnail: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Send button
          FilledButton.icon(
            onPressed:
                _selectedSticker != null && _selectedStickerKey != null
                    ? () => _send(_selectedSticker!, _selectedStickerKey!)
                    : null,
            icon: const Icon(Icons.send_rounded),
            label: Text(
              _selectedSticker != null
                  ? 'write.stickermessage.send_button'.tr(
                    args: [_selectedStickerKey ?? ''],
                  )
                  : 'write.stickermessage.select_prompt'.tr(),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}
