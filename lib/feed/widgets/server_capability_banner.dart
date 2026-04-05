import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/shared/services/matrix_server_capabilities.dart';

/// A small advisory banner shown on the feed when the user's homeserver
/// does not support the optimised pagination path (Matrix v1.6+).
///
/// Long-pressing the banner opens a dialog with details. The banner never
/// blocks the user; it's informational only because the feed still works
/// (via fallback to `requestHistory`), just less efficiently.
class ServerCapabilityBanner extends StatelessWidget {
  const ServerCapabilityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final caps = context.watch<MatrixServerCapabilities>();
    // Only show when loaded AND the requirement is not met.
    if (!caps.isLoaded || caps.supportsTimestampToEvent) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onLongPress: () => _showInfoDialog(context),
      onTap: () => _showInfoDialog(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'feed.pages.home.server_warning_badge'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('feed.pages.home.server_warning_title'.tr()),
            content: Text('feed.pages.home.server_warning_body'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('approve'.tr()),
              ),
            ],
          ),
    );
  }
}
