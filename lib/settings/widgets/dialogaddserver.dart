import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

import '/shared/mixins/matrix_essentials.dart';
import '/shared/utils/servers.dart';

// Define a custom Form widget.
class DialogAddServer extends StatefulWidget {
  const DialogAddServer({super.key});

  @override
  State<DialogAddServer> createState() => _DialogAddServerState();
}

class _DialogAddServerState extends State<DialogAddServer>
    with MatrixEssentials {
  final _matrixServerAdressContrainer = TextEditingController();
  final _matrixServerPopupFormKey = GlobalKey<FormState>();

  String lastValidatedMatrixServerAddr = "";
  bool isInvalidMatrixServer = true;
  bool _isLoading = false;

  // Monotonic counter used to discard stale [checkHost] results. Each call
  // captures the current value, and only the result with the matching value
  // is allowed to mutate state. Without this, two near-simultaneous
  // validations could complete in the wrong order (e.g. the user types
  // "abc", then quickly "abcdef" — if the first server lookup finished
  // after the second, the form could mark "abc" as valid).
  int _validationSeq = 0;

  // Account data may legitimately be empty for first-time users; treat
  // any read error as "no data" instead of crashing. Callers must still
  // guard for an empty map when interpreting the result.
  Future<Map<String, Object?>> get accountData => getSubstitutionServers(client);

  Future checkHost(String serverAddr) async {
    // Capture our sequence number; if a later validation kicks off, we'll
    // see the sequence advance and skip applying our (now stale) result.
    final mySeq = ++_validationSeq;

    isInvalidMatrixServer = true;

    Room room = Room(
      id: '#substitution:$serverAddr',
      client: client,
    );

    debugPrint("room.lastEvent: ${room.name}");

    if (room.lastEvent != null) {
      // Only the latest validation gets to update state.
      if (mySeq != _validationSeq || !mounted) return;
      isInvalidMatrixServer = false;
      lastValidatedMatrixServerAddr = serverAddr;
      _matrixServerPopupFormKey.currentState?.validate();
    }

    // Note: the heavier "does this server have a public room directory?"
    // check happens at submit time in [addRoom] (queryPublicRooms + the
    // totalRoomCountEstimate gate). The validator above is intentionally
    // sync (no await) — async lookups belong on the submit path, not in
    // a sync validator that fires on every keystroke.
  }

  String? validateMatrixServer(String? serverAddr) {
    debugPrint("checking Room #substitution:$serverAddr");

    if (serverAddr == '') {
      return "empty server adress can't contain any matrix server";
    }
    if (!isInvalidMatrixServer && lastValidatedMatrixServerAddr == serverAddr) {
      return null;
    }

    checkHost(serverAddr!);
    return "The provided adress contains no for this app configured matrix server";
  }

  Future<void> addRoom() async {
    var navState = Navigator.of(context);
    var scavMsg = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
    });

    try {
      // queryPublicRooms can fail with M_FORBIDDEN or a federation error
      // when the target server doesn't allow public room listing; the
      // catch below surfaces that to the user as a snackbar.
      QueryPublicRoomsResponse resp = await client.queryPublicRooms(
        server: _matrixServerAdressContrainer.text,
        limit: 1,
      );

      if ((resp.totalRoomCountEstimate ?? 0) > 0) {
        final existing = await getSubstitutionServers(client);
        await setSubstitutionServers(client, {
          _matrixServerAdressContrainer.text: null,
          ...existing,
        });

        if (!mounted) return;
        scavMsg.showSnackBar(
          SnackBar(
            content: const Text("settings.dialog.add.snackbar.success").tr(),
          ),
        );

        navState.pop(true);
      } else {
        if (!mounted) return;
        scavMsg.showSnackBar(
          SnackBar(
            content:
                const Text(
                  "settings.dialog.add.snackbar.error_homeserver",
                ).tr(),
          ),
        );
        // Keep dialog open to allow retry
      }
    } catch (e) {
      if (!mounted) return;
      scavMsg.showSnackBar(
        SnackBar(content: const Text("error").tr(args: ['$e'])),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('settings.dialog.add.title').tr(),
      content: Form(
        key: _matrixServerPopupFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: TextFormField(
          controller: _matrixServerAdressContrainer,
          decoration: InputDecoration(
            prefixText: 'https://',
            icon: const Icon(Icons.dns),
            labelText: "settings.dialog.add.input_placeholder".tr(),
          ),
          // The sync validator delegates to checkHost() above. Heavier
          // server-level checks (does the homeserver expose a public
          // room directory?) run on submit in [addRoom].
          validator: validateMatrixServer,
        ),
      ),
      actions: <Widget>[
        if (_isLoading)
          const CircularProgressIndicator()
        else
          TextButton(
            child: const Text('settings.dialog.add.button.submit').tr(),
            onPressed: () async => await addRoom(),
          ),
      ],
    );
  }
}
