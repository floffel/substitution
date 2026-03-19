import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

import '/shared/constants.dart';
import '/shared/extensions/client_extensions.dart';

/// Shows a dialog asking the user whether to join the Substitution welcome room.
///
/// Skips the dialog silently if the user is already a member of the startroom.
/// Returns `true` if the user chose to join (or was already a member),
/// `false` if they skipped.
Future<bool> showStartroomDialog(BuildContext context, Client client) async {
  if (!client.isLogged()) return false;

  // Check if the user has already joined the startroom
  final alias = AppConstants.substitutionRoomAlias;

  // Try to resolve the alias to a room ID and check membership
  try {
    final resolvedRoom = await client.getRoomIdByAlias(alias);
    final roomId = resolvedRoom.roomId;
    if (roomId != null) {
      final isJoined = await client.isRoomInSubstitution(roomId);
      if (isJoined) return true;
    }
  } catch (_) {
    // Room alias couldn't be resolved — continue showing the dialog
  }

  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final theme = Theme.of(dialogContext);
      final colorScheme = theme.colorScheme;

      return AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.group_add_rounded,
            color: colorScheme.primary,
            size: 40,
          ),
        ),
        title: Text('startroom_dialog.title'.tr()),
        content: Text(
          'startroom_dialog.desc'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('startroomJoinButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.group_add_rounded),
              label: Text('startroom_dialog.join'.tr()),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('startroomSkipButton'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text('startroom_dialog.skip'.tr()),
            ),
          ),
        ],
      );
    },
  );

  if (result == true) {
    try {
      final id = AppConstants.substitutionRoomAlias;
      await client.joinRoom(id, serverName: ["matrix.org"]);
      await client.setAccountDataPerRoom(client.userID!, id, "substitution", {
        "joined": true,
      });
    } catch (e) {
      debugPrint("Error joining startroom: $e");
    }
  }

  return result == true;
}
