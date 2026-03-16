import '/post/interfaces/i_event.dart';
import '/post/widgets/post.dart';
import '/post/widgets/comment.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class PostPage extends IEventWidget {
  const PostPage({
    super.key,
    required super.event,
    required super.displayEvent,
  });

  @override
  PostPageState createState() => PostPageState();
}

class PostPageState extends State<PostPage> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  /// The event being replied to. Null means replying to the main post.
  Event? _replyTargetEvent;

  /// Display name of the user being replied to (for the indicator chip).
  String? _replyTargetUsername;

  bool _isSending = false;

  Client get client => Provider.of<Client>(context, listen: false);
  Room? get room =>
      widget.event.roomId != null
          ? client.getRoomById(widget.event.roomId!)
          : null;

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  /// Called when user taps reply on a comment — sets the reply target and focuses the input.
  void _onCommentReply(Event event, String username) {
    setState(() {
      _replyTargetEvent = event;
      _replyTargetUsername = username;
    });
    _replyFocusNode.requestFocus();
  }

  /// Clears the reply target back to the main post.
  void _clearReplyTarget() {
    setState(() {
      _replyTargetEvent = null;
      _replyTargetUsername = null;
    });
  }

  /// Sends the reply as a plain text message with thread/reply semantics.
  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || room == null) return;

    setState(() => _isSending = true);

    try {
      // Determine the event we are replying to
      final Event replyToEvent = _replyTargetEvent ?? widget.event;

      // Determine thread root: if the reply target is itself a thread reply, reuse the existing thread root
      String? threadRootEventId = widget.event.eventId;
      if (replyToEvent.relationshipType == RelationshipTypes.thread) {
        threadRootEventId = replyToEvent.relationshipEventId;
      }

      final result = await room!.sendEvent(
        {'body': text, 'msgtype': MessageTypes.Text},
        threadRootEventId: threadRootEventId,
        inReplyTo: replyToEvent,
      );

      if (result != null && mounted) {
        _replyController.clear();
        _clearReplyTarget();
        // Refresh comments
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('write.textmessage.send_complete').tr(),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('write.textmessage.send_failed').tr()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // --- Scrollable content area ---
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              return Future<void>.delayed(const Duration(seconds: 1));
            },
            child: FutureBuilder(
              future: widget.comments,
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      PostWidget(
                        event: widget.event,
                        displayEvent: widget.displayEvent,
                        isDetailView: true,
                      ),

                      // --- Comments section header ---
                      if (snapshot.data != null && snapshot.data!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16.0,
                            8.0,
                            16.0,
                            4.0,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${snapshot.data!.length}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                snapshot.data!.length == 1
                                    ? 'comment'
                                    : 'comments',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const Divider(height: 1),

                      // --- Comments list ---
                      if (snapshot.data == null || snapshot.data!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'post.pages.post.no_comments'.tr(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ...snapshot.data!.map((e) {
                          return Column(
                            children: [
                              CommentWidget(
                                event: e.origEvent,
                                displayEvent: e.displayEvent,
                                postEvent: widget.event,
                                onReply: _onCommentReply,
                              ),
                              Divider(
                                height: 1,
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ],
                          );
                        }),

                      // Bottom padding so content is not hidden behind reply bar
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // --- Inline reply bar ---
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- "Replying to @user" indicator ---
                if (_replyTargetEvent != null && _replyTargetUsername != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 8.0, 0),
                    child: Row(
                      children: [
                        Icon(Icons.reply, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'post.replying_to'.tr(
                              args: [_replyTargetUsername!],
                            ),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: _clearReplyTarget,
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- Input row ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Attach / Upload image button
                      IconButton(
                        onPressed: () {
                          final targetEventId =
                              _replyTargetEvent?.eventId ??
                              widget.event.eventId;
                          context.push(
                            Uri(
                              path: "/file/${widget.event.roomId}",
                              queryParameters: {'event': targetEventId},
                            ).toString(),
                          );
                        },
                        icon: Icon(
                          Icons.image_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Attach image',
                      ),
                      // Text input
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          focusNode: _replyFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'post.reply_placeholder'.tr(),
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 10.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24.0),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24.0),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24.0),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Send button
                      IconButton(
                        onPressed: _isSending ? null : _sendReply,
                        icon:
                            _isSending
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                                : Icon(Icons.send, color: colorScheme.primary),
                        tooltip: 'Send',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
