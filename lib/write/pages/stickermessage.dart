import '/write/widgets/room_header.dart';
import '/write/widgets/reply_preview.dart';
import '/write/widgets/send_progress_dialog.dart';
import '/shared/widgets/mxc_image.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Recently used sticker keys (stored in SharedPreferences)
  static const String _recentPrefKey = 'substitution_recent_stickers';
  static const int _maxRecent = 20;
  List<String> _recentKeys = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _loadRecentStickers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentStickers() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentPrefKey) ?? [];
    if (mounted) setState(() => _recentKeys = stored);
  }

  Future<void> _saveRecentSticker(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final updated =
        [key, ..._recentKeys.where((k) => k != key)].take(_maxRecent).toList();
    await prefs.setStringList(_recentPrefKey, updated);
    if (mounted) setState(() => _recentKeys = updated);
  }

  Future<void> _send(ImagePackImageContent sticker, String stickerKey) async {
    // Capture context objects before any await.
    // ignore: use_build_context_synchronously
    final scavMsg = ScaffoldMessenger.of(context);
    // ignore: use_build_context_synchronously
    final navigator = Navigator.of(context);
    // ignore: use_build_context_synchronously
    final goRouter = GoRouter.of(context);
    await _saveRecentSticker(stickerKey);

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
      goRouter.go('/room/${answerEvent.room.id}/${answerEvent.eventId}');
    } else if (room != null) {
      goRouter.go('/feed/${room!.id}');
    } else {
      goRouter.go('/');
    }
  }

  Widget _buildStickerCell({
    required ImagePackImageContent image,
    required String imageKey,
    required String packSlug,
    required bool isSelected,
    required ColorScheme colorScheme,
  }) {
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
            color: isSelected ? colorScheme.primary : Colors.transparent,
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
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search.hint'.tr(),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () => _searchController.clear(),
                        )
                        : null,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Recently used section (only when not searching)
                if (_searchQuery.isEmpty && _recentKeys.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                    child: Text(
                      'write.stickermessage.recently_used'.tr(),
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
                    itemCount: _recentKeys.length,
                    itemBuilder: (context, index) {
                      final recentKey = _recentKeys[index];
                      // Find the image in any pack
                      ImagePackImageContent? foundImage;
                      String foundPackSlug = '';
                      for (final packEntry in packs.entries) {
                        final img = packEntry.value.images[recentKey];
                        if (img != null) {
                          foundImage = img;
                          foundPackSlug = packEntry.key;
                          break;
                        }
                      }
                      if (foundImage == null) return const SizedBox.shrink();
                      final isSelected =
                          _selectedStickerKey == recentKey &&
                          _selectedPackName == foundPackSlug;
                      return _buildStickerCell(
                        image: foundImage,
                        imageKey: recentKey,
                        packSlug: foundPackSlug,
                        isSelected: isSelected,
                        colorScheme: colorScheme,
                      );
                    },
                  ),
                ],
                // Pack sections
                ...packs.entries.expand((packEntry) {
                  final packSlug = packEntry.key;
                  final pack = packEntry.value;
                  // Filter images by search query
                  final filteredImages =
                      _searchQuery.isEmpty
                          ? pack.images.entries.toList()
                          : pack.images.entries
                              .where(
                                (e) =>
                                    e.key.toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                    (e.value.body?.toLowerCase().contains(
                                          _searchQuery,
                                        ) ??
                                        false),
                              )
                              .toList();
                  if (filteredImages.isEmpty) return <Widget>[];
                  return [
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
                      itemCount: filteredImages.length,
                      itemBuilder: (context, index) {
                        final imageKey = filteredImages[index].key;
                        final image = filteredImages[index].value;
                        final isSelected =
                            _selectedStickerKey == imageKey &&
                            _selectedPackName == packSlug;
                        return _buildStickerCell(
                          image: image,
                          imageKey: imageKey,
                          packSlug: packSlug,
                          isSelected: isSelected,
                          colorScheme: colorScheme,
                        );
                      },
                    ),
                  ];
                }),
              ],
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
