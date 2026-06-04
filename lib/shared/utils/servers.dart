import 'package:matrix/matrix.dart';

/// The Matrix account-data key used to persist the list of Substitution
/// homeservers the user follows.
///
/// The stored value is a `Map<String, Object?>` where each key is a server
/// hostname (e.g. `matrix.org`) and each value is currently either `null`
/// (manually added by the user) or `{"added_automatically": true}` (the
/// user's own homeserver, seeded on first run).
const String substitutionServersAccountDataKey = 'substitution.servers';

/// Reads the Substitution servers account-data map from the Matrix server.
///
/// Returns an empty map on any error (first-time users have no account
/// data yet, and a malformed response should not crash the UI).
///
/// Callers that need a cached future (e.g. for use in a `FutureBuilder`
/// across multiple rebuilds) should wrap the result themselves.
Future<Map<String, Object?>> getSubstitutionServers(Client client) async {
  try {
    return await client.getAccountData(
      client.userID!,
      substitutionServersAccountDataKey,
    );
  } catch (e) {
    // First-time user, network error, or malformed account data.
    // All of these are "no servers yet" from the UI's perspective.
    return <String, Object?>{};
  }
}

/// Writes the Substitution servers account-data map to the Matrix server.
///
/// Throws if the network call fails — callers are responsible for showing
/// an error to the user.
Future<void> setSubstitutionServers(
  Client client,
  Map<String, Object?> servers,
) async {
  await client.setAccountData(
    client.userID!,
    substitutionServersAccountDataKey,
    servers,
  );
}
