import '/settings/widgets/roomwidget.dart'; // todo: move into other file structure, as it is imported from more than one directory/page/...
import '/shared/extensions/client_extensions.dart';
import '/shared/models/substitution_room.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

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
  bool postType = false;

  final WidgetStateProperty<Icon?> postTypeThumbIcon =
      WidgetStateProperty.resolveWith<Icon?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return const Icon(Icons.add_a_photo_rounded);
        }
        return const Icon(Icons.post_add_rounded);
      });

  Future<List<SubstitutionRoom>> _getJoinedRooms() async {
    List<SubstitutionRoom> ret = [];

    for (String roomId in await client.getJoinedRooms()) {
      Room r = client.getRoomById(roomId)!;
      bool isInSubstitution = await client.isRoomInSubstitution(roomId);

      if (!isInSubstitution || r.ownPowerLevel < 50) {
        continue;
      }

      ret.add(
        SubstitutionRoom(
          name: r.name,
          id: r.id,
          avatarUrl: r.avatar?.toString(),
          isInsideSubstitution: isInSubstitution,
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
      children: [
        // Post type selector card
        Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: const Text("write.roomselect.type_prompt").tr(),
                ),
                Switch(
                  thumbIcon: postTypeThumbIcon,
                  value: postType,
                  onChanged: (bool value) {
                    setState(() {
                      postType = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(
                Icons.forum_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                "write.roomselect.room_prompt".tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Room list
        Expanded(
          child: FutureBuilder(
            future: _getJoinedRooms(),
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (ctx, index) {
                  final room = snapshot.data![index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        context.push(
                          "/${postType ? "file" : "write"}/${room.id}",
                        );
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
