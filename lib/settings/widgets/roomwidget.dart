import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '/shared/models/substitution_room.dart';

// like post but smaller
class RoomWidget extends StatefulWidget {
  const RoomWidget({
    super.key,
    required this.room,
    this.leaveRoom,
    this.joinRoom,
    this.deleteRoom,
  });

  // room elements
  final SubstitutionRoom room;

  final Future<void> Function(String roomId)? leaveRoom;
  final Future<void> Function(String roomId)? joinRoom;
  final Future<void> Function(String roomId)? deleteRoom;

  @override
  RoomWidgetState createState() => RoomWidgetState();
}

class RoomWidgetState extends State<RoomWidget> {
  Client get client => Provider.of<Client>(context, listen: false);

  bool get showLeaveRoom =>
      widget.room.isInsideSubstitution &&
      widget.room.joined &&
      widget.leaveRoom != null;
  bool get showJoinRoom => widget.joinRoom != null;
  bool get showDeleteRoom => widget.deleteRoom != null;

  bool get isAdminRoom {
    final room = client.getRoomById(widget.room.id);
    return room != null && room.ownPowerLevel >= 100;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('settings.room.desc').tr(args: [widget.room.name]),
      subtitle: Text(widget.room.id),
      leading:
          widget.room.avatarUrl != null
              ? CircleAvatar(
                radius: 20,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundImage: NetworkImage(
                  widget.room.avatarUrl!.startsWith('mxc://')
                      ? Uri.parse(
                        widget.room.avatarUrl!,
                      ).getDownloadUri(client).toString()
                      : widget.room.avatarUrl!,
                ),
                onForegroundImageError: (ctx, obj) {
                  debugPrint("Failed to load avatar: ${widget.room.avatarUrl}");
                },
                child: Text(widget.room.name[0].toUpperCase()),
              )
              : CircleAvatar(
                radius: 20,
                child: Text(widget.room.name[0].toUpperCase()),
              ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdminRoom)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'settings.room.permissions'.tr(),
              onPressed: () {
                context.push('/settings/room/${widget.room.id}/permissions');
              },
            ),
          showLeaveRoom
              ? IconButton(
                icon: const Icon(Icons.person_remove),
                tooltip: 'settings.room.leave'.tr(),
                onPressed: () async {
                  await widget.leaveRoom!(widget.room.id);
                },
              )
              : showJoinRoom
              ? IconButton(
                icon: const Icon(Icons.person_add),
                tooltip: 'settings.room.join'.tr(),
                onPressed: () async {
                  await widget.joinRoom!(widget.room.id);
                },
              )
              : const SizedBox.shrink(),
          if (showDeleteRoom) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'settings.room.delete'.tr(), // todo intl
              onPressed: () async {
                await widget.deleteRoom!(widget.room.id);
              },
            ),
          ],
        ],
      ),
    );
  }
}
