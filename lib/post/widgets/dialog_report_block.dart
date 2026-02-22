import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '/post/interfaces/i_event.dart';

class DialogReportBlock extends StatefulWidget {
  final Event event;
  final Event displayEvent;

  const DialogReportBlock({
    super.key,
    required this.event,
    required this.displayEvent,
  });

  @override
  State<DialogReportBlock> createState() => _DialogReportBlockState();
}

class _DialogReportBlockState extends State<DialogReportBlock> {
  final TextEditingController _reasonController = TextEditingController();
  bool _blockUser = false;
  bool _isSubmitting = false;

  Client get client => Provider.of<Client>(context, listen: false);

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final reason = _reasonController.text.trim();
      
      // If a reason is provided, report the content
      if (reason.isNotEmpty) {
        final roomId = widget.event.roomId;
        if (roomId != null) {
          await client.reportEvent(
            roomId,
            widget.event.eventId,
            reason: reason,
          );
        }
      }

      // If the user checked the block box, ignore the user
      if (_blockUser) {
        await client.ignoreUser(widget.displayEvent.senderId);
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('post.dialog.report_block_success').tr()),
      );
      
      context.pop(); // Close dialog
      
      // If we blocked the user, we should probably go back to home feed so it forces a refresh of what we see
      if (_blockUser) {
         context.go('/');
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('post.dialog.report_block_error').tr(args: [e.toString()])),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('post.dialog.report_block_title').tr(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('post.dialog.report_desc').tr(),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'post.dialog.report_reason'.tr(),
                hintText: 'post.dialog.report_reason_hint'.tr(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Divider(),
            CheckboxListTile(
              title: const Text('post.dialog.block_user_checkbox').tr(),
              subtitle: const Text('post.dialog.block_user_desc').tr(args: [widget.displayEvent.senderId]),
              value: _blockUser,
              onChanged: (bool? value) {
                setState(() {
                  _blockUser = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => context.pop(),
          child: const Text('post.dialog.cancel').tr(),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('post.dialog.submit').tr(),
        ),
      ],
    );
  }
}
