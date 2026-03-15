import 'package:matrix/matrix.dart';

extension SubstitutionClientExtension on Client {
  /// Checks if a room is joined in the context of the 'substitution' app.
  /// This checks the account data for the 'substitution' key and verifies if 'joined' is true.
  Future<bool> isRoomInSubstitution(String roomId) async {
    if (userID == null) return false;

    try {
      // First try to check the room's in-memory account data which is populated by sync
      final room = getRoomById(roomId);
      if (room != null) {
        final data = room.roomAccountData['substitution'];
        if (data != null) {
          return data.content['joined'] == true;
        }
        // If the room is synced but doesn't have the data, we might optionally fallback to network,
        // but typically sync has everything. We'll fallback just in case.
      }

      final accountData = await getAccountDataPerRoom(
        userID!,
        roomId,
        "substitution",
      );
      return accountData["joined"] == true;
    } catch (_) {
      return false;
    }
  }
}
