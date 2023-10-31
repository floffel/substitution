import 'package:substitution/settings/widgets/menu.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:substitution/settings/widgets/roomwidget.dart'; // todo: move into other file structure, as it is imported from more than one directory/page/...

// hier will ich eigentlich als übergabe einen raum haben
// optional ein post oder kommentar, den ich dann darüber anzeige, zum antworten
// und dann da eine neue Text-Message reinsenden

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => {context.pop(true)},
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text("Substitution"),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            onPressed: () => {
              _scaffoldKey.currentState?.openEndDrawer(),
            },
            icon: const Icon(Icons.menu),
          )
        ],
      ),
      body: Column(children: [
        Text("Bitte den typ wählen, der gepostet werden soll"),
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
        Text("Bitte den Raum auswählen, in den gepostet werden soll:"),
        FutureBuilder(
            future: _getJoinedRooms(),
            builder: (ctx, snapshot) {
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
                    [Text("no rooms found... please add one first!")]
              ]).toList()));
            }),
      ]),
      endDrawer: const Menu(),
    );
  }
}
