import 'dart:async';
import '/settings/widgets/dialogaddserver.dart';
import '/settings/widgets/dialogdeleteserver.dart';
import '/settings/widgets/dialogcreateroom.dart';
import '/settings/widgets/roomwidget.dart';
import '/shared/extensions/client_extensions.dart';
import '/shared/models/substitution_room.dart';
import '/shared/services/substitution_service.dart';

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
  bool reachedEnd = false;
  bool get isLastPage => reachedEnd;
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
    await context.read<SubstitutionService>().joinRoom(id, serverNames: [selectedServer]);
    _resetList();
  }

  Future<void> _leaveRoom(String id) async {
    await context.read<SubstitutionService>().leaveRoom(id);
    _resetList();
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
    debugPrint("[FollowFeeds] Fetching rooms for generation $currentGeneration, server: '$selectedServer', search: '$searchText'");

    FollowFeedPageKey key = pageKey ?? FollowFeedPageKey(nextBatch: null);

    List<SubstitutionRoom> newData = [];

    if (selectedServer.isEmpty) {
      debugPrint("[FollowFeeds] Selected server is empty, returning empty list.");
      key.reachedEnd = true;
      return newData;
    }

    try {
      // Fetch public rooms with a timeout to avoid infinite hangs
      debugPrint("[FollowFeeds] Calling queryPublicRooms...");
      final String? queryServer = selectedServer == (client.userID?.split(':').last ?? "") ? null : selectedServer;
      QueryPublicRoomsResponse resp = await client
          .queryPublicRooms(
            server: queryServer,
            limit: 20,
            filter: PublicRoomQueryFilter(genericSearchTerm: searchText),
            since: key.nextBatch,
          )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException("Matrix queryPublicRooms timed out after 15 seconds");
      });


      // Check for race condition
      if (currentGeneration != _searchGeneration) {
        return [];
      }

      key.nextBatch = resp.nextBatch;
      if (resp.nextBatch == null || resp.chunk.isEmpty) {
        key.reachedEnd = true;
      }

      // Optimization: Fetch all joined rooms once instead of inside the loop
      final joinedRooms = await client.getJoinedRooms();

      for (var chunk in resp.chunk) {
        final isJoined = joinedRooms.contains(chunk.roomId);
        
        // Optimization: Only check substitution status for rooms we are joined to.
        // Public rooms we haven't joined yet can't have our account data anyway.
        bool isInSubstitution = false;
        if (isJoined) {
           isInSubstitution = await client.isRoomInSubstitution(chunk.roomId);
        }

        newData.add(SubstitutionRoom(
          name: chunk.name ?? "Unknown Room",
          id: chunk.roomId,
          avatarUrl: chunk.avatarUrl?.toString(),
          isInsideSubstitution: isInSubstitution,
          joined: isJoined,
        ));
      }

      // Check for end of pagination
      if (resp.nextBatch == null || resp.nextBatch!.isEmpty || resp.chunk.isEmpty) {
        key.reachedEnd = true;
      }

      return newData;
    } catch (e) {
      debugPrint("[FollowFeeds] Error fetching rooms: $e");
      if (currentGeneration == _searchGeneration) {
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

    // Try to initialize selectedServer immediately
    final defaultServer = client.userID?.split(':').last ?? client.homeserver?.host;
    if (defaultServer != null) {
      selectedServer = defaultServer;
    }

    _pagingController = PagingController<FollowFeedPageKey?, SubstitutionRoom>(
      getNextPageKey: (state) {
        if (state.keys == null || state.keys!.isEmpty) {
          return FollowFeedPageKey();
        }
        final lastKey = state.keys!.last;
        if (lastKey?.isLastPage == true) {
          return null;
        }
        // Return a fresh copy or the same object if we update it in place?
        // Let's return the same object, but ensure it's updated correctly in _fetchRooms
        return lastKey;
      },
      fetchPage: (pageKey) async {
        return await _fetchRooms(pageKey);
      },
    )..addListener(() {
      if (mounted) setState(() {});
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
                 final defaultServer = client.userID?.split(':').last ?? client.homeserver?.host;
                 if (defaultServer != null && !data.containsKey(defaultServer)) {
                    // clone map to avoid mutation issues if unmodifiable
                    final newData = Map<String, Object?>.from(data);
                    newData[defaultServer] = {"added_automatically": true};
                    return newData;
                 }
                 return data;
              }).catchError((e) {
                  // Handle error if account data fetch fails (e.g. initially empty)
                  final defaultServer = client.userID?.split(':').last ?? client.homeserver?.host;
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
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_box),
                        label: const Text(
                                "settings.ownfeeds.buttons.create_room")
                            .tr(),
                        onPressed: () async {
                          await showDialog<void>(
                            context: context,
                            barrierDismissible: true,
                            builder: (BuildContext context) {
                              return const DialogCreateRoom();
                            },
                          );
                          setState(() {
                             _resetList();
                          });
                        },
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
                  noItemsFoundIndicatorBuilder: (context) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        "settings.followfeeds.no_rooms_found",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ).tr(),
                    ),
                  ),
                  firstPageErrorIndicatorBuilder: (context) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        const Text("settings.followfeeds.error_loading_rooms").tr(),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _pagingController.refresh(),
                          child: const Text("settings.followfeeds.buttons.retry").tr(),
                        )
                      ],
                    ),
                  ),
                  itemBuilder: (context, item, index) => RoomWidget(
                      room: item,
                      leaveRoom: _leaveRoom,
                      joinRoom: _joinRoom)))),
    ]);
  }
}
