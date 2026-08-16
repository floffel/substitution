import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

import '../extensions/client_extensions.dart';

class SubstitutionService extends ChangeNotifier {
  final Client _client;
  final Set<String> _substitutionRoomIds = {};
  Future<void>? _initFuture;
  StreamSubscription? _syncSubscription;
  bool _isRefreshingFromLocal = false;

  /// Returns true if the service has finished its initial room discovery.
  bool get isInitialized => _initFuture != null;

  /// Returns the number of rooms currently tracked.
  int get roomCount => _substitutionRoomIds.length;

  /// Read-only view of tracked substitution room IDs.
  Set<String> get substitutionRoomIds => Set.unmodifiable(_substitutionRoomIds);

  SubstitutionService(this._client) {
    // Listen for sync completion to trigger UI updates (e.g. new messages)
    try {
      _syncSubscription = _client.onSyncStatus.stream.listen((status) {
        if (status.status == SyncStatus.finished) {
          unawaited(_refreshFromLocalRooms());
          // Throttled notification to avoid rapid refresh loops in the UI
          final now = DateTime.now();
          if (_lastSyncNotify == null ||
              now.difference(_lastSyncNotify!) > const Duration(seconds: 2)) {
            _lastSyncNotify = now;
            notifyListeners();
          }
        }
      });
    } catch (e) {
      // In tests, MockClient.onSyncStatus might be null if not stubbed.
    }
  }

  DateTime? _lastSyncNotify;

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  /// Call once (e.g. in HomePage.initState) to pre-populate the local cache
  /// from the Matrix server's account data.
  Future<void> init() {
    _initFuture ??= _ensureInitialized();
    return _initFuture!;
  }

  Future<void> _ensureInitialized() async {
    // In a real app, we might want to fetch all rooms and their account data.
    // For now, we trust the join/leave flow and maybe a sync.
    // To be really robust, we'd iterate joined rooms once.

    // Wait for initial sync if not yet synced to ensure local roomAccountData is populated
    if (_client.prevBatch == null) {
      try {
        await _client.onSync.stream
            .firstWhere((_) => _client.prevBatch != null)
            .timeout(const Duration(seconds: 30));
      } catch (_) {
        // Timeout reached, proceed anyway
      }
    }

    final joined = await _client.getJoinedRooms();
    final seeded = <String>{};

    final results = await Future.wait(
      joined.map((roomId) => _client.isRoomInSubstitution(roomId)),
    );

    for (int i = 0; i < joined.length; i++) {
      if (results[i]) {
        seeded.add(joined[i]);
      }
    }

    _substitutionRoomIds
      ..clear()
      ..addAll(seeded);

    await _refreshFromLocalRooms();
    notifyListeners();
  }

  Future<void> _refreshFromLocalRooms() async {
    if (_isRefreshingFromLocal) return;
    _isRefreshingFromLocal = true;

    try {
      final localSubstitutionRooms =
          _client.rooms
              .where((r) => r.membership == Membership.join)
              .where((r) {
                final data = r.roomAccountData['substitution'];
                return data?.content['joined'] == true;
              })
              .map((r) => r.id)
              .toSet();

      final changed =
          localSubstitutionRooms.length != _substitutionRoomIds.length ||
          !localSubstitutionRooms.containsAll(_substitutionRoomIds);

      if (!changed) return;

      _substitutionRoomIds
        ..clear()
        ..addAll(localSubstitutionRooms);
      notifyListeners();
    } finally {
      _isRefreshingFromLocal = false;
    }
  }

  @visibleForTesting
  Future<void> debugRefreshFromLocalRooms() => _refreshFromLocalRooms();

  bool isSubstitutionRoom(String roomId) {
    return _substitutionRoomIds.contains(roomId);
  }

  /// Joins a room and marks it as a 'substitution' room in account data.
  Future<void> joinRoom(String roomId, {List<String>? serverNames}) async {
    await _client.joinRoom(roomId, via: serverNames);

    // Mark room in substitution app context
    if (_client.userID != null) {
      await _client.setAccountDataPerRoom(
        _client.userID!,
        roomId,
        "substitution",
        {"joined": true},
      );
    }

    _substitutionRoomIds.add(roomId);
    notifyListeners();
  }

  /// Leaves a room and removes its 'substitution' status in account data.
  Future<void> leaveRoom(String roomId) async {
    // Remove from substitution app context first
    if (_client.userID != null) {
      await _client.setAccountDataPerRoom(
        _client.userID!,
        roomId,
        "substitution",
        {},
      );
    }

    await _client.leaveRoom(roomId);

    _substitutionRoomIds.remove(roomId);
    notifyListeners();
  }

  /// Directly add a room ID to the in-memory set without touching Matrix
  /// account data. Useful in tests to bypass async init and directly mark a
  /// room as a substitution room so the feed picks it up.
  void addRoomId(String roomId) {
    _substitutionRoomIds.add(roomId);
  }

  /// Directly remove a room ID from the in-memory set without touching Matrix
  /// account data. Counterpart to [addRoomId].
  void removeRoomId(String roomId) {
    _substitutionRoomIds.remove(roomId);
  }

  /// External trigger to notify about changes if needed (e.g. after sync)
  void triggerRefresh() {
    notifyListeners();
  }
}
