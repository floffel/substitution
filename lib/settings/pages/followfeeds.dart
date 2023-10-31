import 'package:substitution/settings/widgets/menu.dart';

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:substitution/settings/widgets/dialogaddserver.dart';
import 'package:substitution/settings/widgets/dialogdeleteserver.dart';
import 'package:substitution/settings/widgets/roomwidget.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String selectedServer =
      ""; // todo: must be initialized with the first server, or we'll error in here!
  final roomSearchContrainer = TextEditingController();

  String? searchText; // todo: if input is "" => searchText shall be null
  final PagingController<String?, Map<String, dynamic>> _pagingController =
      PagingController(firstPageKey: null);

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
          "room id: ${roomId}, domain: ${roomId.domain}, selectedServer: $serverAddr");
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

      debugPrint("item list: ${_pagingController.itemList}");

      // todo: load joined rooms

      // todo: as soon as we have long running querys, the pagingController gets refreshed without waiting for the requests to complete beforehand... we have to check this!
      // mby inside fetchRooms with a field startedTimestamp and lastResetTimestamp and if we are at the end of the fetch, we shall only add it if we get lastResetTimestamp < startedTimestamp
      _resetList();
      _pagingController.itemList = newData;
      // todo: set itemList to joined rooms according to the server and filter it!

      // todo: add listener and remove listener!
    });
  }

  Future<void> _fetchRooms(String? pageKey) async {
    int startTime = DateTime.now()
        .millisecondsSinceEpoch; // for catching long runs while already reset

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

    debugPrint("nextPageKey: ${nextPageKey}");

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
        _fetchRooms(nextPageKey);
      }
    } else {
      if (nextPageKey != null) {
        _pagingController.appendPage([ret], nextPageKey);
      } else {
        _pagingController.appendLastPage([ret]);
      }
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
    _pagingController.addPageRequestListener((pageKey) {
      _fetchRooms(pageKey);
    });

    super.initState();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    roomSearchContrainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //accountData.then((a) => {debugPrint("Returned account data: ${a}")});

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
      body: Container(
          alignment: Alignment.center,
          child: Column(children: [
            Text("Server zum filtern auswählen, oder einen neuen hinzufügen:"),
            Padding(
                padding: EdgeInsets.all(16.0),
                child: FutureBuilder(
                    future: accountData,
                    builder: (ctx, snapshot) {
                      return Wrap(
                          // select Servers to display or add new server
                          spacing: 8.0,
                          runSpacing: 4.0,
                          alignment: WrapAlignment.center,
                          children: [
                            ...snapshot.data?.entries.map((s) =>
                                    GestureDetector(
                                        child: ChoiceChip(
                                            label: Text(s.key),
                                            selected: selectedServer == s.key,
                                            onSelected: (bool selected) async {
                                              await _setServerAddr(
                                                  selected ? s.key : "");
                                            }),
                                        onSecondaryTap: () async =>
                                            await showDeleteDialog(s.key),
                                        onLongPress: () async =>
                                            await showDeleteDialog(s.key))) ??
                                [],

                            /*ChoiceChip(
                    label: Text('server.matrix.org'),
                    selected: true, // todo
                    /*todo onSelected: (bool selected) {
                      setState(() {
                        _value = selected ? index : null;
                      });
                    },*/
                  ),
                  ChoiceChip(
                    label: Text('other-server.matrix.org'),
                    selected: false, // todo

                    /*todo onSelected: (bool selected) {
                      setState(() {
                        _value = selected ? index : null;
                      });
                    },*/
                  ),
                  */

                            ActionChip(
                              avatar: Icon(Icons.add),
                              label: const Text('add a new server'),
                              onPressed: () async => await showAddDialog(),
                            )
                          ]);
                    })),

            // TODO: wir können es doch open für alles machen!
            // wir können einmal in account_data reinschreiben, welche server wir konfiguriert haben
            // und pro room noch einmal in account_data reinschreiben, dass wir hier gejoined sind für substitution!
            // das wird automatisch synchronisiert mit client.setAccountData und getAccountData und getAccountDataPerRoom oder getRoomTags
            // mann kann auch auf servern nach public räumen suchen per client.getPublicRooms (das könnte man auch zur verifizierung nehmen)

            // todo client.getJoinedRooms sollte als erstes auch ohne suchauswahl kommen, dait man schnell sieht, welchen man folgt
            // leaveRoom fürs leaven

            Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(children: [
                  const Text(
                      "Suche nach einem Raum, um ihm zu folgen oder zu entfolgen:"),
                  TextFormField(
                      controller: roomSearchContrainer,
                      decoration: InputDecoration(
                        labelText: "Roomname",
                      ),
                      onChanged: (String text) => {
                            setState(() {
                              _resetList();
                              searchText = text;
                            })
                          }),
                ])),

            //if (searchText != null) ...[

            // todo: joined rooms für den jeweiligen room hier am anfang anstellen!

            // todo: auslagern in ein extra widget, weil wir es ja zwei mal brauchen!
            Expanded(
                // https://stackoverflow.com/questions/45669202/how-to-add-a-listview-to-a-column-in-flutter
                child: PagedListView.separated(
                    pagingController: _pagingController,
                    separatorBuilder: (context, index) => const Divider(),
                    builderDelegate: PagedChildBuilderDelegate<
                            Map<String, dynamic>>(
                        itemBuilder: (context, item, index) => RoomWidget(
                            items: item,
                            leaveRoom: _leaveRoom,
                            joinRoom: _joinRoom)

                        /*ListTile(
                        title: Text(
                            'Raum: ${item["name"]}, joined: ${item["joined"]}, isInsideSubstitution: ${item["isInsideSubstitution"]}'),
                        subtitle: Text(item["id"]),
                        leading: item["avatarUrl"] != null
                            ? Image.network(item["avatarUrl"])
                            : const Text("no img"),
                        trailing:
                            (item["isInsideSubstitution"] && item["joined"])
                                ? IconButton(
                                    icon: const Icon(Icons.person_remove),
                                    tooltip: 'leave',
                                    onPressed: () async {
                                      // todo: loading animation
                                      await _leaveRoom(item["id"]);

                                      setState(() {});
                                    },
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.person_add),
                                    tooltip: 'join',
                                    onPressed: () async {
                                      // todo: loading animation
                                      await _joinRoom(item["id"]);

                                      setState(() {});
                                    },
                                  ),
                      ),*/

                        ))),

            /*
        Padding(
            padding: EdgeInsets.all(16.0),
            child: SearchAnchor(
                builder: (BuildContext context, SearchController controller) {
              return SearchBar(
                controller: controller,
                padding: const MaterialStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 16.0)),
                onTap: () {
                  controller.openView();
                },
                onChanged: (_) {
                  controller.openView();
                },
                leading: const Icon(Icons.search),
                trailing: <Widget>[
                  // TODO: group_add nur machen, wenn man noch nicht folgt, sonst group_off machen!
                  Tooltip(
                    message: 'Follow room',
                    child: IconButton(
                      //isSelected: isDark,
                      onPressed: () {
                        //setState(() {
                        //isDark = !isDark;
                        //}
                        //);
                      },
                      icon: const Icon(Icons.group_add),
                    ),
                  ),
                  Tooltip(
                    message: 'Unfollow room',
                    child: IconButton(
                      //isSelected: isDark,
                      onPressed: () {
                        //setState(() {
                        //isDark = !isDark;
                        //}
                        //);
                      },
                      icon: const Icon(Icons.group_off),
                    ),
                  )
                ],
              );
            }, suggestionsBuilder:
                    (BuildContext context, SearchController controller) {
              // hier nehmen wir für alle server einfach

              // hier brauchen wir natürlich noch das gleiche für alle Server, denen man folgt...
              /*  // ausserdem muss man vmtl. noch checken, ob der archiviert ist etc.
                          List<dynamic>? get spaces => Provider.of<Client>(context, listen: false)
                              .getRoomByAlias("#substitution:matrix.org")
                              ?.spaceChildren;
                        
                          List<Room>? get rooms => spaces
                              ?.map((element) => Room(
                                  id: element.roomId,
                                  client: Provider.of<Client>(context, listen: false)))
                              .toList();
                              */

              return List<ListTile>.generate(5, (int index) {
                final String item = 'item $index';
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    setState(() {
                      controller.closeView(item);
                    });
                  },
                );
              });
            })),
            */

            /*List<ListTile>.generate(5, (int index) {
                final String item = 'item $index';
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    setState(() {
                     // controller.closeView(item);
                    });
                  },
                );
              }),*/

            // TODO: hier was zum adden/suchen von neuen räumen hinzufügen, auch von servern
            // das hier am besten nach servern aufteilen. Vielleicht auch nach servern filtern?
            //ListView(children: [])
          ])),
      endDrawer: const Menu(),
    );
  }
}
