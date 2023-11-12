import '/settings/widgets/roomwidget.dart';
import '/settings/widgets/dialogcreateroom.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class OwnFeedSettings extends StatefulWidget {
  const OwnFeedSettings({super.key});

  static OwnFeedSettingsState of(BuildContext context) {
    return context.findAncestorStateOfType<OwnFeedSettingsState>()!;
  }

  @override
  OwnFeedSettingsState createState() => OwnFeedSettingsState();
}

/*
TODO: hier sollen die _eigenen_ feeds gemanaged werden, also quasi für "influencer",
also so sachen wie "löschen" des feeds, vielleicht "automatische konfiguration", etc.
*/

class OwnFeedSettingsState extends State<OwnFeedSettings> {
  Client get client => Provider.of<Client>(context, listen: false);

  // TODO: this is exactly the same method as in followfeeds.dart -> make it abstract, or a mixin or something
  String selectedServer =
      ""; // todo: must be initialized with the first server, or we'll error in here!

  List<Map<String, dynamic>> data =
      []; // todo: this is adapted from _getJoinedRooms, make it a struct-like type!

  @override
  void initState() {
    super.initState();
  }

  // TODO: this is NOT! exactly but mostly (only added check if the user has powerlevel > 50, removed server filtering) the same method as in followfeeds.dart -> make it abstract, or a mixin or something
  Future<List<Map<String, dynamic>>> _getJoinedRooms() async {
    List<Map<String, dynamic>> newData = [];

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

      if (!isInSubstitution) {
        continue;
      }

      // todo: could be a field inside add, if one would make this method a mixin
      if (r.ownPowerLevel < 50) {
        continue; // checks if the user has the posting privilege (>=50)
      }

      Map<String, dynamic> add = {
        // todo: do it with a typedef https://stackoverflow.com/questions/24762414/is-there-anything-like-a-struct-in-dart
        "name": r.name,
        "id": r.id,
        "isInsideSubstitution": isInSubstitution,
        "joined": true,
      };

      newData.add(add);
    }

    return newData;
  }

  // TODO: this is exactly the same method as in followfeeds.dart -> make it abstract, or a mixin or something
  Future<Map<String, Object?>> get accountData async =>
      await client.getAccountData(client.userID!, "substitution.servers");

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("settings.ownfeeds.header").tr(),
      TextButton(
          child: const Text("settings.ownfeeds.buttons.create_room").tr(),
          onPressed: () async {
            await showDialog<void>(
              context: context,
              barrierDismissible: true,
              builder: (BuildContext context) {
                return const DialogCreateRoom();
              },
            );
            setState(() {});
          }),
      FutureBuilder(
          future: _getJoinedRooms(),
          builder: (ctx, snapshot) {
            if (!snapshot.hasData) {
              return const Text("loading").tr();
            }

            return Column(
                children: ListTile.divideTiles(context: ctx, tiles: [
              ...snapshot.data?.map((d) => RoomWidget(items: d
                  // todo: delete room
                  )) ?? []
            ]).toList());
          })
    ]);
  }
}
