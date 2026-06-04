import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Basic room info section: name, alias (optional), and topic.
///
/// All three fields are controlled by parent-owned [TextEditingController]s
/// so the form can call `controller.text` at submit time without waiting
/// for the field widgets to commit.
///
/// The alias field is optional; when non-empty it must match the Matrix
/// alias localpart charset. The [homeserverSuffix] is shown as an inline
/// suffix (e.g. `:matrix.org`) so the user understands the full alias
/// shape that will be sent to the server.
class RoomBasicInfoForm extends StatelessWidget {
  const RoomBasicInfoForm({
    super.key,
    required this.nameController,
    required this.aliasController,
    required this.topicController,
    required this.homeserverSuffix,
  });

  final TextEditingController nameController;
  final TextEditingController aliasController;
  final TextEditingController topicController;

  /// Suffix to show after the alias field, e.g. `"matrix.org"`.
  /// Falls back to `"homeserver"` if null.
  final String? homeserverSuffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'settings.room_form.name_label'.tr(),
            prefixIcon: const Icon(Icons.label_outline_rounded),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'settings.room_form.name_required'.tr();
            }
            return null;
          },
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: aliasController,
          decoration: InputDecoration(
            labelText: 'settings.room_form.alias_label'.tr(),
            hintText: 'settings.room_form.alias_hint'.tr(),
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            // Show the homeserver suffix inline so users understand
            // what the full alias will look like.
            suffixText: ':${homeserverSuffix ?? 'homeserver'}',
            prefixText: '#',
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return null; // optional
            final valid = RegExp(r'^[a-z0-9._=\-/]+$').hasMatch(v);
            if (!valid) {
              return 'settings.room_form.alias_invalid'.tr();
            }
            return null;
          },
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: topicController,
          decoration: InputDecoration(
            labelText: 'settings.room_form.topic_label'.tr(),
            hintText: 'settings.room_form.topic_hint'.tr(),
            prefixIcon: const Icon(Icons.notes_rounded),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          minLines: 2,
          textInputAction: TextInputAction.newline,
        ),
      ],
    );
  }
}
