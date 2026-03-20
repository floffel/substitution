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
  matrix.Client get client =>
      Provider.of<matrix.Client>(context, listen: false);
  bool loading = false;
  String? error;

  final _formKey = GlobalKey<FormState>();
  final _roomNameContainer = TextEditingController();
  final _roomTopicContainer = TextEditingController();
  final _roomAliasContainer = TextEditingController();

  Future<void> _createRoom() async {
    setState(() {
      loading = true;
      error = null;
    });

    String? roomId;

    try {
      roomId = await client.createRoom(
        isDirect:
            false, // Changed to false as public rooms are usually not direct
        name: _roomNameContainer.text,
        topic: _roomTopicContainer.text,
        roomAliasName:
            _roomAliasContainer.text.isNotEmpty
                ? _roomAliasContainer.text
                : null,
        visibility: matrix.Visibility.public,
      );

      final room = client.getRoomById(roomId);
      if (room == null || room.membership != matrix.Membership.join) {
        // Wait for room actually appears in sync
        await client.waitForRoomInSync(roomId, join: true);
      }

      await client.setAccountDataPerRoom(
        client.userID!,
        roomId,
        "substitution",
        {"joined": true},
      );

      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'settings.dialog.create.error'.tr();
        loading = false;
      });
      return;
    }
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
      content: Column(
        children: [
          error != null ? Text(error!) : Container(),
          loading
              ? const CircularProgressIndicator()
              : Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _roomNameContainer,
                      decoration: InputDecoration(
                        labelText:
                            "settings.dialog.create.placeholder_name".tr(),
                      ),
                    ),
                    TextFormField(
                      controller: _roomAliasContainer,
                      decoration: InputDecoration(
                        labelText:
                            "settings.dialog.create.placeholder_alias".tr(),
                      ),
                      // todo: validate if the alias is already taken
                    ),
                    TextFormField(
                      controller: _roomTopicContainer,
                      decoration: InputDecoration(
                        labelText:
                            "settings.dialog.create.placeholder_topic".tr(),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
      actions: <Widget>[
        if (loading)
          const CircularProgressIndicator()
        else
          TextButton(
            child: const Text('settings.dialog.create.submit').tr(),
            onPressed: () async => await _createRoom(),
          ),
      ],
    );
  }
}
