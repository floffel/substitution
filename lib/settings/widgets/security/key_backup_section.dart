import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

/// Section widget showing the online key backup status.
class KeyBackupSection extends StatelessWidget {
  final Client client;
  final bool backupEnabled;
  final bool backupCached;

  const KeyBackupSection({
    super.key,
    required this.client,
    required this.backupEnabled,
    required this.backupCached,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isGood = backupEnabled && backupCached;
    final icon = isGood ? Icons.cloud_done_rounded : Icons.cloud_off_rounded;
    final color = isGood ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.security.backup.title'.tr(),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isGood
                        ? 'settings.security.backup.enabled'.tr()
                        : backupEnabled
                        ? 'settings.security.backup.not_cached'.tr()
                        : 'settings.security.backup.disabled'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isGood ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
