import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

// Define a custom Form widget.
class DialogAddServer extends StatefulWidget {
  const DialogAddServer({super.key});

  @override
  _DialogAddServerState createState() => _DialogAddServerState();
}

class _DialogAddServerState extends State<DialogAddServer> {
  Client get client => Provider.of<Client>(context, listen: false);

  final _matrixServerAdressContrainer = TextEditingController();
  final _matrixServerPopupFormKey = GlobalKey<FormState>();

  String lastValidatedMatrixServerAddr = "";
  bool isInvalidMatrixServer = true;

  // TODO: client id is only valid if a user logged in! Only show this option to logged in users!
  // TODO: this throws an exception if the account data is not valid!
  // so we have to ensure, that the account data exists!
  Future<Map<String, Object?>> get accountData async {
    try {
      return await client.getAccountData(
          client.userID!, "substitution.servers");
    } catch (e) {
      // no account data (e.g. no server is set)
      return {};
    }
  }

  Future checkHost(String serverAddr) async {
    // TODO: this could possibly go wrong, if two validations occour and the second one is faster than the first one... sudo fix this!

    isInvalidMatrixServer = true;

    Room room = Room(
        id: '#substitution:$serverAddr',
        client: Provider.of<Client>(context, listen: false));

    debugPrint("room.lastEvent: ${room.name}");

    if (room.lastEvent != null) {
      isInvalidMatrixServer = false;
      lastValidatedMatrixServerAddr = serverAddr;
      _matrixServerPopupFormKey.currentState?.validate();
    }

    /*try {
        await client.checkHomeserver(Uri.https(serverAddr.trim(), ''));
        isInvalidMatrixServer = false;
      } catch (e) {}
      */
    // TODO: test if (public) space exists on this server
    //final resp = await client.getDiscoveryInformationsByUserId(serverAddr);
  }

  String? validateMatrixServer(String? serverAddr) {
    debugPrint("checking Room #substitution:$serverAddr");

    if (serverAddr == '') {
      return "empty server adress can't contain any matrix server";
    }
    if (!isInvalidMatrixServer && lastValidatedMatrixServerAddr == serverAddr) {
      return null;
    } else {
      checkHost(serverAddr!);
      return "The provided adress contains no for this app configured matrix server";
    }
    //Room? room = Provider.of<Client>(context, listen: false)
    //    .getRoomById('#substitution:$serverAddr');

    /*if (room == null) {
        // TODO: intl
        return "The provided adress contains no for this app configured matrix server";
      } else if (!room.isSpace) {
        return "The provided adress contains an oddly configured room, we cannot use it";
      }*/

    return null;
  }

  Future<void> addRoom() async {
    // TODO: server aufnehmen!
    /*Room room = Room(
                                        id: '#substitution:${_matrixServerAdressContrainer.text}',
                                        client: Provider.of<Client>(context, listen: false));*/

    var navState = Navigator.of(context);
    var scavMsg = ScaffoldMessenger.of(context);

    // TODO: make this async test as soon as the user entered the new server
    // TODO: mby wrap it in a try/catch block, b.c. it can error if the server won't allow querying (over federation/public)
    QueryPublicRoomsResponse resp = await client.queryPublicRooms(
        server: _matrixServerAdressContrainer.text, limit: 1);

    if ((resp.totalRoomCountEstimate ?? 0) > 0) {
      // TODO: show loading animation

      await client.setAccountData(client.userID!, "substitution.servers",
          {_matrixServerAdressContrainer.text: null, ...await accountData});

      scavMsg.showSnackBar(SnackBar(
        content: const Text("settings.dialog.add.snackbar.success").tr(),
      ));

      navState.pop(true);
    } else {
      scavMsg.showSnackBar(SnackBar(
        content: const Text("settings.dialog.add.snackbar.error_homeserver")
            .tr(), // todo intl
      ));
      navState.pop(false);
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
              /*suffixIcon: Icon(
                                              (_matrixServerPopupFormKey
                                                              .currentState !=
                                                          null &&
                                                      _matrixServerPopupFormKey
                                                          .currentState!
                                                          .validate())
                                                  ? Icons.check_circle
                                                  : Icons
                                                      .cancel), // while checking: Icons.help, matrix-server: Icons.check_circle, no matrix server: Icons.cancel
                                          */ // todo: do with validation
            ),
            //validator: validateMatrixServer, TODO: I don't know how to check if a room really exists
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('settings.dialog.add.button.submit').tr(),
            onPressed: () async => await addRoom(),
          ),
        ]);
  }
}
