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

  final PagingController<
          Map<Timeline, ({String? lastEventId, bool wasExhausted})>?,
          ({Event origEvent, Event displayEvent})> _pagingController =
      PagingController(firstPageKey: null);
  bool pageKeyInitialized =
      false; // tracks if the pageKey needs initializing, workarround b.c. we can't initilize it as a future, so we initialize it at the first call (yes, poor performance for all runs after, TODO)
  Map<String, String> firstEventIds =
      {}; // Map<room.id, event.eventId> saves the eventIds of the events at the top (start) of the page, so we can track wich events where already added

  Client get client => Provider.of<Client>(context, listen: false);

  // TODO: rooms muss jetzt alle gefolgten rooms zurückgeben, die in substitution angezeigt werden sollen
  // abgewandelte form von followfeeds.dart, TODO: impl. it as one function, somehow

  Future<List<Room>> get rooms async {
    List<Room> ret = [];

    if (widget.roomId != null) {
      String roomId = widget.roomId!;

      if (roomId.startsWith("#")) {
        roomId = (await client.getRoomIdByAlias(roomId)).roomId!;
        debugPrint("roomId: $roomId");
      }

      final GetRoomEventsResponse resp = await client.getRoomEvents(
        roomId,
        Direction.b,
        limit:
            1, // we don't need events, we just need the prev_batch -> we have to set it to at least 1

        filter: jsonEncode(StateFilter(lazyLoadMembers: true)
            .toJson()), // for getting state events (e.g. power levels of posters)
      );

      debugPrint("getRoomEvents finished");
      return [Room(id: roomId, client: client, prev_batch: resp.end)];
    }

    final roomIds = await client.getJoinedRooms();

    for (String roomId in roomIds) {
      Room r = client.getRoomById(roomId)!;
      // todo: use client.getRoomEvents

      debugPrint("checking room ${r.name} id: ${r.id}");

      try {
        final accountData = await client.getAccountDataPerRoom(
            client.userID!, roomId, "substitution");
        final isInSubstitution =
            accountData["joined"] == true; // Sichere Prüfung

        if (isInSubstitution) {
          debugPrint("--- adding room ${r.name} id: ${r.id}");
          ret.add(r);
        }
      } catch (_) {} // we cannot get the account data
    }

    return ret;
  }

  Future<List<Timeline>> get timelines async {
    final roomList = await rooms;
    final timelineFutures = roomList.map((r) => r.getTimeline()).toList();
    return Future.wait(timelineFutures); // Warte auf alle Timelines
  }

  // TODO: requestHistory für history, requestFuture wenn man neue sachen haben will

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

    final timelineLists = await timelines;
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
            e.relationshipType != RelationshipTypes.reply && // ... no replys
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
    _pagingController.itemList = [...ret, ...?_pagingController.itemList];
  }

  // beim update werden einfach "neue" events an timeline.events angehangen
  // Idea: Only post as much events from the timeline until exactly one has no more events to be posted, and hold back elements from other timelines that would be posted there after
  // Map value:
  //  lastEventId: last event id that was added to the list
  //  since: das ding was man mitgibt um zu sagen an welcher stelle man war.. todo auf englisch dokumentierne
  //  wasExhausted: we do not have any events that where not posted on the timeline
  Future<void> _fetchEvents(
      Map<Timeline, ({String? lastEventId, bool wasExhausted})>?
          pageKey) async {
    if (pageKey == null) {
      if (!pageKeyInitialized) {
        pageKeyInitialized = true;
        pageKey = {};

        final timelineList = await timelines;
        if (!mounted) return;

        for (Timeline timeline in timelineList) {
          pageKey[timeline] = (lastEventId: null, wasExhausted: false);
        }
      } else {
        debugPrint("Page key is null, returning...");
        _pagingController.appendLastPage([]);
        // TODO: no more elements to display, all timelines are exhausted. Mby display this...?
        return;
      }
    }

    debugPrint("start quering new events...");

    List<({Event origEvent, Event displayEvent})> ret = [];
    Map<Timeline, ({String? lastEventId, bool wasExhausted})> newPageKey =
        pageKey;

    List<String> lastPostableEventIds = [];

    timelineLoop:
    for (Timeline timeline in pageKey.keys.toList()) {
      ({String? lastEventId, bool wasExhausted}) meta = pageKey[timeline]!;

      List<({Event origEvent, Event displayEvent})> newEvents = [];

      while (newEvents.isEmpty) {
        // get events as long as we don't have some new ones to display or until the timeline is exhausted (=at it's starting point where the room was created)
        // request new elements
        //await timeline.requestHistory(historyCount: 10);
        if (timeline.canRequestHistory) {
          await timeline.requestHistory(historyCount: 100);
          if (!mounted) return;
        }
        //await timeline.getRoomEvents(historyCount: 10); // leads to doubled events sometimes!

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
                  RelationshipTypes.reply && // ... no replys
              event.relationshipType !=
                  RelationshipTypes.thread && // ... no threads
              event.relationshipType !=
                  RelationshipTypes
                      .edit && // ... no edits (will be catched later)
              event.room.getPowerLevelByUserId(event.senderId) >=
                  50) //... only with powerlevel >= 50, so the admin of a room can limit who can post to timeline (leaving commenting is still possible with < 50)
          {
            // we have a new event to handle
            //if(newEvents.where((e) => e.eventId == event.eventId && e.room.roomId))

            newEvents.add((
              origEvent: event,
              displayEvent: event.getDisplayEvent(timeline)
            ));
          }
        }

        /*newEvents = [
          // remove duplicates
          ...{...newEvents}
        ];*/

        if (!timeline.canRequestHistory) {
          // history of this timeline is exhausted, no need to add more
          debugPrint(
              "cannot request more history... events.isEmpty? ${timeline.events.isEmpty}, room.prev_batch: ${timeline.room.prev_batch}, events.last.type: ${timeline.events.last.type}");

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
        _pagingController.appendLastPage([]);

        return; // no new things to append
      }

      debugPrint("mby new things to append -> fetch another page...");
      await _fetchEvents(newPageKey);
      if (!mounted) return;
    } else {
      debugPrint("start appending...");

      _pagingController.appendPage(ret, newPageKey);
    }
  }

  @override
  void initState() {
    super.initState();

    _pagingController.addPageRequestListener((pageKey) async {
      //_fetchRooms(pageKey); todo...
      await _fetchEvents(pageKey);
      if (!mounted) return;
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
        body: RefreshIndicator(
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
                  child: PagedListView.separated(
                      pagingController: _pagingController,
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
