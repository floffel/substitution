import '/post/widgets/post.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

/// Shows a "replying to" preview card for the given event.
/// Used on write/compose pages when the user is replying to an existing post.
class ReplyPreviewWidget extends StatelessWidget {
  const ReplyPreviewWidget({super.key, required this.future});

  final Future<({Event event, Event displayEvent})?> future;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Row(
            children: [
              Icon(Icons.reply_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'write.answer'.tr(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: colorScheme.surfaceContainerHighest,
          child: FutureBuilder<({Event event, Event displayEvent})?>(
            future: future,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'write.reply_load_error'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (snapshot.data != null) {
                return PostWidget(
                  event: snapshot.data!.event,
                  displayEvent: snapshot.data!.displayEvent,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}
