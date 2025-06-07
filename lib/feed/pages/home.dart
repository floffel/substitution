import '/post/widgets/post.dart';

import 'dart:convert'; // for json
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.roomId});

  // only display content of this room, if set. Otherwise: display all followed rooms content
  final String? roomId;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final adressContrainer = TextEditingController();

  PagingController<
          Map<Timeline, ({String? lastEventId, bool wasExhausted})>?,
          ({Event origEvent, Event displayEvent})>? _pagingController; // Made nullable
  bool pageKeyInitialized =
      false;
  Map<String, String> firstEventIds = {};

  Client get client => Provider.of<Client>(context, listen: false);

  Future<List<Room>> get rooms async {
    List<Room> ret = [];
    if (widget.roomId != null) {
      String roomId = widget.roomId!;
      if (roomId.startsWith("#")) {
        roomId = (await client.getRoomIdByAlias(roomId)).roomId!;
      }
      final GetRoomEventsResponse resp = await client.getRoomEvents(
        roomId,
        Direction.b,
        limit: 1,
        filter: jsonEncode(StateFilter(lazyLoadMembers: true).toJson()),
      );
      return [Room(id: roomId, client: client, prev_batch: resp.end)];
    }
    final roomIds = await client.getJoinedRooms();
    for (String roomId in roomIds) {
      Room r = client.getRoomById(roomId)!;
      try {
        final accountData = await client.getAccountDataPerRoom(
            client.userID!, roomId, "substitution");
        if (accountData["joined"] == true) {
          ret.add(r);
        }
      } catch (_) {}
    }
    return ret;
  }

  Future<List<Timeline>> get timelines async {
    final roomList = await rooms;
    final timelineFutures = roomList.map((r) => r.getTimeline()).toList();
    return Future.wait(timelineFutures);
  }

  Future<void> _fetchFutureEvents() async {
    // This method is now only responsible for triggering a refresh.
    // The actual fetching of future/latest events should be handled by _fetchEvents
    // when it's called with the firstPageKey (e.g., null) due to the refresh.
    _pagingController!.refresh();
  }

  Future<void> _fetchEvents(Map<Timeline, ({String? lastEventId, bool wasExhausted})>? pageKey) async {
    Map<Timeline, ({String? lastEventId, bool wasExhausted})>? currentPageKey = pageKey;
    List<({Event origEvent, Event displayEvent})> fetchedItemsForPage = [];
    Map<Timeline, ({String? lastEventId, bool wasExhausted})> nextPageKeyMap;

    // TODO: [infinite_scroll_pagination_migration] The logic for `_fetchFutureEvents` (loading newer items)
    // needs to be integrated here if `pageKey == _pagingController!.firstPageKey` (i.e. pageKey == null in our case)
    // and this call is due to a refresh.
    // For now, this method proceeds with its original pagination logic.
    // The `firstEventIds` map and its usage in original `_fetchFutureEvents` would be relevant here.

    try {
      if (currentPageKey == null) {
        if (!pageKeyInitialized) {
          pageKeyInitialized = true; // This flag helps distinguish initial load from subsequent null page keys.
          currentPageKey = {};
          final timelineList = await timelines;
          if (!mounted) return;
          for (Timeline timeline in timelineList) {
            currentPageKey[timeline] = (lastEventId: null, wasExhausted: false);
          }
           // Initialize firstEventIds for all relevant timelines if it's the very first load (refresh)
          if (pageKey == _pagingController!.firstPageKey) { // True for initial load/refresh
            for (var timeline in timelineList) {
                if (timeline.events.isNotEmpty) {
                    firstEventIds[timeline.room.id] = timeline.events.first.eventId;
                }
            }
          }
        } else {
          // pageKey is null, but pageKeyInitialized is true. This means we've reached the end.
          _pagingController!.appendLastPage([]); // No more items
          return;
        }
      }

      nextPageKeyMap = Map.from(currentPageKey!);
      List<String> lastPostableEventIds = [];

      for (Timeline timeline in currentPageKey.keys.toList()) {
        ({String? lastEventId, bool wasExhausted}) meta = currentPageKey[timeline]!;
        List<({Event origEvent, Event displayEvent})> timelineNewEvents = [];

        while (timelineNewEvents.isEmpty) {
          if (timeline.canRequestHistory) {
            await timeline.requestHistory(historyCount: 100);
            if (!mounted) return;
          }

          bool foundNewStart = false;
          for (Event event in timeline.events) {
            if (!foundNewStart) {
              if (meta.lastEventId == null) {
                foundNewStart = true;
              } else if (event.eventId == meta.lastEventId) {
                foundNewStart = true;
                continue;
              } else {
                continue;
              }
            }
            if (event.type == "m.room.message" &&
                event.relationshipType != RelationshipTypes.reply &&
                event.relationshipType != RelationshipTypes.thread &&
                event.relationshipType != RelationshipTypes.edit &&
                event.room.getPowerLevelByUserId(event.senderId) >= 50) {
              timelineNewEvents.add((origEvent: event, displayEvent: event.getDisplayEvent(timeline)));
            }
          }

          if (!timeline.canRequestHistory) {
            nextPageKeyMap.remove(timeline);
            if (timelineNewEvents.isEmpty) {
              // Removed continue timelineLoop;
            }
          }
        }

        if (timelineNewEvents.isNotEmpty) {
          lastPostableEventIds.add(timelineNewEvents.last.origEvent.eventId);
          fetchedItemsForPage.addAll(timelineNewEvents);

          // This logic was for prepending, should be reviewed if firstEventIds is still used for refresh
           if (firstEventIds[timeline.room.id] == null && timelineNewEvents.isNotEmpty) {
             timelineNewEvents.sort((a, b) => b.displayEvent.originServerTs.compareTo(a.displayEvent.originServerTs));
             firstEventIds[timeline.room.id] = timelineNewEvents.first.origEvent.eventId;
          }
        }
      }

      fetchedItemsForPage.sort((a, b) => b.displayEvent.originServerTs.compareTo(a.displayEvent.originServerTs));

      if (lastPostableEventIds.isNotEmpty) {
        int cutOffIndex = -1;
        for (int i = 0; i < fetchedItemsForPage.length; i++) {
          if (lastPostableEventIds.contains(fetchedItemsForPage[i].origEvent.eventId)) {
            cutOffIndex = i;
            break;
          }
        }
        if (cutOffIndex != -1) {
          fetchedItemsForPage.removeRange(cutOffIndex + 1, fetchedItemsForPage.length);
        }
      }

      bool overallExhausted = true;
      for (MapEntry e in Map.from(nextPageKeyMap).entries) {
          bool timelineExhaustedForThisBatch = true;
          for (var el in fetchedItemsForPage.reversed) {
              if (el.origEvent.room.id == e.key.room.id) {
                  nextPageKeyMap[e.key] = (lastEventId: el.origEvent.eventId, wasExhausted: false);
                  timelineExhaustedForThisBatch = false;
                  overallExhausted = false;
                  break;
              }
          }
          if (timelineExhaustedForThisBatch && !e.key.canRequestHistory) {
            nextPageKeyMap[e.key] = (lastEventId: e.value.lastEventId, wasExhausted: true);
          } else if (timelineExhaustedForThisBatch && e.key.canRequestHistory) {
            overallExhausted = false;
          }
      }

      final bool isLastPage = nextPageKeyMap.isEmpty || nextPageKeyMap.values.every((v) => v.wasExhausted);

      if (fetchedItemsForPage.isEmpty) {
        if (isLastPage) {
          _pagingController!.appendLastPage([]);
        } else {
          if (!mounted) return;
          await _fetchEvents(nextPageKeyMap); // Recursive call if no items in this batch but more might exist
        }
      } else {
        if (isLastPage) {
          _pagingController!.appendLastPage(fetchedItemsForPage);
        } else {
          _pagingController!.appendPage(fetchedItemsForPage, nextPageKeyMap);
        }
      }
    } catch (e) { // Simpler catch for now, can add stackTrace if needed
      debugPrint("Error in _fetchEvents: $e");
      _pagingController!.error = e;
    }
  }

  @override
  void initState() {
    super.initState();
    _pagingController = PagingController(
      firstPageKey: null, // This will be the initial pageKey passed to _fetchEvents
    );
    _pagingController!.addPageRequestListener((pageKey) {
      _fetchEvents(pageKey);
    });
    // pageKeyInitialized is used within _fetchEvents to manage the very first load logic.
    // No need to call _fetchEvents(null) here as PagingController does it.
  }

  @override
  void dispose() {
    _pagingController?.dispose();
    adressContrainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: () async => _pagingController!.refresh(), // Use controller's refresh
            child: Column(children: [
              if (widget.roomId != null) ...[
                Text("feed.pages.home.roomlabel".tr(args: [widget.roomId!]))
              ],
              Expanded(
                  child: PagedListView.separated(
                      pagingController: _pagingController!, // Changed from controller
                      separatorBuilder: (context, index) => const Divider(),
                      builderDelegate: PagedChildBuilderDelegate<
                              ({Event origEvent, Event displayEvent})>(
                          itemBuilder: (context, item, index) => GestureDetector(
                              onTap: () => context.push(Uri(
                                      path: "/post/${item.origEvent.eventId}",
                                      queryParameters: {
                                        'room': item.origEvent.roomId
                                      }).toString()),
                              child: PostWidget(
                                  event: item.origEvent,
                                  displayEvent: item.displayEvent)))))
            ])));
  }
}
