import 'dart:async';
import '/settings/widgets/dialogaddserver.dart';
import '/settings/widgets/dialogdeleteserver.dart';
import '/settings/widgets/dialogcreateroom.dart';
import '/settings/widgets/roomwidget.dart';
import '/settings/widgets/sheet_room_preview.dart';
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
  String selectedServer = "";
  final roomSearchContrainer = TextEditingController();

  String? searchText;
  late final PagingController<FollowFeedPageKey?, SubstitutionRoom>
  _pagingController;
  int _searchGeneration = 0;

  /// Cached account-data future (including the .then/.catchError transform) so
  /// FutureBuilder always receives the same Future object and never resets to
  /// ConnectionState.waiting on rebuild — which would cause an infinite loop.
  Future<Map<String, Object?>>? _accountDataFuture;

  Client get client => Provider.of<Client>(context, listen: false);

  void _resetList() {
    _searchGeneration++;
    _pagingController.refresh();
  }

  Future<void> _joinRoom(String id) async {
    await context.read<SubstitutionService>().joinRoom(
      id,
      serverNames: [selectedServer],
    );
    _resetList();
  }

  Future<void> _leaveRoom(String id) async {
    await context.read<SubstitutionService>().leaveRoom(id);
    _resetList();
  }

  Future<void> _setServerAddr(String serverAddr) async {
    _searchGeneration++;
    setState(() {
      selectedServer = serverAddr;
    });
    _pagingController.refresh();
  }

  Future<List<SubstitutionRoom>> _fetchRooms(FollowFeedPageKey? pageKey) async {
    final currentGeneration = _searchGeneration;
    debugPrint(
      "[FollowFeeds] Fetching rooms for generation $currentGeneration, server: '$selectedServer', search: '$searchText'",
    );

    FollowFeedPageKey key = pageKey ?? FollowFeedPageKey(nextBatch: null);

    List<SubstitutionRoom> newData = [];

    if (selectedServer.isEmpty) {
      debugPrint(
        "[FollowFeeds] Selected server is empty, returning empty list.",
      );
      key.reachedEnd = true;
      return newData;
    }

    try {
      debugPrint("[FollowFeeds] Calling queryPublicRooms...");
      final String? queryServer =
          selectedServer == (client.userID?.split(':').last ?? "")
              ? null
              : selectedServer;
      QueryPublicRoomsResponse resp = await client
          .queryPublicRooms(
            server: queryServer,
            limit: 20,
            filter: PublicRoomQueryFilter(genericSearchTerm: searchText),
            since: key.nextBatch,
          )
          .timeout(
            // 8 seconds — short enough that the timer fires reliably even on
            // slow Android emulators in CI, while still giving real servers
            // enough time to respond.
            const Duration(seconds: 8),
            onTimeout: () {
              throw TimeoutException(
                "Matrix queryPublicRooms timed out after 8 seconds",
              );
            },
          );

      if (currentGeneration != _searchGeneration) {
        return [];
      }

      key.nextBatch = resp.nextBatch;
      if (resp.nextBatch == null || resp.chunk.isEmpty) {
        key.reachedEnd = true;
      }

      final joinedRooms = await client.getJoinedRooms();

      for (var chunk in resp.chunk) {
        final isJoined = joinedRooms.contains(chunk.roomId);

        bool isInSubstitution = false;
        if (isJoined) {
          isInSubstitution = await client.isRoomInSubstitution(chunk.roomId);
        }

        newData.add(
          SubstitutionRoom(
            name: chunk.name ?? "Unknown Room",
            id: chunk.roomId,
            avatarUrl: chunk.avatarUrl?.toString(),
            isInsideSubstitution: isInSubstitution,
            joined: isJoined,
            topic: chunk.topic,
            numJoinedMembers: chunk.numJoinedMembers,
            worldReadable: chunk.worldReadable,
          ),
        );
      }

      if (resp.nextBatch == null ||
          resp.nextBatch!.isEmpty ||
          resp.chunk.isEmpty) {
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

  /// Returns the cached, fully-transformed account-data future.
  /// The .then/.catchError transform is included in the cache so that
  /// FutureBuilder never sees a new Future object on rebuild.
  Future<Map<String, Object?>> get accountData =>
      _accountDataFuture ??= _buildAccountDataFuture();

  Future<Map<String, Object?>> _buildAccountDataFuture() {
    final defaultServer =
        client.userID?.split(':').last ?? client.homeserver?.host;
    return client
        .getAccountData(client.userID!, "substitution.servers")
        .then((data) {
          if (defaultServer != null && !data.containsKey(defaultServer)) {
            final newData = Map<String, Object?>.from(data);
            newData[defaultServer] = {"added_automatically": true};
            return newData;
          }
          return data;
        })
        .catchError((e) {
          if (defaultServer != null) {
            return <String, Object?>{
              defaultServer: {"added_automatically": true},
            };
          }
          return <String, Object?>{};
        });
  }

  Future<void> showDeleteDialog(String server) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return DialogDeleteServer(server: server);
      },
    );

    setState(() {
      _accountDataFuture = null; // invalidate so chips reload
    });
  }

  Future<void> showAddDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return const DialogAddServer();
      },
    );

    setState(() {
      _accountDataFuture = null; // invalidate so chips reload
    });
  }

  @override
  void initState() {
    super.initState();

    final defaultServer =
        client.userID?.split(':').last ?? client.homeserver?.host;
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
        return lastKey;
      },
      fetchPage: (pageKey) async {
        return await _fetchRooms(pageKey);
      },
    );
    // Note: do NOT addListener(setState) here. Doing so causes the entire
    // FollowFeedSettings subtree (including FutureBuilder(accountData)) to
    // rebuild on every PagingController state change, which in turn schedules
    // more post-frame callbacks → infinite rebuild loop under pumpAndSettle.
    // Instead, only the PagedListView is wrapped in a ListenableBuilder so
    // only the list portion rebuilds when the paging state changes.
  }

  @override
  void dispose() {
    _pagingController.dispose();
    roomSearchContrainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Server filter section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "settings.followfeeds.filter_server_header".tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FutureBuilder(
            // accountData is fully cached (including .then/.catchError) so
            // FutureBuilder always receives the same Future object each build.
            future: accountData,
            builder: (ctx, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Wrap(
                spacing: 8.0,
                runSpacing: 6.0,
                alignment: WrapAlignment.center,
                children: [
                  ...snapshot.data!.entries.map(
                    (s) => GestureDetector(
                      child: ChoiceChip(
                        label: Text(s.key),
                        selected: selectedServer == s.key,
                        onSelected: (bool selected) async {
                          await _setServerAddr(selected ? s.key : "");
                        },
                      ),
                      onSecondaryTap: () async => await showDeleteDialog(s.key),
                      onLongPress: () async => await showDeleteDialog(s.key),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label:
                        const Text(
                          "settings.followfeeds.buttons.add_server",
                        ).tr(),
                    onPressed: () async => await showAddDialog(),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add_box_rounded, size: 18),
                    label:
                        const Text(
                          "settings.ownfeeds.buttons.create_room",
                        ).tr(),
                    onPressed: () async {
                      await showDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        builder: (BuildContext context) {
                          return const DialogCreateRoom();
                        },
                      );
                      _searchGeneration++;
                      setState(() {});
                      _pagingController.refresh();
                    },
                  ),
                ],
              );
            },
          ),
        ),

        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "settings.followfeeds.filter_rooms_header".tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: roomSearchContrainer,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  labelText: "settings.followfeeds.roomname_placeholder".tr(),
                ),
                onChanged: (String text) {
                  _searchGeneration++;
                  setState(() {
                    searchText = text.isEmpty ? null : text;
                  });
                  // Refresh the paging controller outside of setState so
                  // its notifyListeners() call doesn't race with the build
                  // cycle. The ListenableBuilder will pick up the new state
                  // on the very next frame.
                  _pagingController.refresh();
                },
              ),
            ],
          ),
        ),

        // Room list — wrapped in ListenableBuilder so only this subtree
        // rebuilds when the paging state changes (avoids full-widget rebuild
        // that would re-create FutureBuilder's future and cause an
        // infinite rebuild loop under pumpAndSettle).
        Expanded(
          child: ListenableBuilder(
            listenable: _pagingController,
            builder:
                (context, _) => PagedListView<
                  FollowFeedPageKey?,
                  SubstitutionRoom
                >.separated(
                  state: _pagingController.value,
                  fetchNextPage: _pagingController.fetchNextPage,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 2),
                  builderDelegate: PagedChildBuilderDelegate<SubstitutionRoom>(
                    noItemsFoundIndicatorBuilder:
                        (context) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "settings.followfeeds.no_rooms_found",
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ).tr(),
                              ],
                            ),
                          ),
                        ),
                    firstPageErrorIndicatorBuilder:
                        (context) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: colorScheme.error,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "settings.followfeeds.error_loading_rooms",
                              ).tr(),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: () => _pagingController.refresh(),
                                icon: const Icon(Icons.refresh_rounded),
                                label:
                                    const Text(
                                      "settings.followfeeds.buttons.retry",
                                    ).tr(),
                              ),
                            ],
                          ),
                        ),
                    itemBuilder:
                        (context, item, index) => RoomWidget(
                          room: item,
                          leaveRoom: _leaveRoom,
                          joinRoom: _joinRoom,
                          onTap:
                              () => showRoomPreview(
                                context: context,
                                room: item,
                                onJoin: _joinRoom,
                                onLeave: _leaveRoom,
                              ),
                        ),
                  ),
                ),
          ),
        ),
      ],
    );
  }
}
