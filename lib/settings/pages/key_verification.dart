import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// Represents the verification status of a device
enum DeviceVerificationStatus { verified, unverified, blocked }

/// Extension to determine verification status from DeviceKeys
extension VerificationStatusExt on DeviceKeys {
  DeviceVerificationStatus get verificationStatus {
    if (blocked) {
      return DeviceVerificationStatus.blocked;
    } else if (verified) {
      return DeviceVerificationStatus.verified;
    } else {
      return DeviceVerificationStatus.unverified;
    }
  }
}

/// KeyVerificationPage displays the user's devices and allows verification
class KeyVerificationPage extends StatefulWidget {
  const KeyVerificationPage({super.key});

  @override
  State<KeyVerificationPage> createState() => _KeyVerificationPageState();
}

class _KeyVerificationPageState extends State<KeyVerificationPage> {
  Client get client => Provider.of<Client>(context, listen: false);
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshDevices() async {
    try {
      setState(() => _error = null);
      await client.sync();
      setState(() {});
    } catch (e) {
      setState(() {
        _error = 'Failed to load devices: $e';
      });
    }
  }

  Future<void> _verifyDevice(DeviceKeys device) async {
    try {
      await device.setVerified(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device marked as verified')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
      }
    }
  }

  Future<void> _blockDevice(DeviceKeys device) async {
    try {
      await device.setBlocked(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device has been blocked')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to block device: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildDeviceList();
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: _refreshDevices,
      child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.devices_rounded,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No devices found',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: _refreshDevices,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userID = client.userID;
    if (userID == null) {
      return Center(
        child: Text(
          'Not logged in',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Get device keys for the current user
    final deviceKeysList = client.userDeviceKeys[userID];
    if (deviceKeysList == null) {
      return _buildEmptyState();
    }

    final devices = deviceKeysList.deviceKeys.values.toList();

    if (devices.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshDevices,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Device Security', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${devices.length} device${devices.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        size: 20,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ...devices.map((device) => _buildDeviceCard(device)),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DeviceKeys device) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = device.verificationStatus;
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
                      Text(
                        device.deviceDisplayName ?? 'Unknown Device',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device.deviceId ?? 'Unknown ID',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 14),
            Row(
              children: [
                if (status == DeviceVerificationStatus.unverified) ...[
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _verifyDevice(device),
                      icon: const Icon(Icons.verified_user_rounded, size: 18),
                      label: const Text('Verify'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        status == DeviceVerificationStatus.blocked
                            ? null
                            : () => _blockDevice(device),
                    icon: const Icon(Icons.block_rounded, size: 18),
                    label: const Text('Block'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(
                        color:
                            status == DeviceVerificationStatus.blocked
                                ? colorScheme.outlineVariant
                                : colorScheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
      DeviceVerificationStatus.verified => 'Verified',
      DeviceVerificationStatus.unverified => 'Unverified',
      DeviceVerificationStatus.blocked => 'Blocked',
    };
  }
}
