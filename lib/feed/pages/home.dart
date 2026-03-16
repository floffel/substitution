import '/post/widgets/post.dart';
import '/shared/widgets/post_skeleton.dart';

import '/shared/services/connectivity_service.dart';

import 'dart:convert'; // for json
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '/shared/services/substitution_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.roomId});

  // only display content of this room, if set. Otherwise: display all followed rooms content
  final String? roomId;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  static const int _pageSize = 100;
  final adressContrainer = TextEditingController();

  late final PagingController<
    Map<Timeline, ({String? lastEventId, bool wasExhausted})>?,
    ({Event origEvent, Event displayEvent})
  >
  _pagingController;
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

  late final Client _client;
  late final ConnectivityService _connectivityService;
  late final SubstitutionService _substitutionService;
  Set<String> _currentRoomIds = {};
  Set<String> get currentRoomIds => _currentRoomIds;
  bool _isFetchingFuture = false;

  Future<List<Timeline>> _fetchTimelines() async {
    List<Room> rooms = [];
    if (!mounted) return [];

    // Capture the client synchronously to avoid looking up context after an await
    final currentClient = _client;

    if (widget.roomId != null) {
      String roomId = widget.roomId!;

      if (roomId.startsWith("#")) {
        final aliasResolv = await currentClient.getRoomIdByAlias(roomId);
        if (aliasResolv.roomId != null) {
          roomId = aliasResolv.roomId!;
        }
        if (!mounted) return [];
      }

      final GetRoomEventsResponse resp = await currentClient.getRoomEvents(
        roomId,
        Direction.b,
        limit:
            1, // we don't need events, we just need the prev_batch -> we have to set it to at least 1

        filter: jsonEncode(
          StateFilter(lazyLoadMembers: true).toJson(),
        ), // for getting state events (e.g. power levels of posters)
      );
      if (!mounted) return [];

      // Prefer existing room from client if available
      final existingRoom = currentClient.getRoomById(roomId);
      if (existingRoom != null) {
        rooms = [existingRoom];
      } else {
        rooms = [Room(id: roomId, client: currentClient, prev_batch: resp.end)];
      }
    } else {
      if (!currentClient.isLogged()) {
        return [];
      }

      // Ensure SubstitutionService is initialized before querying rooms
      await _substitutionService.init();

      final roomIds = await currentClient.getJoinedRooms();
      if (!mounted) return [];

      for (String roomId in roomIds) {
        Room? r = currentClient.getRoomById(roomId);
        if (r == null) continue;

        if (_substitutionService.isSubstitutionRoom(r.id)) {
          rooms.add(r);
        }
      }
    }

    if (!mounted) return [];
    final timelineFutures = rooms.map((r) => r.getTimeline()).toList();
    _currentRoomIds = rooms.map((r) => r.id).toSet();
    debugPrint("HomePage: Found ${_currentRoomIds.length} rooms for feed");
    return Future.wait(timelineFutures);
  }

  // fetch events that are unknown by the _pagingController because they are too new

  Future<void> _fetchFutureEvents() async {
    if (_isFetchingFuture) return;
    _isFetchingFuture = true;

    try {
      List<({Event origEvent, Event displayEvent})> ret = [];

      final timelineLists = await _timelinesFuture;
      if (!mounted) return;

      for (Timeline timeline in timelineLists) {
        List<({Event origEvent, Event displayEvent})> newEvents = [];

        String? lastCurrentEventId = firstEventIds[timeline.room.id];

        // Scan the current timeline events (already populated by sync loop)
        for (Event e in timeline.events) {
          // If we have a marker, stop when we reach it
          if (lastCurrentEventId != null && e.eventId == lastCurrentEventId) {
            break;
          }

          if (e.type == "m.room.message" &&
              e.relationshipType != RelationshipTypes.reference &&
              e.relationshipType != RelationshipTypes.thread &&
              e.relationshipType != RelationshipTypes.edit &&
              e.room.getPowerLevelByUserId(e.senderId) >= 50) {
            newEvents.add((
              origEvent: e,
              displayEvent: e.getDisplayEvent(timeline),
            ));
          }

          // If we didn't have a marker, only take the first N messages to avoid flooding
          if (lastCurrentEventId == null && newEvents.length >= _pageSize) {
            break;
          }
        }

        if (newEvents.isNotEmpty) {
          firstEventIds[timeline.room.id] = newEvents.first.origEvent.eventId;
          ret.addAll(newEvents);
        }
      }

      if (ret.isEmpty) return;

      // sort
      ret.sort(
        (a, b) => b.displayEvent.originServerTs.compareTo(
          a.displayEvent.originServerTs,
        ),
      );

      // add ret to the top
      final currentPages = _pagingController.value.pages ?? [];
      final currentKeys = _pagingController.value.keys ?? [];

      if (currentPages.isNotEmpty && currentKeys.isNotEmpty) {
        final List<List<({Event origEvent, Event displayEvent})>> updatedPages =
            [
              [...ret, ...currentPages.first],
              ...currentPages.skip(1),
            ];
        _pagingController.value = _pagingController.value.copyWith(
          pages: updatedPages,
        );
        debugPrint("HomePage: Prepended ${ret.length} new events to feed");
      } else {
        debugPrint("HomePage: Deferring prepend, no pages loaded yet");
      }
    } finally {
      _isFetchingFuture = false;
    }
  }

  // beim update werden einfach "neue" events an timeline.events angehangen
  // Idea: Only post as much events from the timeline until exactly one has no more events to be posted, and hold back elements from other timelines that would be posted there after
  // Map value:
  //  lastEventId: last event id that was added to the list
  //  since: das ding was man mitgibt um zu sagen an welcher stelle man war.. todo auf englisch dokumentierne
  //  wasExhausted: we do not have any events that where not posted on the timeline
  Future<
    ({
      List<({Event origEvent, Event displayEvent})> events,
      Map<Timeline, ({String? lastEventId, bool wasExhausted})>? nextKey,
    })
  >
  _fetchEvents(
    Map<Timeline, ({String? lastEventId, bool wasExhausted})>? pageKey,
  ) async {
    List<({Event origEvent, Event displayEvent})> ret = [];

    Map<Timeline, ({String? lastEventId, bool wasExhausted})>? newPageKey =
        pageKey;

    // Treat both `null` and an empty map as the "initialize from timelines"
    // signal.  The PagingController passes an empty map `{}` as the very
    // first page key (see getNextPageKey), so we need to handle both cases.
    final bool isInitialLoad = pageKey == null || pageKey.isEmpty;

    if (isInitialLoad) {
      if (!pageKeyInitialized) {
        pageKeyInitialized = true;

        final timelineList = await _timelinesFuture;
        if (!mounted) return (events: ret, nextKey: newPageKey);

        newPageKey = {};
        for (Timeline timeline in timelineList) {
          newPageKey[timeline] = (lastEventId: null, wasExhausted: false);
        }
      } else {
        return (events: ret, nextKey: newPageKey);
      }
    }

    List<({Event origEvent, Event displayEvent})> allCandidates = [];
    Map<Timeline, List<({Event origEvent, Event displayEvent})>>
    candidatesPerTimeline = {};

    for (Timeline timeline in newPageKey!.keys.toList()) {
      ({String? lastEventId, bool wasExhausted}) meta = newPageKey[timeline]!;

      List<({Event origEvent, Event displayEvent})> roomCandidates = [];
      int retryCount = 0;
      int lastProcessedIndex = -1;

      // Find the starting point in the current timeline events
      if (meta.lastEventId != null) {
        lastProcessedIndex = timeline.events.indexWhere(
          (e) => e.eventId == meta.lastEventId,
        );
      }

      while (roomCandidates.length < _pageSize && retryCount < 3) {
        retryCount++;

        final int countBefore = timeline.events.length;

        // Process events from the last point reached
        for (int i = lastProcessedIndex + 1; i < timeline.events.length; i++) {
          final event = timeline.events[i];
          lastProcessedIndex = i;

          final isMsg = event.type == "m.room.message";
          final isNotReply =
              event.relationshipType != RelationshipTypes.reference;
          final isNotThread =
              event.relationshipType != RelationshipTypes.thread;
          final isNotEdit = event.relationshipType != RelationshipTypes.edit;
          final powerLevel = event.room.getPowerLevelByUserId(event.senderId);

          if (isMsg &&
              isNotReply &&
              isNotThread &&
              isNotEdit &&
              powerLevel >= 50) {
            roomCandidates.add((
              origEvent: event,
              displayEvent: event.getDisplayEvent(timeline),
            ));
          }
        }

        if (roomCandidates.length < _pageSize && timeline.canRequestHistory) {
          await timeline.requestHistory(historyCount: _pageSize);
          if (!mounted) return (events: ret, nextKey: newPageKey);

          // If count didn't increase, the server has no more history for us despite what canRequestHistory says
          if (timeline.events.length <= countBefore) {
            break;
          }
        } else {
          break;
        }
      }

      candidatesPerTimeline[timeline] = roomCandidates;
      allCandidates.addAll(roomCandidates);
    }

    // Sort all candidates newest first
    allCandidates.sort(
      (a, b) => b.displayEvent.originServerTs.compareTo(
        a.displayEvent.originServerTs,
      ),
    );

    // Take top N posts for this page
    ret = allCandidates.take(_pageSize).toList();

    // Update the next key based on what we are actually returning
    Map<Timeline, ({String? lastEventId, bool wasExhausted})> nextKey = {};
    for (Timeline timeline in newPageKey.keys.toList()) {
      final meta = newPageKey[timeline]!;
      final eventsInRet =
          ret.where((e) => e.origEvent.roomId == timeline.room.id).toList();

      String? lastId =
          eventsInRet.isNotEmpty
              ? eventsInRet.last.origEvent.eventId
              : meta.lastEventId;

      if (eventsInRet.isNotEmpty && firstEventIds[timeline.room.id] == null) {
        // Track the newest event ID we've displayed for this room
        firstEventIds[timeline.room.id] = eventsInRet.first.origEvent.eventId;
      }

      bool isExhausted = !timeline.canRequestHistory;
      if (isExhausted) {
        // If there are still candidate messages from this timeline that we didn't include in 'ret',
        // it's not exhausted yet for the next fetch.
        final allTimelineCandidates = candidatesPerTimeline[timeline] ?? [];
        final retEventIds = ret.map((e) => e.origEvent.eventId).toSet();
        if (allTimelineCandidates.any(
          (e) => !retEventIds.contains(e.origEvent.eventId),
        )) {
          isExhausted = false;
        }
      }

      if (!isExhausted) {
        nextKey[timeline] = (lastEventId: lastId, wasExhausted: false);
      }
    }

    if (ret.isEmpty) {
      return (
        events: ret,
        nextKey: null,
      ); // Explicitly stop if no candidates found
    }

    debugPrint(
      "HomePage: Returning ${ret.length} events, nextKey.isEmpty=${nextKey.isEmpty}",
    );
    return (events: ret, nextKey: nextKey.isEmpty ? null : nextKey);
  }

  @override
  void initState() {
    super.initState();
    _client = Provider.of<Client>(context, listen: false);
    _connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );
    _substitutionService = Provider.of<SubstitutionService>(
      context,
      listen: false,
    );

    // Initialize SubstitutionService cache
    _substitutionService.init();

    _timelinesFuture = _fetchTimelines();

    _pagingController = PagingController<
      Map<Timeline, ({String? lastEventId, bool wasExhausted})>?,
      ({Event origEvent, Event displayEvent})
    >(
      getNextPageKey: (state) {
        if (state.keys == null) {
          return {}; // Initial load key
        }

        // Explicitly terminate if _latestNextPageKey is null or empty
        if (_latestNextPageKey == null || _latestNextPageKey!.isEmpty) {
          return null;
        }

        return _latestNextPageKey;
      },
      fetchPage: (pageKey) async {
        final result = await _fetchEvents(pageKey);
        _latestNextPageKey = result.nextKey;
        return result.events;
      },
    )..addListener(() {
      if (mounted) setState(() {});
    });

    // Initialize connectivity tracking
    _connectivityStream = _connectivityService.onConnectivityChanged;
    _connectivityStream.listen(
      (isOnline) {
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
      },
      onError: (Object e) {
        // Swallow connectivity errors (e.g. DBus/NetworkManager unavailable on
        // Linux CI). The app defaults to online.
        debugPrint('ConnectivityService: listen error: $e');
      },
    );

    // Check initial connectivity status
    _connectivityService.isOnline.then((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });

    // Listen for room changes via SubstitutionService
    _substitutionService.addListener(_handleRoomChanges);
  }

  void _handleRoomChanges() async {
    if (!mounted) return;

    // Check if room IDs actually changed before doing a heavy refresh
    final joinedRooms = await _client.getJoinedRooms();
    final joinedRoomIds = joinedRooms.toSet();
    final newSubstitutionRoomIds =
        joinedRoomIds
            .where((id) => _substitutionService.isSubstitutionRoom(id))
            .toSet();

    bool roomsChanged =
        newSubstitutionRoomIds.length != _currentRoomIds.length ||
        !newSubstitutionRoomIds.every((id) => _currentRoomIds.contains(id));

    if (!roomsChanged) {
      _fetchFutureEvents();
      return;
    }

    debugPrint(
      "HomePage: Room set changed from ${_currentRoomIds.length} to ${newSubstitutionRoomIds.length} rooms. Refreshing...",
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        // Reset paging state so that the next _fetchEvents call
        // re-reads the updated timeline list instead of returning early.
        pageKeyInitialized = false;
        _latestNextPageKey = null;
        _timelinesFuture = _fetchTimelines();
        _pagingController.refresh();
      });
    });
  }

  @override
  void dispose() {
    _substitutionService.removeListener(_handleRoomChanges);
    _pagingController.dispose();
    adressContrainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            color: colorScheme.primary,
            onRefresh: () async {
              await _fetchFutureEvents();
              if (!mounted) return;
            },
            child: Column(
              children: [
                if (widget.roomId != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Chip(
                      label: Text(
                        "feed.pages.home.roomlabel",
                      ).tr(args: [widget.roomId!]),
                      avatar: const Icon(Icons.tag, size: 16),
                    ),
                  ),
                ],
                Expanded(
                  child: PagedListView<
                    Map<Timeline, ({String? lastEventId, bool wasExhausted})>?,
                    ({Event origEvent, Event displayEvent})
                  >.separated(
                    key: const ValueKey('feedListView'),
                    state: _pagingController.value,
                    fetchNextPage: _pagingController.fetchNextPage,
                    // Use spacing instead of dividers for modern look
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 2),
                    builderDelegate: PagedChildBuilderDelegate<
                      ({Event origEvent, Event displayEvent})
                    >(
                      // Shimmer skeleton loading instead of spinner
                      firstPageProgressIndicatorBuilder:
                          (context) => const PostSkeletonList(count: 4),
                      newPageProgressIndicatorBuilder:
                          (context) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                      noItemsFoundIndicatorBuilder:
                          (context) => Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.art_track_outlined,
                                    size: 72,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    "feed.pages.home.empty",
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                    textAlign: TextAlign.center,
                                  ).tr(),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      context.push('/settings/feed');
                                    },
                                    child:
                                        Text(
                                          "feed.pages.home.empty_button",
                                        ).tr(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      itemBuilder:
                          (context, item, index) => GestureDetector(
                            onTap:
                                () => context.push(
                                  Uri(
                                    path: "/post/${item.origEvent.eventId}",
                                    queryParameters: {
                                      'room': item.origEvent.roomId,
                                    },
                                  ).toString(),
                                ),
                            child: PostWidget(
                              event: item.origEvent,
                              displayEvent: item.displayEvent,
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Offline banner
          if (!_isOnline && _showOfflineBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Offline — showing cached content',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: colorScheme.onErrorContainer,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _showOfflineBanner = false;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
