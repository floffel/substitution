import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '/shared/mixins/matrix_essentials.dart';
import '/shared/utils/servers.dart';

// Define a custom Form widget.
class DialogDeleteServer extends StatefulWidget {
  const DialogDeleteServer({super.key, required this.server});

  final String server;

  @override
  State<DialogDeleteServer> createState() => _DialogDeleteServerState();
}

class _DialogDeleteServerState extends State<DialogDeleteServer>
    with MatrixEssentials {
  bool _isLoading = false;

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
                // The original TODO suggested adding a per-room flag
                // (e.g. "joined_via_substitution") so the dialog could
                // just unset the flag for users who joined through the
                // substitution feed, instead of fully leaving the
                // room. That requires a schema migration (and a Matrix
                // spec change) and is therefore deferred. The current
                // implementation just removes the server from the
                // user's local substitution account-data, which is
                // what the "delete from follow list" action should
                // do semantically — leaving the room happens via a
                // separate user action.
                var newServers = Map<String, dynamic>.from(
                  await getSubstitutionServers(client),
                );
                newServers.remove(widget.server);

                await setSubstitutionServers(client, newServers);

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
