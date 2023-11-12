import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart' as matrix;
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

// Define a custom Form widget.
class DialogCreateRoom extends StatefulWidget {
  const DialogCreateRoom({super.key});

  @override
  DialogCreateRoomState createState() => DialogCreateRoomState();
}

class DialogCreateRoomState extends State<DialogCreateRoom> {
  get client => Provider.of<matrix.Client>(context, listen: false);
  bool loading = false;
  String? error;

  final _formKey = GlobalKey<FormState>();
  final _roomNameContainer = TextEditingController();
  final _roomTopicContainer = TextEditingController();
  final _roomAliasContainer = TextEditingController();

  Future<void> _createRoom() async {
    loading = true;
    error = null;
    final String roomId;

    try {
      roomId = await client.createRoom(
          isDirect: true,
          name: _roomNameContainer.text,
          topic: _roomTopicContainer.text,
          roomAliasName: _roomAliasContainer.text,
          visibility: matrix.Visibility.public);
    } catch (e) {
      error = "$e"; // TODO: nicer error message...
      loading = false;
      return;
    }

    final room = client.getRoomById(roomId);
    if (room == null || room.membership != matrix.Membership.join) {
      // Wait for room actually appears in sync
      await client.waitForRoomInSync(roomId, join: true);
    }

    await client.setAccountDataPerRoom(
        client.userID!, roomId, "substitution", {"joined": true});
    loading = false;
    if (!mounted) return;
    context.pop();
  }

  @override
  void dispose() {
    _roomNameContainer.dispose();
    _roomTopicContainer.dispose();
    _roomAliasContainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text('settings.dialog.create.title').tr(),
        content: Column(children: [
          error != null ? Text(error!) : Container(),
          loading
              ? const CircularProgressIndicator()
              : Form(
                  key: _formKey,
                  child: Column(children: [
                    TextFormField(
                      controller: _roomNameContainer,
                      decoration: InputDecoration(
                          labelText:
                              "settings.dialog.create.placeholder_name".tr()),
                    ),
                    TextFormField(
                      controller: _roomAliasContainer,
                      decoration: InputDecoration(
                          labelText:
                              "settings.dialog.create.placeholder_alias".tr()),
                      // todo: validate if the alias is already taken
                    ),
                    TextFormField(
                      controller: _roomTopicContainer,
                      decoration: InputDecoration(
                          labelText:
                              "settings.dialog.create.placeholder_topic".tr()),
                    )
                  ]),
                )
        ]),
        actions: <Widget>[
          TextButton(
            child: const Text('settings.dialog.create.submit').tr(),
            onPressed: () async => await _createRoom(),
          ),
        ]);
  }
}
