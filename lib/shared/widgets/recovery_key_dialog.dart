import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

/// Dialog to display or input a recovery key.
class RecoveryKeyDialog extends StatefulWidget {
  /// If non-null, the dialog displays this key for the user to save.
  /// If null, the dialog prompts the user to enter their key.
  final String? recoveryKey;

  const RecoveryKeyDialog({super.key, this.recoveryKey});

  /// Show the dialog to display a newly generated recovery key.
  /// Returns true if the user acknowledges they saved it.
  static Future<bool?> showSaveDialog(
    BuildContext context, {
    required String recoveryKey,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecoveryKeyDialog(recoveryKey: recoveryKey),
    );
  }

  /// Show the dialog to enter a recovery key / passphrase.
  /// Returns the entered string, or null if cancelled.
  static Future<String?> showInputDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const RecoveryKeyDialog(),
    );
  }

  @override
  State<RecoveryKeyDialog> createState() => _RecoveryKeyDialogState();
}

class _RecoveryKeyDialogState extends State<RecoveryKeyDialog> {
  final _inputController = TextEditingController();
  bool _copied = false;

  bool get _isDisplayMode => widget.recoveryKey != null;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isDisplayMode) {
      return _buildSaveDialog(theme, colorScheme);
    }
    return _buildInputDialog(theme, colorScheme);
  }

  Widget _buildSaveDialog(ThemeData theme, ColorScheme colorScheme) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.key_rounded, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('settings.security.recovery.save_title'.tr())),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.security.recovery.save_desc'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: SelectableText(
              widget.recoveryKey!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.recoveryKey!));
                setState(() => _copied = true);
              },
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 18,
              ),
              label: Text(
                _copied
                    ? 'settings.security.recovery.copied'.tr()
                    : 'settings.security.recovery.copy'.tr(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'settings.security.recovery.warning'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('settings.security.recovery.saved'.tr()),
        ),
      ],
    );
  }

  Widget _buildInputDialog(ThemeData theme, ColorScheme colorScheme) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.key_rounded, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('settings.security.recovery.enter_title'.tr())),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.security.recovery.enter_desc'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inputController,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'settings.security.recovery.input_label'.tr(),
              hintText: 'settings.security.recovery.input_hint'.tr(),
            ),
            onSubmitted: (_) {
              if (_inputController.text.isNotEmpty) {
                Navigator.of(context).pop(_inputController.text);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: () {
            if (_inputController.text.isNotEmpty) {
              Navigator.of(context).pop(_inputController.text);
            }
          },
          child: Text('settings.security.recovery.restore'.tr()),
        ),
      ],
    );
  }
}
