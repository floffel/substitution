import '/settings/widgets/dialogaddserver.dart';
import '/settings/widgets/dialogdeleteserver.dart';
import '/settings/widgets/roomwidget.dart';

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class FollowFeedSettings extends StatefulWidget {
  const FollowFeedSettings({super.key});

  static FollowFeedSettingsState of(BuildContext context) {
    return context.findAncestorStateOfType<FollowFeedSettingsState>()!;
  }

  @override
  FollowFeedSettingsState createState() => FollowFeedSettingsState();
}

class FollowFeedSettingsState extends State<FollowFeedSettings> {
  String selectedServer =
      ""; // todo: must be initialized with the first server, or we'll error in here!
  final roomSearchContrainer = TextEditingController();

  String? searchText; // todo: if input is "" => searchText shall be null
  late final PagingController<String?, Map<String, dynamic>> _pagingController;

  Client get client => Provider.of<Client>(context, listen: false);

  int lastResetTime = DateTime.now()
      .millisecondsSinceEpoch; // for catching long runs while already reset

  void _resetList() {
    lastResetTime =
        DateTime.now().millisecondsSinceEpoch; //... works not as expected
    _pagingController.refresh();
  }

  Future<void> _joinRoom(String id) async {
    await client.joinRoom(id, serverName: [selectedServer]);

    // todo: this works only for logged in users
    await client.setAccountDataPerRoom(
        client.userID!, id, "substitution", {"joined": true});
    _resetList();
    setState(() {});
  }

  Future<void> _leaveRoom(String id) async {
    // todo: this works only for logged in users
    await client.setAccountDataPerRoom(client.userID!, id, "substitution", {});
    await client.leaveRoom(id);
    _resetList();
    setState(() {});
  }

  // TODO: this is more or less the same function as in write/pages/textmessage.dart -> make it abstract, or a mixin or something
  Future<List<Map<String, dynamic>>> _getJoinedRooms(String serverAddr) async {
    List<Map<String, dynamic>> newData = [];

    for (String roomId in await client.getJoinedRooms()) {
      debugPrint(
          "room id: $roomId, domain: ${roomId.domain}, selectedServer: $serverAddr");
      if (roomId.domain != serverAddr) {
        continue; // only add rooms from the selected server
      }

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

  Future<void> _setServerAddr(String serverAddr) async {
    var newData = await _getJoinedRooms(serverAddr);

    setState(() {
      selectedServer = serverAddr;

      debugPrint("item list: ${_pagingController.value}");

      // todo: load joined rooms

      // todo: as soon as we have long running querys, the pagingController gets refreshed without waiting for the requests to complete beforehand... we have to check this!
      // mby inside fetchRooms with a field startedTimestamp and lastResetTimestamp and if we are at the end of the fetch, we shall only add it if we get lastResetTimestamp < startedTimestamp
      _resetList();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchRooms(String? pageKey) async {
    int startTime = DateTime.now()
        .millisecondsSinceEpoch; // for catching long runs while already reset

    List<Map<String, dynamic>> newData = [];

    if (selectedServer.isEmpty) {
      return newData;
    }

    QueryPublicRoomsResponse resp = await client.queryPublicRooms(
        server: selectedServer,
        limit: 20, // Increased limit for better performance
        filter: PublicRoomQueryFilter(genericSearchTerm: searchText),
        since: pageKey);

    final String? nextPageKey = resp.nextBatch;

    if (resp.chunk.isEmpty) {
      return newData; // no data available
    }

    for (var chunk in resp.chunk) {
      Map<String, dynamic> roomData = {
        "name": chunk.name,
        "id": chunk.roomId,
        "avatarUrl": chunk.avatarUrl?.getDownloadUri(client).toString(),
      };

      // todo: this only works with logged in clients!
      try {
        roomData["isInsideSubstitution"] = (await client.getAccountDataPerRoom(
                client.userID!, chunk.roomId, "substitution"))["joined"] ==
            true;
      } catch (_) {} // we cannot get the account data

      roomData["joined"] =
          (await client.getJoinedRooms()).contains(chunk.roomId);

      newData.add(roomData);
    }

    debugPrint("nextPageKey: $nextPageKey");

    if (lastResetTime > startTime) {
      debugPrint(
          "reset happend before we finished! $lastResetTime > $startTime");
      return []; // we where reset before the querys ended, so discard this values!
    }

    return newData;
  }

  // TODO: client id is only valid if a user logged in! Only show this option to logged in users!
  // TODO: this throws an exception if the account data is not valid!
  // so we have to ensure, that the account data exists!
  Future<Map<String, Object?>> get accountData async =>
      await client.getAccountData(client.userID!, "substitution.servers");

  Future<void> showDeleteDialog(String server) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return DialogDeleteServer(server: server);
      },
    );

    setState(() {});
  }

  Future<void> showAddDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        return const DialogAddServer();
      },
    );

    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _pagingController = PagingController<String?, Map<String, dynamic>>(
      getNextPageKey: (state) => state.keys?.lastOrNull,
      fetchPage: _fetchRooms,
    );
    
    // Auto-select homeserver default
    WidgetsBinding.instance.addPostFrameCallback((_) {
       try {
         final defaultServer = client.homeserver?.host;
         if (defaultServer != null && selectedServer.isEmpty) {
            _setServerAddr(defaultServer);
         }
       } catch (e) {
         debugPrint("Error setting default server: $e");
       }
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    roomSearchContrainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Text("settings.followfeeds.filter_server_header").tr(),
      Padding(
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder(
              future: accountData.then((data) {
                 // Ensure default server is in the list
                 final defaultServer = client.homeserver?.host;
                 if (defaultServer != null && !data.containsKey(defaultServer)) {
                    // clone map to avoid mutation issues if unmodifiable
                    final newData = Map<String, Object?>.from(data);
                    newData[defaultServer] = {"added_automatically": true};
                    return newData;
                 }
                 return data;
              }).catchError((e) {
                  // Handle error if account data fetch fails (e.g. initially empty)
                  final defaultServer = client.homeserver?.host;
                  if (defaultServer != null) {
                    return {defaultServer: {"added_automatically": true}};
                  }
                  return <String, Object?>{};
              }),
              builder: (ctx, snapshot) {
                return Wrap(
                    // select Servers to display or add new server
                    spacing: 8.0,
                    runSpacing: 4.0,
                    alignment: WrapAlignment.center,
                    children: [
                      ...?snapshot.data?.entries.map((s) => GestureDetector(
                              child: ChoiceChip(
                                  label: Text(s.key),
                                  selected: selectedServer == s.key,
                                  onSelected: (bool selected) async {
                                    await _setServerAddr(selected ? s.key : "");
                                  }),
                              onSecondaryTap: () async =>
                                  await showDeleteDialog(s.key),
                              onLongPress: () async =>
                                  await showDeleteDialog(s.key))) ??
                          [],
                      ActionChip(
                        avatar: const Icon(Icons.add),
                        label: const Text(
                                "settings.followfeeds.buttons.add_server")
                            .tr(),
                        onPressed: () async => await showAddDialog(),
                      )
                    ]);
              })),
      Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            const Text("settings.followfeeds.filter_rooms_header").tr(),
            TextFormField(
                controller: roomSearchContrainer,
                decoration: InputDecoration(
                  labelText: "settings.followfeeds.roomname_placeholder".tr(),
                ),
                onChanged: (String text) => {
                      setState(() {
                        _resetList();
                        searchText = text;
                      })
                    }),
          ])),
      Expanded(
          // https://stackoverflow.com/questions/45669202/how-to-add-a-listview-to-a-column-in-flutter
          child: PagedListView<String?, Map<String, dynamic>>.separated(
              state: _pagingController.value,
              fetchNextPage: _pagingController.fetchNextPage,
              separatorBuilder: (context, index) => const Divider(),
              builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
                  itemBuilder: (context, item, index) => RoomWidget(
                      items: item,
                      leaveRoom: _leaveRoom,
                      joinRoom: _joinRoom)))),
    ]);
  }
}
