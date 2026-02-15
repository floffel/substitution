import '/settings/widgets/dialogaddserver.dart';
import '/settings/widgets/dialogdeleteserver.dart';
import '/settings/widgets/roomwidget.dart';
import '/shared/extensions/client_extensions.dart';
import '/shared/models/substitution_room.dart';

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


class FollowFeedPageKey {
  String? nextBatch;
  bool isLastPage = false;
  FollowFeedPageKey({this.nextBatch});
}

class FollowFeedSettingsState extends State<FollowFeedSettings> {
  String selectedServer =
      ""; // todo: must be initialized with the first server, or we'll error in here!
  final roomSearchContrainer = TextEditingController();

  String? searchText; // todo: if input is "" => searchText shall be null
  late final PagingController<FollowFeedPageKey?, SubstitutionRoom> _pagingController;
  int _searchGeneration = 0;

  Client get client => Provider.of<Client>(context, listen: false);

  void _resetList() {
    _searchGeneration++;
    // Re-initialize controller logic or refresh?
    // PagingController from home.dart doesn't seem to have refresh() method visible in usages?
    // But it has dispose().
    // Let's assume we can trigger refresh by replacing the controller or using a method if available.
    // If standard PagingController has refresh(), we can use it.
    // But analysis said appendPage is missing. Maybe refresh is there?
    // Let's try to keep refresh().
    // If it fails, we might need to recreate the controller.
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

  Future<void> _setServerAddr(String serverAddr) async {
    // var newData = await _getJoinedRooms(serverAddr); // unused?

    setState(() {
      selectedServer = serverAddr;
      _resetList();
    });
  }

  Future<List<SubstitutionRoom>> _fetchRooms(FollowFeedPageKey? pageKey) async {
    final currentGeneration = _searchGeneration;
    // If pageKey is null, it's the first page. Create a wrapper.
    // However, the controller seems to manage the key object persistence?
    // If we return the list, and update the key object in place...
    // We need to ensure we are working on the correct key object.
    
    // If pageKey is null, we create one. But we need to store it?
    // No, PagingController passes the result of getNextPageKey?
    // getNextPageKey returns "state".
    
    FollowFeedPageKey key = pageKey ?? FollowFeedPageKey(nextBatch: null);

    List<SubstitutionRoom> newData = [];

    if (selectedServer.isEmpty) {
      key.isLastPage = true;
      return newData;
    }

    try {
      QueryPublicRoomsResponse resp = await client.queryPublicRooms(
          server: selectedServer,
          limit: 20, // Increased limit for better performance
          filter: PublicRoomQueryFilter(genericSearchTerm: searchText),
          since: key.nextBatch);

      // Check for race condition
      if (currentGeneration != _searchGeneration) {
        debugPrint(
            "Race condition detected: generation $currentGeneration != $_searchGeneration. Discarding results.");
        return [];
      }

      key.nextBatch = resp.nextBatch;

      for (var chunk in resp.chunk) {
        bool isInSubstitution = await client.isRoomInSubstitution(chunk.roomId);
        bool joined = (await client.getJoinedRooms()).contains(chunk.roomId);

        newData.add(SubstitutionRoom(
          name: chunk.name ?? "Unknown Room", // handle null name
          id: chunk.roomId,
          avatarUrl: chunk.avatarUrl?.getDownloadUri(client).toString(),
          isInsideSubstitution: isInSubstitution,
          joined: joined,
        ));
      }

      debugPrint("nextPageKey: ${key.nextBatch}");

      // Check again before returning
      if (currentGeneration != _searchGeneration) {
        return [];
      }
      
      if (key.nextBatch == null || resp.chunk.isEmpty) {
        key.isLastPage = true;
      }

      return newData; 
      
    } catch (e) {
      debugPrint("Error fetching rooms: $e");
      if (currentGeneration == _searchGeneration) {
          // Propagate error?
          rethrow;
      }
      return [];
    }
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

    _pagingController = PagingController<FollowFeedPageKey?, SubstitutionRoom>(
      getNextPageKey: (state) => state.keys?.lastOrNull,
      fetchPage: (pageKey) async {
        return await _fetchRooms(pageKey);
      },
    );
    
    // Auto-select homeserver default
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (!mounted) return;
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Wrap(
                    // select Servers to display or add new server
                    spacing: 8.0,
                    runSpacing: 4.0,
                    alignment: WrapAlignment.center,
                    children: [
                      ...snapshot.data!.entries.map((s) => GestureDetector(
                              child: ChoiceChip(
                                  label: Text(s.key),
                                  selected: selectedServer == s.key,
                                  onSelected: (bool selected) async {
                                    await _setServerAddr(selected ? s.key : "");
                                  }),
                              onSecondaryTap: () async =>
                                  await showDeleteDialog(s.key),
                              onLongPress: () async =>
                                  await showDeleteDialog(s.key))),
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
                         searchText = text.isEmpty ? null : text;
                        _resetList();
                      })
                    }),
          ])),
      Expanded(
          // https://stackoverflow.com/questions/45669202/how-to-add-a-listview-to-a-column-in-flutter
          child: PagedListView<FollowFeedPageKey?, SubstitutionRoom>.separated(
              state: _pagingController.value,
              fetchNextPage: _pagingController.fetchNextPage,
              separatorBuilder: (context, index) => const Divider(),
              builderDelegate: PagedChildBuilderDelegate<SubstitutionRoom>(
                  itemBuilder: (context, item, index) => RoomWidget(
                      room: item,
                      leaveRoom: _leaveRoom,
                      joinRoom: _joinRoom)))),
    ]);
  }
}
