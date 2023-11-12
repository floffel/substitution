import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

// like post but smaller
class RoomWidget extends StatefulWidget {
  const RoomWidget(
      {super.key,
      required this.items,
      this.leaveRoom,
      this.joinRoom,
      this.deleteRoom});

  // room elements
  final Map<String, dynamic> items; // TODO: make it class/"structlike"

  final Future<void> Function(String roomId)? leaveRoom;
  final Future<void> Function(String roomId)? joinRoom;
  final Future<void> Function(String roomId)? deleteRoom;

  @override
  RoomWidgetState createState() => RoomWidgetState();
}

class RoomWidgetState extends State<RoomWidget> {
  Client get client => Provider.of<Client>(context, listen: false);

  bool get showLeaveRoom =>
      widget.items["isInsideSubstitution"] &&
      widget.items["joined"] &&
      widget.leaveRoom != null;
  bool get showJoinRoom => widget.joinRoom != null;
  bool get showDeleteRoom => widget.deleteRoom != null;

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title:
            const Text('settings.room.desc').tr(args: [widget.items["name"]]),
        subtitle: Text(widget.items["id"]),
        leading: widget.items["avatarUrl"] != null
            ? Image.network(widget.items["avatarUrl"])
            : const Text("error_no_image").tr(),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          showLeaveRoom
              ? IconButton(
                  icon: const Icon(Icons.person_remove),
                  tooltip: 'settings.room.leave'.tr(),
                  onPressed: () async {
                    await widget.leaveRoom!(widget.items["id"]);
                  },
                )
              : showJoinRoom
                  ? IconButton(
                      icon: const Icon(Icons.person_add),
                      tooltip: 'settings.room.join'.tr(),
                      onPressed: () async {
                        await widget.joinRoom!(widget.items["id"]);
                      },
                    )
                  : const Text(""), // TODO: use Container() ?
          if (showDeleteRoom) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'settings.room.delete'.tr(), // todo intl
              onPressed: () async {
                await widget.deleteRoom!(widget.items["id"]);
              },
            )
          ]
        ] // todo: find a better solution. Be aware: substitutiong Text("") with Cointainer() breaks!
            ));
  }
}
