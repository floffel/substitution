import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '/shared/models/substitution_room.dart';
import '/shared/widgets/mxc_image.dart';

// like post but smaller
class RoomWidget extends StatefulWidget {
  const RoomWidget({
    super.key,
    required this.room,
    this.leaveRoom,
    this.joinRoom,
    this.deleteRoom,
    this.onTap,
  });

  // room elements
  final SubstitutionRoom room;

  final Future<void> Function(String roomId)? leaveRoom;
  final Future<void> Function(String roomId)? joinRoom;
  final Future<void> Function(String roomId)? deleteRoom;

  /// Called when the user taps on the room tile body (not the action buttons).
  final VoidCallback? onTap;

  @override
  RoomWidgetState createState() => RoomWidgetState();
}

class RoomWidgetState extends State<RoomWidget> {
  Client get client => Provider.of<Client>(context, listen: false);

  bool get showLeaveRoom =>
      widget.room.isInsideSubstitution &&
      widget.room.joined &&
      widget.leaveRoom != null;
  bool get showJoinRoom => widget.joinRoom != null;
  bool get showDeleteRoom => widget.deleteRoom != null;

  bool get isAdminRoom {
    final room = client.getRoomById(widget.room.id);
    return room != null && room.ownPowerLevel >= 100;
  }

  Widget _buildLeadingAvatar(ColorScheme colorScheme) {
    final fallback = CircleAvatar(
      radius: 22,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        widget.room.name.isNotEmpty ? widget.room.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (widget.room.avatarUrl != null &&
        widget.room.avatarUrl!.startsWith('mxc://')) {
      return SizedBox(
        width: 44,
        height: 44,
        child: ClipOval(
          child: MxcImage(
            uri: Uri.parse(widget.room.avatarUrl!),
            client: client,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            isThumbnail: true,
            placeholder: (_) => fallback,
            errorBuilder: (_, _) => fallback,
          ),
        ),
      );
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      onTap: widget.onTap,
      title: Text(
        'settings.room.desc'.tr(args: [widget.room.name]),
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        widget.room.id,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: _buildLeadingAvatar(colorScheme),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdminRoom)
            IconButton(
              icon: Icon(
                Icons.settings_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              tooltip: 'settings.room.permissions'.tr(),
              onPressed: () {
                context.push('/settings/room/${widget.room.id}/permissions');
              },
            ),
          showLeaveRoom
              ? IconButton(
                icon: Icon(
                  Icons.person_remove_rounded,
                  color: colorScheme.error,
                ),
                tooltip: 'settings.room.leave'.tr(),
                onPressed: () async {
                  await widget.leaveRoom!(widget.room.id);
                },
              )
              : showJoinRoom
              ? IconButton(
                icon: Icon(
                  Icons.person_add_rounded,
                  color: colorScheme.primary,
                ),
                tooltip: 'settings.room.join'.tr(),
                onPressed: () async {
                  await widget.joinRoom!(widget.room.id);
                },
              )
              : const SizedBox.shrink(),
          if (showDeleteRoom) ...[
            IconButton(
              icon: Icon(Icons.delete_rounded, color: colorScheme.error),
              tooltip: 'settings.room.delete'.tr(),
              onPressed: () async {
                await widget.deleteRoom!(widget.room.id);
              },
            ),
          ],
        ],
      ),
    );
  }
}
