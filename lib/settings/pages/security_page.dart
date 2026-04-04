import 'dart:async';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/encryption.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '/settings/widgets/security/device_card.dart';
import '/settings/widgets/security/cross_signing_banner.dart';
import '/settings/widgets/security/key_backup_section.dart';
import '/shared/widgets/verification_dialog.dart';
import '/shared/widgets/uia_dialog.dart';

/// The main security settings page showing device list, cross-signing status,
/// key backup status, and session management.
class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  Client get client => Provider.of<Client>(context, listen: false);

  String? _error;
  bool _isLoading = true;
  List<Device>? _apiDevices;

  // Cross-signing state
  bool _csInitialized = false;
  bool _csConnected = false;
  // ignore: prefer_final_fields
  bool _csLoading = false;

  // Key backup state
  bool _backupEnabled = false;
  bool _backupCached = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch device keys and API devices in parallel
      await Future.wait([
        _loadDeviceKeys(),
        _loadApiDevices(),
        _loadCryptoState(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'settings.security.error_loading'.tr(args: ['$e']),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDeviceKeys() async {
    try {
      await client.updateUserDeviceKeys();
    } catch (e) {
      debugPrint('Failed to update device keys: $e');
    }
  }

  Future<void> _loadApiDevices() async {
    try {
      _apiDevices = await client.getDevices();
    } catch (e) {
      debugPrint('Failed to load API devices: $e');
    }
  }

  Future<void> _loadCryptoState() async {
    try {
      final state = await client.getCryptoIdentityState();
      _csInitialized = state.initialized;
      _csConnected = state.connected;

      _backupEnabled = client.encryption?.keyManager.enabled ?? false;
      _backupCached = (await client.encryption?.keyManager.isCached()) ?? false;
    } catch (e) {
      debugPrint('Failed to load crypto state: $e');
    }
  }

  List<DeviceData> _buildDeviceList() {
    final userID = client.userID;
    if (userID == null) return [];

    final deviceKeysList = client.userDeviceKeys[userID];
    if (deviceKeysList == null) return [];

    final devices = deviceKeysList.deviceKeys.values.toList();
    final apiMap = <String, Device>{};
    if (_apiDevices != null) {
      for (final d in _apiDevices!) {
        apiMap[d.deviceId] = d;
      }
    }

    return devices.map((keys) {
        return DeviceData(
          keys: keys,
          apiDevice: keys.deviceId != null ? apiMap[keys.deviceId!] : null,
        );
      }).toList()
      // Sort: current device first, then by verification status, then by name
      ..sort((a, b) {
        final aIsCurrent = a.keys.deviceId == client.deviceID;
        final bIsCurrent = b.keys.deviceId == client.deviceID;
        if (aIsCurrent && !bIsCurrent) return -1;
        if (!aIsCurrent && bIsCurrent) return 1;
        final aStatus = a.keys.verificationStatus.index;
        final bStatus = b.keys.verificationStatus.index;
        if (aStatus != bStatus) return aStatus.compareTo(bStatus);
        return a.displayName.compareTo(b.displayName);
      });
  }

  Future<void> _verifyDevice(DeviceKeys device) async {
    try {
      await VerificationDialog.startAndShow(context, deviceKeys: device);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'settings.security.devices.verify_error'.tr(args: ['$e']),
            ),
          ),
        );
      }
    }
  }

  Future<void> _blockDevice(DeviceKeys device) async {
    try {
      await device.setBlocked(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings.security.devices.blocked_msg'.tr())),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'settings.security.devices.block_error'.tr(args: ['$e']),
            ),
          ),
        );
      }
    }
  }

  Future<void> _unblockDevice(DeviceKeys device) async {
    try {
      await device.setBlocked(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.security.devices.unblocked_msg'.tr()),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'settings.security.devices.unblock_error'.tr(args: ['$e']),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteDevice(String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('settings.security.session.delete_title'.tr()),
            content: Text(
              'settings.security.session.delete_confirm'.tr(args: [deviceId]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text('settings.security.session.delete_button'.tr()),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // First attempt without auth (will likely fail with UIA)
      await client.deleteDevice(deviceId);
    } on MatrixException catch (e) {
      if (e.requireAdditionalAuthentication && mounted) {
        final authData = await UiaDialog.show(
          context,
          title: 'settings.security.session.delete_title'.tr(),
          description: 'settings.security.session.delete_auth_desc'.tr(),
        );
        if (authData != null) {
          try {
            await client.deleteDevice(deviceId, auth: authData);
          } catch (e2) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'settings.security.session.delete_error'.tr(args: ['$e2']),
                  ),
                ),
              );
            }
            return;
          }
        } else {
          return;
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'settings.security.session.delete_error'.tr(args: ['$e']),
              ),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'settings.security.session.delete_error'.tr(args: ['$e']),
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.security.session.deleted_msg'.tr())),
      );
      _loadData();
    }
  }

  Future<void> _renameDevice(String deviceId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('settings.security.session.rename_title'.tr()),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'settings.security.session.rename_label'.tr(),
              ),
              onSubmitted: (value) => Navigator.pop(ctx, value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: Text('settings.security.session.rename_button'.tr()),
              ),
            ],
          ),
    );

    controller.dispose();
    if (newName == null || newName.isEmpty || !mounted) return;

    try {
      await client.updateDevice(deviceId, displayName: newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings.security.session.renamed_msg'.tr())),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'settings.security.session.rename_error'.tr(args: ['$e']),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!client.isLogged()) {
      return Center(
        child: Text(
          'settings.security.not_logged_in'.tr(),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final devices = _buildDeviceList();

    if (_isLoading && devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (devices.isEmpty && !_isLoading) {
      return _buildEmptyState(theme, colorScheme);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Header
          _buildHeader(theme, colorScheme, devices.length),

          // Error banner
          if (_error != null) _buildErrorBanner(theme, colorScheme),

          // Cross-signing status
          CrossSigningBanner(
            client: client,
            initialized: _csInitialized,
            connected: _csConnected,
            isLoading: _csLoading,
            onSetupComplete: () {
              _loadData();
            },
          ),

          // Key backup status
          KeyBackupSection(
            client: client,
            backupEnabled: _backupEnabled,
            backupCached: _backupCached,
          ),

          const SizedBox(height: 8),

          // Section label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
            child: Text(
              'settings.security.devices.section_title'.tr().toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),

          // Device cards
          ...devices.map((device) {
            final isCurrentDevice = device.keys.deviceId == client.deviceID;
            return DeviceCard(
              device: device,
              isCurrentDevice: isCurrentDevice,
              onVerify: () => _verifyDevice(device.keys),
              onBlock: () => _blockDevice(device.keys),
              onUnblock: () => _unblockDevice(device.keys),
              onDelete:
                  !isCurrentDevice && device.keys.deviceId != null
                      ? () => _deleteDevice(device.keys.deviceId!)
                      : null,
              onRename:
                  device.keys.deviceId != null
                      ? () => _renameDevice(
                        device.keys.deviceId!,
                        device.displayName,
                      )
                      : null,
            );
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
          Text(
            'settings.security.title'.tr(),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'settings.security.device_count'.tr(args: ['$count']),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
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
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadData,
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
            'settings.security.devices.empty'.tr(),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'settings.security.devices.pull_refresh'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('settings.security.devices.refresh'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
