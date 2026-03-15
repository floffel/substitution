import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

// Define a custom Form widget.
class DialogDeleteServer extends StatefulWidget {
  const DialogDeleteServer({super.key, required this.server});

  final String server;

  @override
  State<DialogDeleteServer> createState() => _DialogDeleteServerState();
}

class _DialogDeleteServerState extends State<DialogDeleteServer> {
  Client get client => Provider.of<Client>(context, listen: false);
  bool _isLoading = false;

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
      title: const Text(
        "settings.dialog.delete.title",
      ).tr(args: [widget.server]), //Delete ${widget.server}?'),
      content: const Text(
        "settings.dialog.delete.desc",
      ).tr(args: [widget.server]), // Delete ${widget.server}?"),
      actions: <Widget>[
        if (_isLoading)
          const CircularProgressIndicator()
        else
          TextButton(
            child: const Text("settings.dialog.delete.button.submit").tr(),
            onPressed: () async {
              final navigator = Navigator.of(context);
              setState(() {
                _isLoading = true;
              });

              try {
                // todo: maybe we have to add a new flag to rooms, which where already joined while adding it to substitution
                //       so we can just delete the substition flag and don't leave the room

                var newServers = Map<String, dynamic>.from(await accountData);
                newServers.remove(widget.server);

                await client.setAccountData(
                  client.userID!,
                  "substitution.servers",
                  newServers,
                );

                navigator.pop(true);
              } catch (e) {
                debugPrint("Error deleting server: $e");
                // Show error?
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
          ),
        if (!_isLoading)
          TextButton(
            child: const Text("settings.dialog.delete.button.cancel").tr(),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}
