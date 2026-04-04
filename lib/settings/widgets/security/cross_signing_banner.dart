import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/encryption.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:substitution/shared/widgets/recovery_key_dialog.dart';

/// Banner widget that shows the cross-signing status and provides
/// setup / restore actions.
class CrossSigningBanner extends StatelessWidget {
  final Client client;
  final bool initialized;
  final bool connected;
  final bool isLoading;
  final VoidCallback? onSetupComplete;

  const CrossSigningBanner({
    super.key,
    required this.client,
    required this.initialized,
    required this.connected,
    this.isLoading = false,
    this.onSetupComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (connected) return _buildConnectedBanner(context);
    if (initialized) return _buildRestoreBanner(context);
    return _buildSetupBanner(context);
  }

  Widget _buildConnectedBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.security.cross_signing.connected_title'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'settings.security.cross_signing.connected_desc'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.key_rounded,
                    color: colorScheme.tertiary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'settings.security.cross_signing.restore_title'.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'settings.security.cross_signing.restore_desc'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: () => _restoreCryptoIdentity(context),
                    icon: const Icon(Icons.key_rounded, size: 18),
                    label: Text(
                      'settings.security.cross_signing.restore_button'.tr(),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: colorScheme.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'settings.security.cross_signing.setup_title'.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'settings.security.cross_signing.setup_desc'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _initCryptoIdentity(context),
                    icon: const Icon(Icons.shield_rounded, size: 18),
                    label: Text(
                      'settings.security.cross_signing.setup_button'.tr(),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initCryptoIdentity(BuildContext context) async {
    try {
      final recoveryKey = await client.initCryptoIdentity();
      if (!context.mounted) return;
      await RecoveryKeyDialog.showSaveDialog(context, recoveryKey: recoveryKey);
      onSetupComplete?.call();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.security.cross_signing.setup_error'.tr(args: ['$e']),
          ),
        ),
      );
    }
  }

  Future<void> _restoreCryptoIdentity(BuildContext context) async {
    final keyOrPassphrase = await RecoveryKeyDialog.showInputDialog(context);
    if (keyOrPassphrase == null || !context.mounted) return;

    try {
      await client.restoreCryptoIdentity(keyOrPassphrase);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.security.cross_signing.restore_success'.tr()),
        ),
      );
      onSetupComplete?.call();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.security.cross_signing.restore_error'.tr(args: ['$e']),
          ),
        ),
      );
    }
  }
}
