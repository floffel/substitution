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
  final PagingController<String?, Map<String, dynamic>> _pagingController =
      PagingController(
        fetchPage: _fetchRooms, // Use fetchPage callback
        firstPageKey: null, // Provide the initial page key
      );

  Client get client => Provider.of<Client>(context, listen: false);

  int lastResetTime = DateTime.now()
      .millisecondsSinceEpoch; // for catching long runs while already reset

  void _resetList() {
    lastResetTime =
        DateTime.now().millisecondsSinceEpoch; //... works not as expected
    // TODO: [infinite_scroll_pagination_migration] Verify behavior of refresh().
    // It should clear current items and trigger the first page fetch.
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
    setState(() {
      selectedServer = serverAddr;
      // TODO: [infinite_scroll_pagination_migration] The logic for displaying joined rooms vs public rooms
      // needs clarification. Originally, _getJoinedRooms(serverAddr) was called and its data
      // was assigned to _pagingController.itemList after _resetList().
      // With the new model, _pagingController.refresh() should trigger _fetchRooms(null).
      // _fetchRooms would then need to be responsible for fetching data for the new 'selectedServer'.
      // If joined rooms are to be displayed distinctly or first, _fetchRooms needs to handle that,
      // or a separate mechanism/controller is needed for them.
      // For now, we just refresh, and _fetchRooms will run with the new selectedServer context.
    });
     _pagingController.refresh(); // This should trigger _fetchRooms(null) for the new server.
  }

  Future<void> _fetchRooms(String? pageKey) async {
    // TODO: [infinite_scroll_pagination_migration] This function's logic for fetching one item
    // and recursively calling itself if the item is skipped is complex and might be inefficient.
    // Consider refactoring to fetch a batch and filter, then append the batch.
    // For now, adapting existing logic to PagingState.

    int startTime = DateTime.now()
        .millisecondsSinceEpoch; // for catching long runs while already reset
    String? currentPageKey = pageKey;

    try {
      Map<String, dynamic> ret = {
        // todo: do it with a typedef https://stackoverflow.com/questions/24762414/is-there-anything-like-a-struct-in-dart
      "name": null,
      "id": null,
      "isInsideSubstitution": false,
      "joined": false,
    };

    //debugPrint("fetch rooms");

    /*if (selectedServer == "") {
      _pagingController.error = "nothing found";
      return;
    }*/

    QueryPublicRoomsResponse resp = await client.queryPublicRooms(
        server: selectedServer,
        limit: 1,
        filter: PublicRoomQueryFilter(genericSearchTerm: searchText),
        since: pageKey);

    final String? nextPageKey = resp.nextBatch;

    //_pagingController.appendPage(newItems, nextPageKey);
    //List<PublicRoomsChunk> chunk = resp.chunk;
    //chunk[0].roomId;

    // todo: passive programming. The room should exist, but better program passive than be sorry
    //Room? room = Provider.of<Client>(context, listen: false).getRoomById(chunk[0]
    //    .roomId); // todo: passive programming, go to 404 or smthg if room does not exist

    /*Room? room = Room(
        id: chunk[0].roomId,
        client: Provider.of<Client>(context, listen: false));
    */

    //await room.requestHistory(historyCount: 1);

    // todo: filter with itemList

    if (resp.chunk.isEmpty) {
      return; // no data available
    }

    ret["name"] = resp.chunk[0].name;
    ret["id"] = resp.chunk[0].roomId;
    ret["avatarUrl"] =
        resp.chunk[0].avatarUrl?.getDownloadLink(client).toString();

    // todo get account data and if we joined already

    // todo: this only works with logged in clients!
    try {
      ret["isInsideSubstitution"] = (await client.getAccountDataPerRoom(
              client.userID!, ret["id"], "substitution"))["joined"] ==
          true;
    } catch (_) {} // we cannot get the account data

    // todo chache getJoinedRooms !
    ret["joined"] = (await client.getJoinedRooms()).contains(ret["id"]);

    //debugPrint("Room name: ${room.name}");

    debugPrint("nextPageKey: $nextPageKey");

    //int startTime = DateTime.now().millisecondsSinceEpoch; // for catching long runs while already reset
      if (lastResetTime > startTime) {
        debugPrint(
            "reset happend before we finished! $lastResetTime > $startTime");
        return; // we where reset before the querys ended, so discard this values!
      }

      // todo: this if looks like we could make it more readable...
      // we have to call this method again to get an unjoined room
      if (ret["joined"] && ret["isInsideSubstitution"]) {
        if (nextPageKey != null) {
          // Item skipped, fetch next. Current items and error state remain unchanged.
          // This recursive call might need a depth limit or other guards in a real scenario.
          if (!mounted) return;
          await _fetchRooms(nextPageKey);
        } else {
          // Skipped an item, but it was the last one from the server's perspective for this query.
          // Effectively, this means we append nothing and there's no next page from this path.
          final oldItems = _pagingController.value.items ?? []; // itemList -> items
          _pagingController.value = PagingState(
            items: oldItems, // No new items added // itemList -> items
            nextPageKey: null,    // No next page from this path
            error: null,
          );
        }
      } else {
        // This is an item to display
        final oldItems = _pagingController.value.items ?? []; // itemList -> items
        _pagingController.value = PagingState(
          items: [...oldItems, ret], // Append the new item // itemList -> items
          nextPageKey: nextPageKey,      // nextPageKey can be null here if it's the last item
          error: null,
        );
      }
    } catch (e, stackTrace) {
      debugPrint("Error in _fetchRooms: $e\n$stackTrace");
      _pagingController.value = PagingState(
        items: _pagingController.value.items, // Preserve current items // itemList -> items
        nextPageKey: currentPageKey, // Preserve key for potential retry
        error: e,
      );
    }

    // set sice = resp.nextBatch

    // todo: apply since!

    // TODO: filter out spaces...
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
    // _fetchRooms is now hooked into PagingController via fetchPage parameter.
    // The PagingController will call it with firstPageKey.
    // Manual call _fetchRooms(null); is no longer needed.
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
              future: accountData,
              builder: (ctx, snapshot) {
                return Wrap(
                    // select Servers to display or add new server
                    spacing: 8.0,
                    runSpacing: 4.0,
                    alignment: WrapAlignment.center,
                    children: [
                      ...snapshot.data?.entries.map((s) => GestureDetector(
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
          child: PagedListView.separated(
              // TODO: [infinite_scroll_pagination_migration] Verify 'controller' and other params.
              controller: _pagingController,
              separatorBuilder: (context, index) => const Divider(),
              builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
                  itemBuilder: (context, item, index) => RoomWidget(
                      items: item,
                      leaveRoom: _leaveRoom,
                      joinRoom: _joinRoom)))),
    ]);
  }
}
