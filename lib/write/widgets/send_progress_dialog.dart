import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Shows a non-dismissible loading dialog while a send/upload operation is in progress.
Future<void> showSendLoadingDialog(
  BuildContext context, {
  required String messageKey,
  List<String> args = const [],
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(messageKey.tr(args: args), textAlign: TextAlign.center),
          ],
        ),
      );
    },
  );
}

/// Shows a retry/cancel dialog when a send/upload fails.
/// Returns `true` if the user chose to cancel, `false` if they chose to retry.
Future<bool> showSendErrorDialog(
  BuildContext context, {
  required String errorMessageKey,
  List<String> errorArgs = const [],
  String retryKey = 'write.send_retry',
  String cancelKey = 'write.send_cancel',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            icon: Icon(
              Icons.error_outline_rounded,
              color: Theme.of(ctx).colorScheme.error,
              size: 32,
            ),
            title: Text('write.send_error_title'.tr()),
            content: Text(
              errorMessageKey.tr(args: errorArgs),
              textAlign: TextAlign.center,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(cancelKey.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(retryKey.tr()),
              ),
            ],
          );
        },
      ) ??
      false;
}
