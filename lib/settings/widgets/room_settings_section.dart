import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'form_section_card.dart';

/// Settings section of the room form: visibility (public/private),
/// encryption, substitution-room toggle (edit mode only), and posting mode
/// (blog/community).
///
/// All toggle values are nullable (`bool?`) to support the tri-state
/// "unset" case during create mode (the server default is only chosen
/// when the user touches the switch).
class RoomSettingsSection extends StatelessWidget {
  const RoomSettingsSection({
    super.key,
    required this.isPublic,
    required this.onIsPublicChanged,
    required this.isEncrypted,
    required this.alreadyEncrypted,
    required this.onIsEncryptedChanged,
    required this.isSubstitutionRoom,
    required this.onIsSubstitutionRoomChanged,
    required this.isBlogMode,
    required this.onIsBlogModeChanged,
    required this.isEditMode,
    required this.canChangeEncryption,
  });

  /// Whether the room is publicly joinable. `null` means "use server
  /// default" (only valid in create mode).
  final bool? isPublic;
  final ValueChanged<bool> onIsPublicChanged;

  /// Whether end-to-end encryption is requested. `null` means "use server
  /// default" (only valid in create mode).
  final bool? isEncrypted;

  /// If `true`, the room already has encryption enabled and the field is
  /// rendered as a read-only badge (encryption is one-way in Matrix —
  /// it can only be enabled, never disabled).
  final bool alreadyEncrypted;
  final ValueChanged<bool> onIsEncryptedChanged;

  /// Whether the room is marked as a Substitution room (controls whether
  /// it shows up in the user's Substitution feed).
  final bool isSubstitutionRoom;
  final ValueChanged<bool> onIsSubstitutionRoomChanged;

  /// `true` = blog mode (only moderators/admins with power ≥ 50 can post);
  /// `false` = community mode (anyone can post).
  final bool isBlogMode;
  final ValueChanged<bool> onIsBlogModeChanged;

  /// Whether the form is in edit mode (existing room) vs. create mode.
  /// The substitution-room toggle is only shown in edit mode.
  final bool isEditMode;

  /// Whether the user is allowed to toggle encryption at all. When
  /// `false`, the field is rendered as a read-only line.
  final bool canChangeEncryption;

  @override
  Widget build(BuildContext context) {
    return FormSectionCard(
      title: 'settings.room_form.section_settings'.tr(),
      children: [
        // Visibility
        FormToggleTile(
          icon:
              isPublic == true
                  ? Icons.public_rounded
                  : Icons.lock_outline_rounded,
          title: 'settings.room_form.visibility_label'.tr(),
          subtitle:
              isPublic == true
                  ? 'settings.room_form.visibility_public_desc'.tr()
                  : 'settings.room_form.visibility_private_desc'.tr(),
          value: isPublic ?? false,
          onChanged: onIsPublicChanged,
        ),
        const Divider(height: 1),

        // Encryption
        if (alreadyEncrypted)
          const _EncryptionLockedTile()
        else
          _EncryptionToggleTile(
            isEncrypted: isEncrypted,
            canChangeEncryption: canChangeEncryption,
            onChanged: onIsEncryptedChanged,
          ),
        const Divider(height: 1),

        // Substitution room toggle (edit mode only)
        if (isEditMode) ...[
          FormToggleTile(
            icon:
                isSubstitutionRoom
                    ? Icons.dynamic_feed_rounded
                    : Icons.dynamic_feed_outlined,
            title: 'settings.room_form.substitution_label'.tr(),
            subtitle:
                isSubstitutionRoom
                    ? 'settings.room_form.substitution_on_desc'.tr()
                    : 'settings.room_form.substitution_off_desc'.tr(),
            value: isSubstitutionRoom,
            onChanged: onIsSubstitutionRoomChanged,
          ),
          const Divider(height: 1),
        ],

        // Posting mode
        FormToggleTile(
          icon: isBlogMode ? Icons.edit_off_rounded : Icons.edit_rounded,
          title: 'settings.room_form.posting_mode_label'.tr(),
          subtitle:
              isBlogMode
                  ? 'settings.room_form.posting_blog_desc'.tr()
                  : 'settings.room_form.posting_community_desc'.tr(),
          value: isBlogMode,
          onChanged: onIsBlogModeChanged,
        ),
      ],
    );
  }
}

/// Read-only "encryption is on" line. Matrix rooms can be encrypted
/// but never un-encrypted, so once it's on we just show a status row.
class _EncryptionLockedTile extends StatelessWidget {
  const _EncryptionLockedTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.lock_rounded, color: colorScheme.primary),
      title: Text(
        'settings.room_form.encryption_label'.tr(),
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        'settings.room_form.encryption_already_on'.tr(),
        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary),
      ),
      trailing: Icon(Icons.check_circle_rounded, color: colorScheme.primary),
    );
  }
}

/// Editable encryption toggle. Shows a warning label when the user turns
/// encryption on (it's an important decision and the action is one-way).
class _EncryptionToggleTile extends StatelessWidget {
  const _EncryptionToggleTile({
    required this.isEncrypted,
    required this.canChangeEncryption,
    required this.onChanged,
  });

  final bool? isEncrypted;
  final bool canChangeEncryption;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormToggleTile(
          icon:
              isEncrypted == true
                  ? Icons.lock_rounded
                  : Icons.lock_open_rounded,
          title: 'settings.room_form.encryption_label'.tr(),
          subtitle: 'settings.room_form.encryption_desc'.tr(),
          value: isEncrypted ?? false,
          onChanged: canChangeEncryption ? onChanged : (_) {},
        ),
        if (isEncrypted == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'settings.room_form.encryption_warning'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
