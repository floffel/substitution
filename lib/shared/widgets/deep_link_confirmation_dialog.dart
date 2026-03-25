import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// The type of deep link target for the confirmation dialog.
enum DeepLinkType { room, user, post, generic }

/// Shows a confirmation dialog before navigating to a deep link target.
///
/// Returns `true` if the user confirmed, `false` if dismissed.
Future<bool> showDeepLinkConfirmation(
  BuildContext context, {
  required DeepLinkType type,
  String? identifier,
}) async {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  String message;
  IconData icon;

  switch (type) {
    case DeepLinkType.room:
      message = 'deep_link.confirm.room'.tr(args: [identifier ?? '']);
      icon = Icons.forum_rounded;
    case DeepLinkType.user:
      message = 'deep_link.confirm.user'.tr(args: [identifier ?? '']);
      icon = Icons.person_rounded;
    case DeepLinkType.post:
      message = 'deep_link.confirm.post'.tr();
      icon = Icons.article_rounded;
    case DeepLinkType.generic:
      message = 'deep_link.confirm.generic'.tr(args: [identifier ?? '']);
      icon = Icons.link_rounded;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: colorScheme.primary),
        ),
        title: Text('deep_link.confirm.title'.tr()),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('deep_link.confirm.cancel_button'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('deep_link.confirm.continue_button'.tr()),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

/// Shows a dialog informing the user they need to log in to open the link.
///
/// Returns `true` if the user wants to log in, `false` otherwise.
Future<bool> showDeepLinkLoginRequired(BuildContext context) async {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 28,
            color: colorScheme.error,
          ),
        ),
        title: Text('deep_link.confirm.title'.tr()),
        content: Text(
          'deep_link.confirm.login_required'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('deep_link.confirm.cancel_button'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('deep_link.confirm.login_button'.tr()),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
