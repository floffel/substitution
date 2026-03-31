import '/write/widgets/send_progress_dialog.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

/// Mixin that provides the shared send-with-retry loop used across all write
/// pages (text, emote, sticker, voice, file).
///
/// Usage:
/// ```dart
/// class _MyWriteState extends State<MyWrite> with SendWithRetry {
///   Future<void> _send() async {
///     await sendWithRetry(
///       context: context,
///       room: room!,
///       send: () => room!.sendEvent({...}),
///       loadingMessageKey: 'write.textmessage.send_start',
///       errorMessageKey: 'write.textmessage.send_failed',
///       successMessageKey: 'write.textmessage.send_complete',
///       threadRootEventId: eventThreadId,
///     );
///   }
/// }
/// ```
mixin SendWithRetry<T extends StatefulWidget> on State<T> {
  /// Runs [send] in a retry loop, showing loading / error dialogs until the
  /// operation succeeds or the user cancels.
  ///
  /// On success, navigates to the post page for [threadRootEventId] (if given)
  /// or to the room feed (if [roomId] is given), or to home.
  ///
  /// Returns `true` if the send succeeded, `false` if the user cancelled.
  Future<bool> sendWithRetry({
    required BuildContext context,
    required Future<String?> Function() send,
    required String loadingMessageKey,
    required String errorMessageKey,
    required String successMessageKey,
    List<String> loadingArgs = const [],
    List<String> errorArgs = const [],
    String? threadRootEventId,
    String? roomId,
    Room? room,
    Client? client,
  }) async {
    // Capture context objects before entering the async retry loop.
    // ignore: use_build_context_synchronously
    final scavMsg = ScaffoldMessenger.of(context);
    // ignore: use_build_context_synchronously
    final navigator = Navigator.of(context);
    // ignore: use_build_context_synchronously
    final goRouter = GoRouter.of(context);

    String? ret;
    bool userCancel = false;

    while (ret == null && !userCancel) {
      if (!mounted) return false;

      showSendLoadingDialog(
        // ignore: use_build_context_synchronously
        context,
        messageKey: loadingMessageKey,
        args: loadingArgs,
      );

      try {
        ret = await send();
      } catch (e) {
        debugPrint('SendWithRetry: error during send: $e');
        // ret stays null so the error dialog below is shown
      }

      navigator.pop(); // pop the loading dialog

      if (ret == null) {
        if (!mounted) break;
        userCancel = await showSendErrorDialog(
          // ignore: use_build_context_synchronously
          context,
          errorMessageKey: errorMessageKey,
          errorArgs: errorArgs,
        );
      } else {
        if (mounted) {
          scavMsg.showSnackBar(SnackBar(content: Text(successMessageKey)));
        }
      }
    }

    if (!userCancel && ret != null) {
      if (!mounted) return true;
      if (threadRootEventId != null && client != null && room != null) {
        final answerEvent = Event.fromMatrixEvent(
          await client.getOneRoomEvent(room.id, threadRootEventId),
          room,
        );
        goRouter.go('/room/${answerEvent.room.id}/${answerEvent.eventId}');
      } else if (room != null) {
        goRouter.go('/feed/${room.id}');
      } else {
        goRouter.go('/');
      }
      return true;
    }

    return false;
  }
}
