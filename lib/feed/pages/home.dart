import '/feed/services/feed_state_cache.dart';
import '/post/widgets/post.dart';
import '/shared/services/loading_service.dart';

import '/shared/services/connectivity_service.dart';

import 'dart:async';
import 'dart:convert'; // for json
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '/shared/services/substitution_service.dart';
import '/shared/extensions/go_router_extensions.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.roomId, this.onDiscoverTap});

  // only display content of this room, if set. Otherwise: display all followed rooms content
  final String? roomId;

  /// Called when the user taps the "find rooms" CTA on the empty feed.
  final VoidCallback? onDiscoverTap;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  /// Number of events to fetch per page when paginating through timelines.
  static const int _pageSize = 20;

  late final PagingController<
    Map<Timeline, ({String? lastEventId, bool wasExhausted})>?,
    ({Event origEvent, Event displayEvent})
  >
  _pagingController;

  /// Whether the page key has been initialized from timelines. Set to true on
  /// the first [_fetchEvents] call because the key depends on an async
  /// timeline fetch that cannot run during controller construction.
  bool pageKeyInitialized = false;

  /// Maps room ID to the newest event ID already displayed, used to detect
  /// which events are new when pulling to refresh.
  Map<String, String> firstEventIds = {};

  // Cache the timelines future to avoid re-fetching on every access
  late Future<List<Timeline>> _timelinesFuture;

  // Track the latest key calculated by _fetchEvents to return it in getNextPageKey
  Map<Timeline, ({String? lastEventId, bool wasExhausted})>? _latestNextPageKey;

  bool _isOnline = true;
  bool _showOfflineBanner = false;
  late Stream<bool> _connectivityStream;
  StreamSubscription<bool>? _connectivitySubscription;

  // ── Search state ────────────────────────────────────────────────────────────
  bool _isSearchActive = false;
  String _searchQuery = '';
  List<({Event origEvent, Event displayEvent})> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  int _searchGeneration = 0;

  late final Client _client;
  late final ConnectivityService _connectivityService;
  late final SubstitutionService _substitutionService;
  late final FeedStateCache _feedStateCache;
  late final LoadingService _loadingService;
  late final ScrollController _scrollController;
  Set<String> _currentRoomIds = {};
  Set<String> get currentRoomIds => _currentRoomIds;
  bool _isFetchingFuture = false;

  /// Candidates fetched but not returned in the previous page, keyed by room ID.
  /// Carried forward to avoid re-fetching the same events on the next page.
  Map<String, List<({Event origEvent, Event displayEvent})>>
  _carryForwardCandidates = {};

  /// Returns `true` if [event] should be shown as a feed post.
  ///
  /// In blog-mode rooms (`events_default >= 50`), only posts from users with
  /// power level >= 50 are shown. In community-mode rooms everyone's posts
  /// are visible.
  static bool _isVisiblePost(Event event) {
    final room = event.room;
    final powerLevelEvent = room.getState('m.room.power_levels');
    final eventsDefault =
        (powerLevelEvent?.content['events_default'] as num?)?.toInt() ?? 0;
    if (eventsDefault >= 50) {
      return room.getPowerLevelByUserId(event.senderId) >= 50;
    }
    return true;
  }

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
              _isVisiblePost(e)) {
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

      // sort by original event timestamp so edits don't change feed position
      ret.sort(
        (a, b) =>
            b.origEvent.originServerTs.compareTo(a.origEvent.originServerTs),
      );

      // add ret to the top
      final currentPages = _pagingController.value.pages ?? [];
      final currentKeys = _pagingController.value.keys ?? [];

      if (currentPages.isNotEmpty && currentKeys.isNotEmpty) {
        // Don't update the controller while a page fetch is already in progress.
        // Doing so resets _hasRequestedNextPage in PagedLayoutBuilder.didUpdateWidget,
        // which re-triggers fetchNextPage as soon as the in-flight fetch completes,
        // creating an infinite cycle that prevents pumpAndSettle from settling in
        // integration tests.
        if (_pagingController.value.isLoading) {
          debugPrint("HomePage: Skipping prepend — page fetch in progress");
          return;
        }
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

  /// Fetches the next page of events across all followed timelines.
  ///
  /// [pageKey] maps each timeline to its pagination state:
  ///   - `lastEventId`: the last event ID that was added to the list
  ///   - `wasExhausted`: whether the timeline has no more history to fetch
  ///
  /// Returns the merged, chronologically sorted events and an updated key for
  /// the next page (or `null` when all timelines are exhausted).
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

      // Start with any candidates carried forward from the previous page
      List<({Event origEvent, Event displayEvent})> roomCandidates =
          _carryForwardCandidates.remove(timeline.room.id) ?? [];
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

          if (isMsg &&
              isNotReply &&
              isNotThread &&
              isNotEdit &&
              _isVisiblePost(event)) {
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

    // Sort all candidates newest first by original timestamp so edits don't change position
    allCandidates.sort(
      (a, b) =>
          b.origEvent.originServerTs.compareTo(a.origEvent.originServerTs),
    );

    // Take top N posts for this page
    ret = allCandidates.take(_pageSize).toList();

    // Update the next key based on what we are actually returning,
    // and carry forward unused candidates to avoid re-fetching them.
    Map<Timeline, ({String? lastEventId, bool wasExhausted})> nextKey = {};
    final retEventIds = ret.map((e) => e.origEvent.eventId).toSet();

    for (Timeline timeline in newPageKey.keys.toList()) {
      final meta = newPageKey[timeline]!;
      final timelineCandidates = candidatesPerTimeline[timeline] ?? [];
      final eventsInRet =
          ret.where((e) => e.origEvent.roomId == timeline.room.id).toList();

      // Advance lastId to the last candidate we processed, not just the last
      // one in ret. This prevents re-scanning the same timeline segment.
      String? lastId =
          timelineCandidates.isNotEmpty
              ? timelineCandidates.last.origEvent.eventId
              : meta.lastEventId;

      if (eventsInRet.isNotEmpty && firstEventIds[timeline.room.id] == null) {
        // Track the newest event ID we've displayed for this room
        firstEventIds[timeline.room.id] = eventsInRet.first.origEvent.eventId;
      }

      // Carry forward candidates that were fetched but didn't make it into
      // this page (e.g. because another room had newer events).
      final unused =
          timelineCandidates
              .where((e) => !retEventIds.contains(e.origEvent.eventId))
              .toList();
      if (unused.isNotEmpty) {
        _carryForwardCandidates[timeline.room.id] = unused;
      }

      bool isExhausted = !timeline.canRequestHistory && unused.isEmpty;

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

  // ── Search logic ────────────────────────────────────────────────────────────

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _searchGeneration++;
    final generation = _searchGeneration;
    setState(() => _isSearching = true);

    try {
      final timelines = await _timelinesFuture;
      final allResults = <({Event origEvent, Event displayEvent})>[];

      for (final timeline in timelines) {
        if (generation != _searchGeneration) return; // stale query
        final room = timeline.room;
        final lowerQuery = trimmed.toLowerCase();

        // Search events in local database + server fallback.
        final result = await room.searchEvents(
          searchTerm: trimmed,
          searchFunc: (event) {
            if (event.type != 'm.room.message') return false;
            if (!_isVisiblePost(event)) return false;
            if (event.relationshipType == RelationshipTypes.edit ||
                event.relationshipType == RelationshipTypes.thread ||
                event.relationshipType == RelationshipTypes.reference) {
              return false;
            }
            final body = event.body.toLowerCase();
            final sender =
                (event.senderFromMemoryOrFallback.displayName ?? '')
                    .toLowerCase();
            return body.contains(lowerQuery) || sender.contains(lowerQuery);
          },
          limit: 50,
        );

        for (final event in result.events) {
          allResults.add((
            origEvent: event,
            displayEvent: event.getDisplayEvent(timeline),
          ));
        }
      }

      // Sort merged results newest-first
      allResults.sort(
        (a, b) =>
            b.origEvent.originServerTs.compareTo(a.origEvent.originServerTs),
      );

      if (generation == _searchGeneration && mounted) {
        setState(() {
          _searchResults = allResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Feed search error: $e');
      if (generation == _searchGeneration && mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchQuery = '';
        _searchResults = [];
        _searchController.clear();
      }
    });
  }

  Widget _buildSearchResults(ThemeData theme, ColorScheme colorScheme) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'search.empty'.tr(args: [_searchQuery]),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return GestureDetector(
          onTap:
              () => context.pushIfNew(
                '/room/${item.origEvent.roomId}/${item.origEvent.eventId}',
              ),
          child: PostWidget(
            event: item.origEvent,
            displayEvent: item.displayEvent,
          ),
        );
      },
    );
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
    _feedStateCache = Provider.of<FeedStateCache>(context, listen: false);
    _loadingService = Provider.of<LoadingService>(context, listen: false);

    // Initialize SubstitutionService cache
    _substitutionService.init();

    _timelinesFuture = _fetchTimelines();

    // Restore paging state from cache when navigating back
    final bool restoreFromCache =
        widget.roomId == null && _feedStateCache.hasCache;
    if (restoreFromCache) {
      pageKeyInitialized = _feedStateCache.wasPageKeyInitialized;
      if (_feedStateCache.firstEventIds != null) {
        firstEventIds = Map<String, String>.from(
          _feedStateCache.firstEventIds!,
        );
      }
      if (_feedStateCache.lastPageKey != null) {
        _latestNextPageKey = _feedStateCache.lastPageKey;
      }
    }

    // Initialize the scroll controller with the cached offset so the list
    // starts at the correct position from the very first frame — no
    // post-frame callback or maxScrollExtent race condition needed.
    _scrollController = ScrollController(
      initialScrollOffset:
          restoreFromCache ? _feedStateCache.scrollOffset : 0.0,
    );

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
        _loadingService.setLoading('feed');
        try {
          final result = await _fetchEvents(pageKey);
          _latestNextPageKey = result.nextKey;
          return result.events;
        } finally {
          _loadingService.setDone('feed');
        }
      },
    );
    // Note: do NOT addListener(setState) here — it causes the entire HomePage
    // (including nested paging fetches) to rebuild on every PagingController
    // state change, creating an infinite rebuild loop under pumpAndSettle.
    // The PagedListView reads _pagingController.value directly and is wrapped
    // in a ListenableBuilder so only the list subtree rebuilds.

    // Pre-populate the PagingController with cached items so the list renders
    // immediately without showing a loading spinner.
    if (restoreFromCache) {
      final cached = _feedStateCache.cachedItems!;
      _pagingController.value = _pagingController.value.copyWith(
        pages: [cached],
        keys: [_feedStateCache.lastPageKey],
      );
    }

    // Initialize connectivity tracking
    _connectivityStream = _connectivityService.onConnectivityChanged;
    _connectivitySubscription = _connectivityStream.listen(
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
      // Clear the scroll cache so the rebuilt feed starts fresh.
      _feedStateCache.clear();
      setState(() {
        // Reset paging state so that the next _fetchEvents call
        // re-reads the updated timeline list instead of returning early.
        pageKeyInitialized = false;
        _latestNextPageKey = null;
        _carryForwardCandidates = {};
        _timelinesFuture = _fetchTimelines();
        _pagingController.refresh();
      });
    });
  }

  @override
  void dispose() {
    // Persist feed state for scroll restoration when navigating back.
    // Only cache for the global feed (roomId == null), not per-room feeds.
    if (widget.roomId == null) {
      final pages = _pagingController.value.pages;
      if (pages != null && pages.isNotEmpty) {
        _feedStateCache.cachedItems = pages.expand((page) => page).toList();
      }
      _feedStateCache.scrollOffset =
          _scrollController.hasClients ? _scrollController.offset : 0.0;
      _feedStateCache.lastPageKey = _latestNextPageKey;
      _feedStateCache.firstEventIds = Map<String, String>.from(firstEventIds);
      _feedStateCache.wasPageKeyInitialized = pageKeyInitialized;
    }

    _connectivitySubscription?.cancel();
    _loadingService.setDone('feed');
    _substitutionService.removeListener(_handleRoomChanges);
    _scrollController.dispose();
    _pagingController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // Search button in the app bar – only shown on home/room feeds, not per-post.
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'fabSearch',
        onPressed: _toggleSearch,
        tooltip: 'search.hint'.tr(),
        child: Icon(
          _isSearchActive ? Icons.search_off_rounded : Icons.search_rounded,
        ),
      ),
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
                // Search bar
                if (_isSearchActive) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'search.hint'.tr(),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon:
                            _searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _searchResults = [];
                                    });
                                  },
                                )
                                : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                        _runSearch(value);
                      },
                    ),
                  ),
                ],
                if (widget.roomId != null && !_isSearchActive) ...[
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
                ] else if (widget.roomId != null && _isSearchActive) ...[
                  const SizedBox(height: 4),
                ],
                // Search results or normal feed
                if (_isSearchActive && _searchQuery.isNotEmpty)
                  Expanded(child: _buildSearchResults(theme, colorScheme))
                else if (!_isSearchActive || _searchQuery.isEmpty)
                  Expanded(
                    // ListenableBuilder ensures only the list subtree rebuilds
                    // when the paging state changes, avoiding the full-widget
                    // rebuild loop that blocks pumpAndSettle in integration tests.
                    child: ListenableBuilder(
                      listenable: _pagingController,
                      builder:
                          (context, _) => PagedListView<
                            Map<
                              Timeline,
                              ({String? lastEventId, bool wasExhausted})
                            >?,
                            ({Event origEvent, Event displayEvent})
                          >.separated(
                            key: const ValueKey('feedListView'),
                            scrollController: _scrollController,
                            state: _pagingController.value,
                            fetchNextPage: _pagingController.fetchNextPage,
                            // Use spacing instead of dividers for modern look
                            separatorBuilder:
                                (context, index) => const SizedBox(height: 2),
                            builderDelegate: PagedChildBuilderDelegate<
                              ({Event origEvent, Event displayEvent})
                            >(
                              // Loading is indicated by the TopLoadingBar — no
                              // in-list spinners or skeletons that would cause layout
                              // shifts when real content arrives.
                              firstPageProgressIndicatorBuilder:
                                  (context) => const SizedBox.shrink(),
                              newPageProgressIndicatorBuilder:
                                  (context) => const SizedBox.shrink(),
                              noItemsFoundIndicatorBuilder:
                                  (context) => Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                                  color:
                                                      colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                            textAlign: TextAlign.center,
                                          ).tr(),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () {
                                              if (widget.onDiscoverTap !=
                                                  null) {
                                                widget.onDiscoverTap!();
                                              } else {
                                                context.push('/settings/feed');
                                              }
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
                                        () => context.pushIfNew(
                                          '/room/${item.origEvent.roomId}/${item.origEvent.eventId}',
                                        ),
                                    child: PostWidget(
                                      event: item.origEvent,
                                      displayEvent: item.displayEvent,
                                    ),
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
