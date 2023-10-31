import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// Define a custom Form widget.
class DialogDeleteServer extends StatefulWidget {
  const DialogDeleteServer({super.key, required this.server});

  final String server;

  @override
  _DialogDeleteServerState createState() => _DialogDeleteServerState();
}

class _DialogDeleteServerState extends State<DialogDeleteServer> {
  Client get client => Provider.of<Client>(context, listen: false);

  // TODO: client id is only valid if a user logged in! Only show this option to logged in users!
  // TODO: this throws an exception if the account data is not valid!
  // so we have to ensure, that the account data exists!
  Future<Map<String, Object?>> get accountData async =>
      await client.getAccountData(client.userID!, "substitution.servers");

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text('Delete ${widget.server}?'),
        content: Text("Delete ${widget.server}?"),
        actions: <Widget>[
          TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                var navState = Navigator.of(context);

                // todo: leave the rooms and delete the substitution flag, so we really clean up
                // todo: maybe we have to add a new flag to rooms, which where already joined while adding it to substitution
                //       so we can just delete the substition flag and don't leave the room
                // todo: display loading animation or smthg. while leaving the rooms and deleting the keys

                var newServers = await accountData;
                newServers.remove(widget.server);

                client.setAccountData(
                    client.userID!, "substitution.servers", newServers);

                navState.pop(true);
              }),
          TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                var navState = Navigator.of(context);

                navState.pop();
              })
        ]); // TODO: leave all rooms where the local substitution flag is set and delete this flag
  }
}
