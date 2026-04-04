import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

/// Represents the verification status of a device.
enum DeviceVerificationStatus { verified, unverified, blocked }

/// Extension to determine verification status from DeviceKeys.
extension VerificationStatusExt on DeviceKeys {
  DeviceVerificationStatus get verificationStatus {
    if (blocked) return DeviceVerificationStatus.blocked;
    if (verified) return DeviceVerificationStatus.verified;
    return DeviceVerificationStatus.unverified;
  }
}

/// Holds combined data from DeviceKeys and the Device API response.
class DeviceData {
  final DeviceKeys keys;
  final Device? apiDevice;

  DeviceData({required this.keys, this.apiDevice});

  String get displayName =>
      keys.deviceDisplayName ??
      apiDevice?.displayName ??
      'settings.security.devices.unknown_device'.tr();
  String get deviceId =>
      keys.deviceId ?? 'settings.security.devices.unknown_id'.tr();
  bool get isCurrentDevice => false; // Set externally
  DateTime? get lastSeen =>
      apiDevice?.lastSeenTs != null
          ? DateTime.fromMillisecondsSinceEpoch(apiDevice!.lastSeenTs!)
          : null;
  String? get lastSeenIp => apiDevice?.lastSeenIp;
}

/// A card displaying a single device with its verification status,
/// session info, and action buttons.
class DeviceCard extends StatelessWidget {
  final DeviceData device;
  final bool isCurrentDevice;
  final VoidCallback? onVerify;
  final VoidCallback? onBlock;
  final VoidCallback? onUnblock;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const DeviceCard({
    super.key,
    required this.device,
    this.isCurrentDevice = false,
    this.onVerify,
    this.onBlock,
    this.onUnblock,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = device.keys.verificationStatus;
    final icon = _getStatusIcon(status);
    final color = _getStatusColor(status, colorScheme);
    final statusLabel = _getStatusLabel(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              device.displayName,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentDevice) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'settings.security.devices.this_device'.tr(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device.deviceId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            // Session metadata
            if (device.lastSeen != null || device.lastSeenIp != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (device.lastSeen != null)
                      _buildMetaChip(
                        context,
                        Icons.access_time_rounded,
                        _formatLastSeen(device.lastSeen!),
                      ),
                    if (device.lastSeenIp != null)
                      _buildMetaChip(
                        context,
                        Icons.language_rounded,
                        device.lastSeenIp!,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Action buttons
            Row(
              children: [
                if (status == DeviceVerificationStatus.unverified &&
                    onVerify != null) ...[
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onVerify,
                      icon: const Icon(Icons.verified_user_rounded, size: 18),
                      label: Text('settings.security.devices.verify'.tr()),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (status == DeviceVerificationStatus.blocked &&
                    onUnblock != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onUnblock,
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      label: Text('settings.security.devices.unblock'.tr()),
                    ),
                  ),
                if (status != DeviceVerificationStatus.blocked &&
                    onBlock != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onBlock,
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: Text('settings.security.devices.block'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(
                          color: colorScheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                if (!isCurrentDevice && onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.error,
                      size: 20,
                    ),
                    tooltip: 'settings.security.devices.delete'.tr(),
                    style: IconButton.styleFrom(
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
                if (onRename != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onRename,
                    icon: Icon(
                      Icons.edit_outlined,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    tooltip: 'settings.security.devices.rename'.tr(),
                    style: IconButton.styleFrom(
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatLastSeen(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 5) return 'settings.security.devices.just_now'.tr();
    if (diff.inHours < 1) {
      return 'settings.security.devices.minutes_ago'.tr(
        args: ['${diff.inMinutes}'],
      );
    }
    if (diff.inDays < 1) {
      return 'settings.security.devices.hours_ago'.tr(
        args: ['${diff.inHours}'],
      );
    }
    if (diff.inDays < 30) {
      return 'settings.security.devices.days_ago'.tr(args: ['${diff.inDays}']);
    }
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  IconData _getStatusIcon(DeviceVerificationStatus status) {
    return switch (status) {
      DeviceVerificationStatus.verified => Icons.verified_user_rounded,
      DeviceVerificationStatus.unverified => Icons.help_outline_rounded,
      DeviceVerificationStatus.blocked => Icons.block_rounded,
    };
  }

  Color _getStatusColor(
    DeviceVerificationStatus status,
    ColorScheme colorScheme,
  ) {
    return switch (status) {
      DeviceVerificationStatus.verified => colorScheme.primary,
      DeviceVerificationStatus.unverified => colorScheme.tertiary,
      DeviceVerificationStatus.blocked => colorScheme.error,
    };
  }

  String _getStatusLabel(DeviceVerificationStatus status) {
    return switch (status) {
      DeviceVerificationStatus.verified =>
        'settings.security.devices.verified'.tr(),
      DeviceVerificationStatus.unverified =>
        'settings.security.devices.unverified'.tr(),
      DeviceVerificationStatus.blocked =>
        'settings.security.devices.blocked'.tr(),
    };
  }
}
