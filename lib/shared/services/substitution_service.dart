import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import '../extensions/client_extensions.dart';

class SubstitutionService extends ChangeNotifier {
  final Client _client;
  final Set<String> _substitutionRoomIds = {};
  Future<void>? _initFuture;

  SubstitutionService(this._client);

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
    final joined = await _client.getJoinedRooms();
    for (final roomId in joined) {
      if (await _client.isRoomInSubstitution(roomId)) {
        _substitutionRoomIds.add(roomId);
      }
    }
  }

  bool isSubstitutionRoom(String roomId) {
    return _substitutionRoomIds.contains(roomId);
  }

  /// Joins a room and marks it as a 'substitution' room in account data.
  Future<void> joinRoom(String roomId, {List<String>? serverNames}) async {
    await _client.joinRoom(roomId, serverName: serverNames);

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

  /// External trigger to notify about changes if needed (e.g. after sync)
  void triggerRefresh() {
    notifyListeners();
  }
}
