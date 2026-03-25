import '/shared/widgets/mxc_image.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

/// Displays a compact card showing the room avatar, name, and ID.
/// Used on write/compose pages to remind the user which room they are posting to.
class RoomHeaderWidget extends StatelessWidget {
  const RoomHeaderWidget({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context, listen: false);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget leading;
    if (room.avatar != null) {
      final fallback = CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          room.name.isNotEmpty ? room.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      leading = SizedBox(
        width: 40,
        height: 40,
        child: ClipOval(
          child: MxcImage(
            uri: room.avatar!,
            client: client,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            isThumbnail: true,
            placeholder: (_) => fallback,
            errorBuilder: (_, _) => fallback,
          ),
        ),
      );
    } else {
      leading = CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          room.name.isNotEmpty ? room.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: leading,
        title: Text(
          'write.roomheader'.tr(args: [room.name]),
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          room.id,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
