import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

// like post but smaller
class RoomWidget extends StatefulWidget {
  const RoomWidget(
      {super.key, required this.items, this.leaveRoom, this.joinRoom});

  // room elements
  final Map<String, dynamic> items; // TODO: make it class/"structlike"

  final Future<void> Function(String roomId)? leaveRoom;
  final Future<void> Function(String roomId)? joinRoom;

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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
          'Raum: ${widget.items["name"]}, joined: ${widget.items["joined"]}, isInsideSubstitution: ${widget.items["isInsideSubstitution"]}'),
      subtitle: Text(widget.items["id"]),
      leading: widget.items["avatarUrl"] != null
          ? Image.network(widget.items["avatarUrl"])
          : const Text("no img"),
      trailing: showLeaveRoom
          ? IconButton(
              icon: const Icon(Icons.person_remove),
              tooltip: 'leave',
              onPressed: () async {
                await widget.leaveRoom!(widget.items["id"]);
              },
            )
          : showJoinRoom
              ? IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'join',
                  onPressed: () async {
                    await widget.joinRoom!(widget.items["id"]);
                  },
                )
              : const Text(""),
    );
  }
}
