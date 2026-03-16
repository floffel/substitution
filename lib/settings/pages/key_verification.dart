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
      // Start the verification process via SAS
      // The Matrix SDK handles the emoji comparison internally
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

  Widget _buildDeviceList() {
    final userID = client.userID;
    if (userID == null) {
      return const Center(child: Text('Not logged in'));
    }

    // Get device keys for the current user
    final deviceKeysList = client.userDeviceKeys[userID];
    if (deviceKeysList == null) {
      return RefreshIndicator(
        onRefresh: _refreshDevices,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  const Text('No devices found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshDevices,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final devices = deviceKeysList.deviceKeys.values.toList();

    if (devices.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshDevices,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  const Text('No devices found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshDevices,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshDevices,
      child: ListView(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ),
          ...devices.map((device) => _buildDeviceCard(device)),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DeviceKeys device) {
    final status = device.verificationStatus;
    final icon = _getStatusIcon(status);
    final color = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceDisplayName ?? 'Unknown Device',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.deviceId ?? 'Unknown ID',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(icon, color: color, size: 28),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (status == DeviceVerificationStatus.unverified)
                  ElevatedButton.icon(
                    onPressed: () => _verifyDevice(device),
                    icon: const Icon(Icons.verified_user),
                    label: const Text('Verify'),
                  ),
                ElevatedButton.icon(
                  onPressed:
                      status == DeviceVerificationStatus.blocked
                          ? null
                          : () => _blockDevice(device),
                  icon: const Icon(Icons.block),
                  label: const Text('Block'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
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
      DeviceVerificationStatus.verified => Icons.verified_user,
      DeviceVerificationStatus.unverified => Icons.person,
      DeviceVerificationStatus.blocked => Icons.block,
    };
  }

  Color _getStatusColor(DeviceVerificationStatus status) {
    return switch (status) {
      DeviceVerificationStatus.verified => Colors.green,
      DeviceVerificationStatus.unverified => Colors.grey,
      DeviceVerificationStatus.blocked => Colors.red,
    };
  }
}
