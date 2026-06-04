import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Red-tinted "danger zone" card shown only in edit mode, housing the
/// destructive "delete room" action.
///
/// Stateless and reusable — caller supplies the [onDeleteRoom] callback
/// (typically the `_deleteRoom` method in `RoomFormPage`).
class RoomDangerZone extends StatelessWidget {
  const RoomDangerZone({super.key, required this.onDeleteRoom});

  /// Invoked when the user taps the "Delete room" button.
  final VoidCallback onDeleteRoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: colorScheme.errorContainer.withValues(alpha: 0.15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'settings.room_form.section_danger'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                  label: Text('settings.room_form.delete_room'.tr()),
                  onPressed: onDeleteRoom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
