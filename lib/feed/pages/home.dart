import '/post/widgets/post.dart';
import '/shared/extensions/client_extensions.dart';
import '/shared/services/connectivity_service.dart';

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

  late final PagingController<
      Map<Timeline, ({String? lastEventId, bool wasExhausted})>?,
      ({Event origEvent, Event displayEvent})> _pagingController;
  bool pageKeyInitialized =
      false; // tracks if the pageKey needs initializing, workarround b.c. we can't initilize it as a future, so we initialize it at the first call (yes, poor performance for all runs after, TODO)
  Map<String, String> firstEventIds =
      {}; // Map<room.id, event.eventId> saves the eventIds of the events at the top (start) of the page, so we can track wich events where already added

  // Cache the timelines future to avoid re-fetching on every access
  late Future<List<Timeline>> _timelinesFuture;

  // Track the latest key calculated by _fetchEvents to return it in getNextPageKey
  Map<Timeline, ({String? lastEventId, bool wasExhausted})>? _latestNextPageKey;

  bool _isOnline = true;
  bool _showOfflineBanner = false;
  late Stream<bool> _connectivityStream;

  Client get client => Provider.of<Client>(context, listen: false);
  ConnectivityService get connectivityService =>
      Provider.of<ConnectivityService>(context, listen: false);

  Future<List<Timeline>> _fetchTimelines() async {
    List<Room> rooms = [];
    if (!mounted) return [];
    
    // Capture the client synchronously to avoid looking up context after an await
    final currentClient = client;

    if (widget.roomId != null) {
      String roomId = widget.roomId!;

      if (roomId.startsWith("#")) {
        final aliasResolv = await currentClient.getRoomIdByAlias(roomId);
        if (aliasResolv.roomId != null) {
          roomId = aliasResolv.roomId!;
        }
        if (!mounted) return [];
        debugPrint("roomId: $roomId");
      }

      final GetRoomEventsResponse resp = await currentClient.getRoomEvents(
        roomId,
        Direction.b,
        limit:
            1, // we don't need events, we just need the prev_batch -> we have to set it to at least 1

        filter: jsonEncode(StateFilter(lazyLoadMembers: true)
            .toJson()), // for getting state events (e.g. power levels of posters)
      );
      if (!mounted) return [];

      debugPrint("getRoomEvents finished");
      // Prefer existing room from client if available
      final existingRoom = currentClient.getRoomById(roomId);
      if (existingRoom != null) {
        rooms = [existingRoom];
      } else {
        rooms = [Room(id: roomId, client: currentClient, prev_batch: resp.end)];
      }
    } else {
      if (!currentClient.isLogged()) {
        debugPrint("HomePage: Client not logged in, skipping room fetch");
        return [];
      }
      final roomIds = await currentClient.getJoinedRooms();
      if (!mounted) return [];

      for (String roomId in roomIds) {
        Room? r = currentClient.getRoomById(roomId);
        if (r == null) continue;

        debugPrint("checking room ${r.name} id: ${r.id}");

        if (await currentClient.isRoomInSubstitution(roomId)) {
          debugPrint("--- adding room ${r.name} id: ${r.id}");
          rooms.add(r);
        }
      }
    }

    if (!mounted) return [];
    final timelineFutures = rooms.map((r) => r.getTimeline()).toList();
    return Future.wait(timelineFutures);
  }

  // fetch events that are unknown by the _pagingController becourse they are too new
  Future<void> _fetchFutureEvents() async {
    // ich muss requestfuture machen und alle, die dann neu dazu gekommen sind, muss ich verarbeiten
    // und vorne anhängen

    // theoretisch könnte man das über die länge herausfinden,
    // also neueElemente = alteElemente[0 bis alteElementeVorGteFuture.length]
    //aber damit würde man falsche werte bekommen,
    // wenn man irgendwie zwischen requestFuture noch ein request history bekommt und der schneller fertig ist,
    // da dann ja die length nicht mehr stimmt und man würde sachen doppelt hinzufügen
    // also müssen wir uns das vorhher erste element abspeichern und dann so viele adden bis man zu diesem element kommt

    List<({Event origEvent, Event displayEvent})> ret = [];

    final timelineLists = await _timelinesFuture;
    if (!mounted) return;

    for (Timeline timeline in timelineLists) {
      List<({Event origEvent, Event displayEvent})> newEvents = [];

      /*if (!timeline.canRequestFuture) {
        debugPrint("can not request future!");
        continue;
      }*/

      // todo: rename firstEventIds to something more meaningfull like lastCurrentEventIds
      String lastCurrentEventId = firstEventIds[timeline.room.id]!;

      //String lastCurrentEventId = timeline.events[0].eventId;

      // todo: returns how many events we got back, so we could just splice the elements there
      await timeline.getRoomEvents(
          direction: Direction.b); // handles canRequestFuture for us
      //await timeline.requestFuture(
      //    historyCount:
      //        100); // normally, there should not be that much of new events, but we don't have a method to know if there ARE new events that wherend displayed yet

      if (!mounted) return;

      debugPrint("requestedFuture");

      for (Event e in timeline.events) {
        debugPrint(
            "found event ${e.eventId}, lastCurrentEventId is $lastCurrentEventId");

        if (e.eventId == lastCurrentEventId) {
          break;
        }

        if (e.type == "m.room.message" && // we only want messages
            e.relationshipType !=
                RelationshipTypes.reference && // ... no replys
            e.relationshipType != RelationshipTypes.thread && // ... no threads
            e.relationshipType !=
                RelationshipTypes
                    .edit && // ... no edits (will be catched later)
            e.room.getPowerLevelByUserId(e.senderId) >=
                50) //... only with powerlevel >= 50, so the admin of a room can limit who can post to timeline (leaving commenting is still possible with < 50)
        {
          // todo: check if this is an event we want to display
          newEvents
              .add((origEvent: e, displayEvent: e.getDisplayEvent(timeline)));
          debugPrint("added ${e.eventId}");
        }
      }

      if (newEvents.isNotEmpty) {
        // sort... mby unnesseccarry (todo)
        newEvents.sort((a, b) => b.displayEvent.originServerTs
            .compareTo(a.displayEvent.originServerTs));
        firstEventIds[timeline.room.id] = newEvents[0].origEvent.eventId;
      }

      ret.addAll(newEvents);
    }

    // sort (cloud be made cleverer, just compare the start of each newEvents and append or insert them (instead of ret.addAll(), see above))
    ret.sort((a, b) =>
        b.displayEvent.originServerTs.compareTo(a.displayEvent.originServerTs));

    // add ret to the top
    // Note: In new API, we don't directly manipulate items like this
  }

  // beim update werden einfach "neue" events an timeline.events angehangen
  // Idea: Only post as much events from the timeline until exactly one has no more events to be posted, and hold back elements from other timelines that would be posted there after
  // Map value:
  //  lastEventId: last event id that was added to the list
  //  since: das ding was man mitgibt um zu sagen an welcher stelle man war.. todo auf englisch dokumentierne
  //  wasExhausted: we do not have any events that where not posted on the timeline
  Future<({List<({Event origEvent, Event displayEvent})> events, Map<Timeline, ({String? lastEventId, bool wasExhausted})>? nextKey})> _fetchEvents(
      Map<Timeline, ({String? lastEventId, bool wasExhausted})>?
          pageKey) async {
    List<({Event origEvent, Event displayEvent})> ret = [];

    Map<Timeline, ({String? lastEventId, bool wasExhausted})>? newPageKey =
        pageKey;

    if (pageKey == null) {
      if (!pageKeyInitialized) {
        pageKeyInitialized = true;

        final timelineList = await _timelinesFuture;
        if (!mounted) return (events: ret, nextKey: newPageKey);

        newPageKey = {};
        for (Timeline timeline in timelineList) {
          newPageKey[timeline] = (lastEventId: null, wasExhausted: false);
        }
      } else {
        debugPrint("Page key is null, returning...");
        return (events: ret, nextKey: newPageKey); // TODO: no more elements to display, all timelines are exhausted. Mby display this...?
      }
    }

    debugPrint("start quering new events...");

    List<String> lastPostableEventIds = [];

    timelineLoop:
    for (Timeline timeline in newPageKey!.keys.toList()) {
      ({String? lastEventId, bool wasExhausted}) meta = newPageKey[timeline]!;

      List<({Event origEvent, Event displayEvent})> newEvents = [];
      int retryCount = 0;

      while (newEvents.isEmpty && retryCount < 5) {
        retryCount++;
        // get events as long as we don't have some new ones to display or until the timeline is exhausted (=at it's starting point where the room was created)
        // request new elements
        if (timeline.canRequestHistory) {
          await timeline.requestHistory(historyCount: 100);
          if (!mounted) return (events: ret, nextKey: newPageKey);
        }

        // find the first event to display, e.g. the one after the one we displayed last. If we did not display any event, meta.lastEventId will be null and we can just display the first event
        bool foundNewStart = false;
        for (Event event in timeline.events) {
          // we have to make any event uniq, as sometimes getRoomEvents lead to doubled events in timeline.events
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

          // filter events to only grap message's
          if (event.type == "m.room.message" && // we only want messages
              event.relationshipType !=
                  RelationshipTypes.reference && // ... no replys
              event.relationshipType !=
                  RelationshipTypes.thread && // ... no threads
              event.relationshipType !=
                  RelationshipTypes
                      .edit && // ... no edits (will be catched later)
              event.room.getPowerLevelByUserId(event.senderId) >=
                  50) //... only with powerlevel >= 50, so the admin of a room can limit who can post to timeline (leaving commenting is still possible with < 50)
          {
            // we have a new event to handle
            newEvents.add((
              origEvent: event,
              displayEvent: event.getDisplayEvent(timeline)
            ));
          }
        }

        if (!timeline.canRequestHistory) {
          // history of this timeline is exhausted, no need to add more
          debugPrint(
              "cannot request more history... events.isEmpty? ${timeline.events.isEmpty}, room.prev_batch: ${timeline.room.prev_batch}");

          newPageKey.remove(timeline);

          if (newEvents.isEmpty) {
            // if not empty -> add the events to ret, or we loos em
            // continue with the next timeline if we got no new events
            continue timelineLoop;
          }
        }
      }

      // get the id of the last postable event of this timeline
      lastPostableEventIds.add(newEvents.last.origEvent
          .eventId); // TODO!! Mby use displayEventId, would add updates from post to the timeline, would double it
      ret.addAll(newEvents);

      if (firstEventIds[timeline.room.id] == null) {
        // first run, so we need to add the first ones of each timeline.. TODO: this affects performance...

        newEvents.sort((a, b) => b.displayEvent.originServerTs
            .compareTo(a.displayEvent.originServerTs));
        firstEventIds[timeline.room.id] = newEvents[0].origEvent.eventId;
      }
    }

    // sort
    ret.sort((a, b) =>
        b.displayEvent.originServerTs.compareTo(a.displayEvent.originServerTs));

    // delete all events after the first "last" event and modify newPageKey accordingly to the last event of each timeline before that event happend
    for (var el in ret) {
      if (lastPostableEventIds.contains(el.origEvent.eventId)) {
        /* this is the red line, after this element, no element shall be added to the output */

        // TODO: one should test if dart always recalculates re.indexOf(el) or if it caches
        ret.removeWhere((i) => ret.indexOf(i) > ret.indexOf(el));
        break;
      }
    }

    // set the id's of the last events accordingly, if the events are postable, else leave the id as it was
    // todo: this is pritty bad performance wise... mby find a better solution with copieng ret and deleting all keys that are from the timeline after we finished one or so...
    // todo: track the first one

    bool exhausted = false;
    timelineLoop:
    for (MapEntry e in newPageKey.entries) {
      for (var el in ret.reversed) {
        if (el.origEvent.room.id == e.key.room.id) {
          // todo: mby better to compare the room address rather than the timeline object?
          // todo: or displayEvent? set it below for newPageKey[...] = ... accordingly
          if (!exhausted) {
            // the timeline of the last postable element was exhausted
            exhausted = true;
            newPageKey[e.key] =
                (lastEventId: el.origEvent.eventId, wasExhausted: true);
          } else {
            newPageKey[e.key] =
                (lastEventId: el.origEvent.eventId, wasExhausted: false);
          }
          continue timelineLoop;
        }
      }
    }

    debugPrint("finished...");

    if (ret.isEmpty) {
      debugPrint("ret is empty...");

      if (newPageKey.isEmpty) {
        debugPrint("no new things to append...");
        return (events: ret, nextKey: newPageKey); // no new things to append
      }

      debugPrint("mby new things to append -> fetch another page...");
      // In new API, we don't recursively call like this
    }

    return (events: ret, nextKey: newPageKey);
  }

  @override
  void initState() {
    super.initState();
    _timelinesFuture = _fetchTimelines();

    _pagingController = PagingController<
        Map<Timeline, ({String? lastEventId, bool wasExhausted})>?,
        ({Event origEvent, Event displayEvent})>(
      getNextPageKey: (state) {
        if (state.keys == null) {
          return {}; // Initial load key
        }

        // If the last fetched page was empty, we are at the end of the list
        if (state.pages != null &&
            state.pages!.isNotEmpty &&
            state.pages!.last.isEmpty) {
          return null;
        }

        // If the map is completely empty, it means all timelines exhausted.
        if (_latestNextPageKey != null && _latestNextPageKey!.isEmpty) {
           return null;
        }

        return _latestNextPageKey ?? state.keys!.lastOrNull;
      },
      fetchPage: (pageKey) async {
        final result = await _fetchEvents(pageKey);
        _latestNextPageKey = result.nextKey;
        return result.events;
      },
    );

    // Initialize connectivity tracking
    _connectivityStream = connectivityService.onConnectivityChanged;
    _connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          // Show banner when going offline, hide when coming back online
          if (!isOnline) {
            _showOfflineBanner = true;
          }
        });

        // If coming back online, refetch events
        if (isOnline && _showOfflineBanner) {
          _fetchFutureEvents();
        }
      }
    });

    // Check initial connectivity status
    connectivityService.isOnline.then((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    adressContrainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        RefreshIndicator(
            onRefresh: () async {
              await _fetchFutureEvents();
              if (!mounted) return;
            },
            child: Column(children: [
              if (widget.roomId != null) ...[
                const Text("feed.pages.home.roomlabel")
                    .tr(args: [widget.roomId!])
              ],
              Expanded(
                  child: PagedListView<Map<Timeline, ({String? lastEventId, bool wasExhausted})>?, ({Event origEvent, Event displayEvent})>.separated(
                      state: _pagingController.value,
                      fetchNextPage: _pagingController.fetchNextPage,
                      separatorBuilder: (context, index) => const Divider(),
                      builderDelegate: PagedChildBuilderDelegate<
                              ({Event origEvent, Event displayEvent})>(
                          noItemsFoundIndicatorBuilder: (context) => Center(
                              child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "feed.pages.home.empty",
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ).tr(),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  context.push('/settings/feed');
                                },
                                child: Text("feed.pages.home.empty_button").tr(),
                              ),
                            ],
                          )),
                          itemBuilder: (context, item, index) => GestureDetector(
                              onTap: () => context.push(Uri(
                                      path: "/post/${item.origEvent.eventId}",
                                      queryParameters: {
                                        'room': item.origEvent.roomId
                                      }).toString()),
                              child: PostWidget(
                                  event: item.origEvent,
                                  displayEvent: item.displayEvent)))))
            ])),
        // Offline banner
        if (!_isOnline && _showOfflineBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MaterialBanner(
              content: const Text('Offline — showing cached content'),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showOfflineBanner = false;
                    });
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ),
      ],
    ));
  }
}
