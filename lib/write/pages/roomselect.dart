import '/settings/widgets/roomwidget.dart'; // todo: move into other file structure, as it is imported from more than one directory/page/...
import '/shared/models/substitution_room.dart';
import '/shared/services/substitution_service.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

/// All supported post types the user can select on the room-select page.
enum PostType { text, photoVideo, location, voice, document, emote, sticker }

extension PostTypeExtension on PostType {
  String get labelKey {
    switch (this) {
      case PostType.text:
        return 'write.roomselect.type_text';
      case PostType.photoVideo:
        return 'write.roomselect.type_photo';
      case PostType.location:
        return 'write.roomselect.type_location';
      case PostType.voice:
        return 'write.roomselect.type_voice';
      case PostType.document:
        return 'write.roomselect.type_document';
      case PostType.emote:
        return 'write.roomselect.type_emote';
      case PostType.sticker:
        return 'write.roomselect.type_sticker';
    }
  }

  IconData get icon {
    switch (this) {
      case PostType.text:
        return Icons.post_add_rounded;
      case PostType.photoVideo:
        return Icons.add_a_photo_rounded;
      case PostType.location:
        return Icons.location_on_rounded;
      case PostType.voice:
        return Icons.mic_rounded;
      case PostType.document:
        return Icons.attach_file_rounded;
      case PostType.emote:
        return Icons.mood_rounded;
      case PostType.sticker:
        return Icons.sticky_note_2_rounded;
    }
  }

  String routePrefix(String roomId) {
    switch (this) {
      case PostType.text:
        return '/write/$roomId';
      case PostType.photoVideo:
        return '/file/$roomId';
      case PostType.location:
        return '/location/$roomId';
      case PostType.voice:
        return '/voice/$roomId';
      case PostType.document:
        return '/document/$roomId';
      case PostType.emote:
        return '/emote/$roomId';
      case PostType.sticker:
        return '/sticker/$roomId';
    }
  }
}

@immutable
class RoomSelectPage extends StatefulWidget {
  const RoomSelectPage({super.key});

  static RoomSelectPageState of(BuildContext context) {
    return context.findAncestorStateOfType<RoomSelectPageState>()!;
  }

  @override
  RoomSelectPageState createState() => RoomSelectPageState();
}

class RoomSelectPageState extends State<RoomSelectPage> {
  // todo: make client a mixin
  Client get client => Provider.of<Client>(context, listen: false);
  PostType _selectedType = PostType.text;

  late Future<List<SubstitutionRoom>> _joinedRoomsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _joinedRoomsFuture = _getJoinedRooms();
  }

  Future<List<SubstitutionRoom>> _getJoinedRooms() async {
    final substitutionService = Provider.of<SubstitutionService>(
      context,
      listen: false,
    );
    await substitutionService.init();

    List<SubstitutionRoom> ret = [];

    for (String roomId in await client.getJoinedRooms()) {
      Room? r = client.getRoomById(roomId);
      if (r == null) continue;

      if (!substitutionService.isSubstitutionRoom(roomId)) continue;

      // In blog mode (events_default >= 50), only moderators/admins can post.
      // In community mode (events_default < 50), anyone can post.
      final powerLevelEvent = r.getState('m.room.power_levels');
      final eventsDefault =
          (powerLevelEvent?.content['events_default'] as num?)?.toInt() ?? 0;
      if (eventsDefault >= 50 && r.ownPowerLevel < 50) {
        continue;
      }

      ret.add(
        SubstitutionRoom(
          name: r.name,
          id: r.id,
          avatarUrl: r.avatar?.toString(),
          isInsideSubstitution: true,
          joined: true,
        ),
      );
    }

    return ret;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Post type selector grid
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'write.roomselect.type_prompt'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _PostTypeGrid(
                selected: _selectedType,
                onSelect: (type) => setState(() => _selectedType = type),
              ),
            ],
          ),
        ),

        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Row(
            children: [
              Icon(
                Icons.forum_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "write.roomselect.room_prompt".tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Room list
        Expanded(
          child: FutureBuilder(
            future: _joinedRoomsFuture,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "write.roomselect.error_no_rooms".tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (ctx, index) {
                  final room = snapshot.data![index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 2,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        context.push(_selectedType.routePrefix(room.id));
                      },
                      child: RoomWidget(room: room),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PostTypeGrid extends StatelessWidget {
  const _PostTypeGrid({required this.selected, required this.onSelect});

  final PostType selected;
  final ValueChanged<PostType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children:
          PostType.values
              .map(
                (type) => _PostTypeChip(
                  type: type,
                  isSelected: type == selected,
                  onTap: () => onSelect(type),
                ),
              )
              .toList(),
    );
  }
}

class _PostTypeChip extends StatelessWidget {
  const _PostTypeChip({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final PostType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(type.labelKey.tr()),
      avatar: Icon(
        type.icon,
        size: 18,
        color:
            isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}
