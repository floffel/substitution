import '/settings/widgets/roomwidget.dart'; // todo: move into other file structure, as it is imported from more than one directory/page/...

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

  final MaterialStateProperty<Icon?> postTypeThumbIcon =
      MaterialStateProperty.resolveWith<Icon?>(
    (Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return const Icon(Icons.add_a_photo);
      }
      return const Icon(Icons.post_add);
    },
  );

  Future<List<Map<String, dynamic>>> _getJoinedRooms() async {
    List<Map<String, dynamic>> ret = [];

    for (String roomId in await client.getJoinedRooms()) {
      Room r = client.getRoomById(roomId)!;
      bool isInSubstitution = false;

      // get if in substitution, stolen from _fetchRooms, todo: make it a function or so...
      // todo: this only works with logged in clients!
      try {
        isInSubstitution = (await client.getAccountDataPerRoom(
                client.userID!, roomId, "substitution"))["joined"] ==
            true;
      } catch (_) {} // we cannot get the account data

      if (!isInSubstitution || r.ownPowerLevel < 50) {
        // only posts with power >= 50 will be recognised, so we only show rooms with power >= 50
        continue;
      }

      // check if we have more than 50 power in this room

      Map<String, dynamic> add = {
        // todo: do it with a typedef https://stackoverflow.com/questions/24762414/is-there-anything-like-a-struct-in-dart
        "name": r.name,
        "id": r.id,
        "isInsideSubstitution": isInSubstitution,
        "joined": true,
      };

      ret.add(add);
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
        activeColor: Colors.red,
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
            if (!snapshot.hasData) {
              return const Text("loading").tr();
            }

            return SingleChildScrollView(
                child: Column(
                    children: ListTile.divideTiles(context: context, tiles: [
              ...snapshot.data?.map((l) {
                    //return Text(l["id"]);
                    return GestureDetector(
                        onTap: () {
                          debugPrint("postType: ${postType}");

                          context.push(
                              "/${postType ? "file" : "write"}/${l['id']}");
                        },
                        child: RoomWidget(items: l));
                  }).toList() ??
                  [const Text("write.roomselect.error_no_rooms").tr()]
            ]).toList()));
          }),
    ]));
  }
}
