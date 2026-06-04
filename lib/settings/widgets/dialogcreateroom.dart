import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart' as matrix;
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '/shared/mixins/matrix_essentials.dart';

// Define a custom Form widget.
class DialogCreateRoom extends StatefulWidget {
  const DialogCreateRoom({super.key});

  @override
  DialogCreateRoomState createState() => DialogCreateRoomState();
}

class DialogCreateRoomState extends State<DialogCreateRoom>
    with MatrixEssentials {
  bool loading = false;
  String? error;

  final _formKey = GlobalKey<FormState>();
  final _roomNameContainer = TextEditingController();
  final _roomTopicContainer = TextEditingController();
  final _roomAliasContainer = TextEditingController();

  /// Synchronous format check. Async availability check happens in
  /// [_validateAliasAvailable] right before submission.
  String? _validateAliasFormat(String? alias) {
    final trimmed = (alias ?? '').trim();
    if (trimmed.isEmpty) return null; // alias is optional
    final valid = RegExp(r'^[a-z0-9._=\-/]+$').hasMatch(trimmed);
    if (!valid) return 'settings.dialog.create.error_alias_invalid'.tr();
    return null;
  }

  /// Asks the homeserver whether [alias] is already taken. Returns the
  /// localized error string if it is, or `null` if it is free.
  ///
  /// Network or federation failures are treated as "could not verify" —
  /// the caller should still attempt the create and let the server
  /// reject on `M_ROOM_IN_USE` if the alias really is taken.
  Future<String?> _validateAliasAvailable(String alias) async {
    try {
      // The matrix SDK throws M_NOT_FOUND when the alias is free and
      // returns a non-null String when it is taken. The null check is
      // kept defensively in case future SDK versions change the contract.
      // ignore: unnecessary_null_comparison
      final existing = await client.getRoomIdByAlias(alias);
      // ignore: unnecessary_null_comparison
      if (existing != null) {
        return 'settings.dialog.create.error_alias_taken'.tr();
      }
      return null;
    } catch (_) {
      // M_NOT_FOUND means the alias is free; any other error means we
      // couldn't verify. Fall through to "no error" so the user can
      // still submit and the server will reject on M_ROOM_IN_USE.
      return null;
    }
  }

  Future<void> _createRoom() async {
    setState(() {
      loading = true;
      error = null;
    });

    String? roomId;

    // Async availability check: ask the homeserver whether the chosen
    // alias is already taken. If the user already saw the format error
    // we wouldn't have reached here, so we can skip that re-check.
    final alias = _roomAliasContainer.text.trim();
    if (alias.isNotEmpty) {
      final fullAlias = '#$alias:${client.userID!.split(':').last}';
      final takenError = await _validateAliasAvailable(fullAlias);
      if (takenError != null) {
        if (!mounted) return;
        setState(() {
          error = takenError;
          loading = false;
        });
        return;
      }
    }

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
        // If the server rejected because the alias is taken, surface that
        // as a specific message instead of the generic "create failed".
        final msg = e.toString();
        if (msg.contains('M_ROOM_IN_USE')) {
          error = 'settings.dialog.create.error_alias_taken'.tr();
        } else {
          error = 'settings.dialog.create.error'.tr();
        }
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
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _roomNameContainer,
                      decoration: InputDecoration(
                        labelText:
                            "settings.dialog.create.placeholder_name".tr(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'settings.dialog.create.error_name_required'
                              .tr();
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _roomAliasContainer,
                      decoration: InputDecoration(
                        labelText:
                            "settings.dialog.create.placeholder_alias".tr(),
                      ),
                      // Sync format check only — async availability check
                      // happens right before submission (see below).
                      validator: _validateAliasFormat,
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
            onPressed: () async {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              await _createRoom();
            },
          ),
      ],
    );
  }
}
