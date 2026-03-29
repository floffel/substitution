import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

/// Confirmation dialog for deleting (redacting) a post or comment.
class DialogDeletePost extends StatefulWidget {
  final Event event;

  const DialogDeletePost({super.key, required this.event});

  @override
  State<DialogDeletePost> createState() => _DialogDeletePostState();
}

class _DialogDeletePostState extends State<DialogDeletePost> {
  bool _isDeleting = false;

  Future<void> _delete() async {
    setState(() => _isDeleting = true);
    try {
      await widget.event.redactEvent();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: const Text('post.delete.success').tr()));
      context.pop(); // close dialog
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('post.delete.error').tr(args: [e.toString()]),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(
        Icons.delete_outline_rounded,
        color: colorScheme.error,
        size: 32,
      ),
      title: const Text('post.delete.title').tr(),
      content: const Text('post.delete.body').tr(),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => context.pop(),
          child: const Text('post.delete.cancel').tr(),
        ),
        FilledButton(
          onPressed: _isDeleting ? null : _delete,
          style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
          child:
              _isDeleting
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onError,
                    ),
                  )
                  : const Text('post.delete.confirm').tr(),
        ),
      ],
    );
  }
}
