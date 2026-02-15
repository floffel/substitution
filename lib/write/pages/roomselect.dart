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
      WidgetStateProperty.resolveWith<Icon?>(
    (Set<WidgetState> states) {
      if (states.contains(WidgetState.selected)) {
        return const Icon(Icons.add_a_photo);
      }
      return const Icon(Icons.post_add);
    },
  );

  Future<List<SubstitutionRoom>> _getJoinedRooms() async {
    List<SubstitutionRoom> ret = [];

    for (String roomId in await client.getJoinedRooms()) {
      Room r = client.getRoomById(roomId)!;
      bool isInSubstitution = await client.isRoomInSubstitution(roomId);

      if (!isInSubstitution || r.ownPowerLevel < 50) {
        // only posts with power >= 50 will be recognised, so we only show rooms with power >= 50
        continue;
      }

      // check if we have more than 50 power in this room

      ret.add(SubstitutionRoom(
        name: r.name,
        id: r.id,
        avatarUrl: r.avatar?.getDownloadUri(client).toString(),
        isInsideSubstitution: isInSubstitution,
        joined: true,
      ));
    }

    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(children: [
      const Text("write.roomselect.type_prompt").tr(),
      Switch(
        thumbIcon: postTypeThumbIcon,
        value: postType,
        activeThumbColor: Colors.red,
        onChanged: (bool value) {
          setState(() {
            postType = value;
          });
        },
      ),
      const Text("write.roomselect.room_prompt").tr(),
      FutureBuilder(
          future: _getJoinedRooms(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            return SingleChildScrollView(
                child: Column(
                    children: ListTile.divideTiles(context: context, tiles: [
              ...snapshot.data?.map((l) {
                    //return Text(l["id"]);
                    return GestureDetector(
                        onTap: () {
                          debugPrint("postType: $postType");

                          context.push(
                              "/${postType ? "file" : "write"}/${l.id}");
                        },
                        child: RoomWidget(room: l));
                  }).toList() ??
                  [const Text("write.roomselect.error_no_rooms").tr()]
            ]).toList()));
          }),
    ]));
  }
}
