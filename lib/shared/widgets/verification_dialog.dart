import 'dart:async';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/encryption.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:substitution/shared/widgets/recovery_key_dialog.dart';

/// A dialog that guides the user through the interactive SAS emoji/number
/// verification flow for a Matrix device or user.
class VerificationDialog extends StatefulWidget {
  final KeyVerification request;

  const VerificationDialog({super.key, required this.request});

  /// Show the verification dialog for an existing request (incoming).
  static Future<void> show(
    BuildContext context, {
    required KeyVerification request,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VerificationDialog(request: request),
    );
  }

  /// Start a new verification with a device and show the dialog.
  static Future<void> startAndShow(
    BuildContext context, {
    required DeviceKeys deviceKeys,
  }) async {
    final request = await deviceKeys.startVerification();
    if (!context.mounted) return;
    return show(context, request: request);
  }

  @override
  State<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<VerificationDialog> {
  KeyVerification get request => widget.request;

  @override
  void initState() {
    super.initState();
    request.onUpdate = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    request.onUpdate = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: _buildTitle(theme, colorScheme),
      content: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: _buildContent(theme, colorScheme),
      ),
      actions: _buildActions(theme, colorScheme),
    );
  }

  Widget _buildTitle(ThemeData theme, ColorScheme colorScheme) {
    final icon = switch (request.state) {
      KeyVerificationState.done => Icons.verified_rounded,
      KeyVerificationState.error => Icons.error_outline_rounded,
      _ => Icons.shield_outlined,
    };
    final color = switch (request.state) {
      KeyVerificationState.done => colorScheme.primary,
      KeyVerificationState.error => colorScheme.error,
      _ => colorScheme.onSurface,
    };

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _titleText,
            style: theme.textTheme.titleLarge?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  String get _titleText => switch (request.state) {
    KeyVerificationState.askAccept =>
      'settings.security.verification.incoming_title'.tr(),
    KeyVerificationState.askChoice =>
      'settings.security.verification.choose_method'.tr(),
    KeyVerificationState.waitingAccept =>
      'settings.security.verification.waiting'.tr(),
    KeyVerificationState.askSas =>
      'settings.security.verification.compare_title'.tr(),
    KeyVerificationState.waitingSas =>
      'settings.security.verification.waiting'.tr(),
    KeyVerificationState.askSSSS =>
      'settings.security.verification.unlock_title'.tr(),
    KeyVerificationState.done =>
      'settings.security.verification.done_title'.tr(),
    KeyVerificationState.error =>
      'settings.security.verification.error_title'.tr(),
    _ => 'settings.security.verification.title'.tr(),
  };

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    return switch (request.state) {
      KeyVerificationState.askAccept => _buildAskAccept(theme, colorScheme),
      KeyVerificationState.askChoice => _buildAskChoice(theme, colorScheme),
      KeyVerificationState.waitingAccept ||
      KeyVerificationState.waitingSas => _buildWaiting(theme, colorScheme),
      KeyVerificationState.askSas => _buildAskSas(theme, colorScheme),
      KeyVerificationState.askSSSS => _buildAskSSSS(theme, colorScheme),
      KeyVerificationState.done => _buildDone(theme, colorScheme),
      KeyVerificationState.error => _buildError(theme, colorScheme),
      _ => _buildWaiting(theme, colorScheme),
    };
  }

  Widget _buildAskAccept(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.notifications_active_rounded,
          size: 48,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'settings.security.verification.incoming_desc'.tr(
            args: [request.userId],
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildAskChoice(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'settings.security.verification.choose_desc'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (request.possibleMethods.contains(EventTypes.Sas))
          ListTile(
            leading: const Icon(Icons.tag_faces_rounded),
            title: Text('settings.security.verification.emoji_method'.tr()),
            subtitle: Text(
              'settings.security.verification.emoji_method_desc'.tr(),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            onTap: () => request.continueVerification(EventTypes.Sas),
          ),
      ],
    );
  }

  Widget _buildWaiting(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'settings.security.verification.waiting_desc'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAskSas(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'settings.security.verification.compare_desc'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (request.sasTypes.contains('emoji')) ...[
          _buildEmojiGrid(theme, colorScheme),
        ] else if (request.sasTypes.contains('decimal')) ...[
          _buildNumberComparison(theme, colorScheme),
        ],
        const SizedBox(height: 16),
        Text(
          'settings.security.verification.compare_check'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiGrid(ThemeData theme, ColorScheme colorScheme) {
    final emojis = request.sasEmojis;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 12,
        children:
            emojis.map((emoji) {
              return SizedBox(
                width: 72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji.emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 4),
                    Text(
                      emoji.name,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildNumberComparison(ThemeData theme, ColorScheme colorScheme) {
    final numbers = request.sasNumbers;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        numbers.join('  '),
        style: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: 4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAskSSSS(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.key_rounded, size: 48, color: colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'settings.security.verification.ssss_desc'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDone(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_rounded, size: 64, color: colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'settings.security.verification.done_desc'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildError(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, size: 64, color: colorScheme.error),
        const SizedBox(height: 16),
        Text(
          request.canceledReason ??
              'settings.security.verification.error_desc'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error),
        ),
      ],
    );
  }

  List<Widget> _buildActions(ThemeData theme, ColorScheme colorScheme) {
    return switch (request.state) {
      KeyVerificationState.askAccept => [
        TextButton(
          onPressed: () {
            request.rejectVerification();
            Navigator.of(context).pop();
          },
          child: Text('settings.security.verification.reject'.tr()),
        ),
        FilledButton(
          onPressed: () => request.acceptVerification(),
          child: Text('settings.security.verification.accept'.tr()),
        ),
      ],
      KeyVerificationState.askSas => [
        TextButton(
          onPressed: () {
            request.rejectSas();
            Navigator.of(context).pop();
          },
          child: Text(
            'settings.security.verification.no_match'.tr(),
            style: TextStyle(color: colorScheme.error),
          ),
        ),
        FilledButton(
          onPressed: () => request.acceptSas(),
          child: Text('settings.security.verification.match'.tr()),
        ),
      ],
      KeyVerificationState.askSSSS => [
        TextButton(
          onPressed: () {
            request.openSSSS(skip: true);
          },
          child: Text('settings.security.verification.skip'.tr()),
        ),
        FilledButton(
          onPressed: () async {
            final key = await RecoveryKeyDialog.showInputDialog(context);
            if (key != null) {
              await request.openSSSS(keyOrPassphrase: key);
            }
          },
          child: Text('settings.security.verification.enter_key'.tr()),
        ),
      ],
      KeyVerificationState.done => [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('settings.security.verification.close'.tr()),
        ),
      ],
      KeyVerificationState.error => [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('settings.security.verification.close'.tr()),
        ),
      ],
      KeyVerificationState.waitingAccept || KeyVerificationState.waitingSas => [
        TextButton(
          onPressed: () {
            request.cancel();
            Navigator.of(context).pop();
          },
          child: Text('cancel'.tr()),
        ),
      ],
      _ => [
        TextButton(
          onPressed: () {
            request.cancel();
            Navigator.of(context).pop();
          },
          child: Text('cancel'.tr()),
        ),
      ],
    };
  }
}
