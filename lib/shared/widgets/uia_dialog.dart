import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

/// A dialog that prompts the user to re-enter their password for
/// User Interactive Authentication (UIA) flows.
class UiaDialog extends StatefulWidget {
  final String title;
  final String? description;

  const UiaDialog({super.key, required this.title, this.description});

  /// Show the UIA dialog and return the [AuthenticationData] if confirmed,
  /// or null if cancelled.
  static Future<AuthenticationPassword?> show(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    return showDialog<AuthenticationPassword>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UiaDialog(title: title, description: description),
    );
  }

  @override
  State<UiaDialog> createState() => _UiaDialogState();
}

class _UiaDialogState extends State<UiaDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    if (password.isEmpty) return;

    final client = Provider.of<Client>(context, listen: false);
    final authData = AuthenticationPassword(
      password: password,
      identifier: AuthenticationUserIdentifier(user: client.userID!),
    );
    Navigator.of(context).pop(authData);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.description != null) ...[
            Text(
              widget.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'settings.security.uia.enter_password'.tr(),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'settings.security.uia.password_label'.tr(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed:
                    () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text('settings.security.uia.confirm'.tr()),
        ),
      ],
    );
  }
}
