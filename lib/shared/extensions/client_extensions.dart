import 'package:matrix/matrix.dart';

extension SubstitutionClientExtension on Client {
  /// Checks if a room is joined in the context of the 'substitution' app.
  /// This checks the account data for the 'substitution' key and verifies if 'joined' is true.
  Future<bool> isRoomInSubstitution(String roomId) async {
    if (userID == null) return false;

    try {
      final accountData =
          await getAccountDataPerRoom(userID!, roomId, "substitution");
      return accountData["joined"] == true;
    } catch (_) {
      return false;
    }
  }
}
