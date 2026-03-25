import '/post/interfaces/i_event.dart';
import '/post/widgets/post.dart';
import '/post/widgets/comment.dart';
import '/shared/services/loading_service.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

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
  final quill.QuillController _quillController = quill.QuillController.basic();
  final FocusNode _replyFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  /// Whether the editor toolbar is visible (shown when editor is focused).
  bool _showToolbar = false;

  /// The event being replied to. Null means replying to the main post.
  Event? _replyTargetEvent;

  /// Display name of the user being replied to (for the indicator chip).
  String? _replyTargetUsername;

  bool _isSending = false;

  /// Cached comments future — wraps [widget.comments] with LoadingService signals.
  late Future<List<({Event origEvent, Event displayEvent})>> _commentsFuture;

  // Cache the LoadingService reference so it can be used safely in dispose()
  // without looking up a deactivated widget's ancestor via Provider.of(context).
  late final LoadingService _loadingService;

  Client get client => Provider.of<Client>(context, listen: false);
  Room? get room =>
      widget.event.roomId != null
          ? client.getRoomById(widget.event.roomId!)
          : null;

  Future<List<({Event origEvent, Event displayEvent})>> _loadComments() async {
    _loadingService.setLoading('post_comments');
    try {
      return await widget.comments;
    } finally {
      _loadingService.setDone('post_comments');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadingService = Provider.of<LoadingService>(context, listen: false);
    _commentsFuture = _loadComments();

    _replyFocusNode.addListener(() {
      final focused = _replyFocusNode.hasFocus;
      if (_showToolbar != focused) {
        setState(() => _showToolbar = focused);
      }
    });
  }

  @override
  void dispose() {
    _loadingService.setDone('post_comments');
    _quillController.dispose();
    _replyFocusNode.dispose();
    _editorScrollController.dispose();
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

  /// Returns true if the Quill document contains any non-whitespace content.
  bool get _hasContent {
    return _quillController.document.toPlainText().trim().isNotEmpty;
  }

  /// Sends the reply as a rich text message (HTML formatted_body) with thread/reply semantics.
  Future<void> _sendReply() async {
    if (!_hasContent || room == null) return;

    setState(() => _isSending = true);

    try {
      // Determine the event we are replying to
      final Event replyToEvent = _replyTargetEvent ?? widget.event;

      // Determine thread root: if the reply target is itself a thread reply, reuse the existing thread root
      String? threadRootEventId = widget.event.eventId;
      if (replyToEvent.relationshipType == RelationshipTypes.thread) {
        threadRootEventId = replyToEvent.relationshipEventId;
      }

      final plainText = _quillController.document.toPlainText().trim();

      final deltaJson = _quillController.document.toDelta().toJson();
      final converter = QuillDeltaToHtmlConverter(
        List.castFrom(deltaJson),
        ConverterOptions.forEmail(),
      );
      final html = converter.convert();

      final result = await room!.sendEvent(
        {
          'body': plainText,
          'format': 'org.matrix.custom.html',
          'formatted_body': html,
          'msgtype': MessageTypes.Text,
        },
        threadRootEventId: threadRootEventId,
        inReplyTo: replyToEvent,
      );

      if (result != null && mounted) {
        _quillController.clear();
        _clearReplyTarget();
        // Refresh comments — create a fresh future so the FutureBuilder re-runs
        setState(() {
          _commentsFuture = _loadComments();
        });
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
    // Replicate the padding that ScaffoldWithNavigation normally provides,
    // but only for the scrollable content — the reply bar spans full width.
    const contentPadding = EdgeInsets.symmetric(horizontal: 16.0);

    return SafeArea(
      // Handle top safe area (status bar) here since ScaffoldWithNavigation's
      // SafeArea is disabled via disableBodyPadding. The AppBar already covers
      // the status bar so top: false is correct.
      top: false,
      bottom: false,
      child: Column(
        children: [
          // --- Scrollable content area ---
          Expanded(
            child: Padding(
              padding: contentPadding,
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _commentsFuture = _loadComments();
                  });
                  return Future<void>.delayed(const Duration(seconds: 1));
                },
                child: FutureBuilder<
                  List<({Event origEvent, Event displayEvent})>
                >(
                  future: _commentsFuture,
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) {
                      // TopLoadingBar handles the loading indicator.
                      // Show the post immediately while comments load.
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: PostWidget(
                          event: widget.event,
                          displayEvent: widget.displayEvent,
                          isDetailView: true,
                        ),
                      );
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
                          if (snapshot.data != null &&
                              snapshot.data!.isNotEmpty)
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
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.3),
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
          ),

          // --- Inline reply bar (full-bleed, handles own bottom safe area) ---
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
                          Icon(
                            Icons.reply,
                            size: 16,
                            color: colorScheme.primary,
                          ),
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

                  // --- Compact formatting toolbar (shown when editor is focused) ---
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    child:
                        _showToolbar
                            ? Padding(
                              padding: const EdgeInsets.fromLTRB(
                                8.0,
                                6.0,
                                8.0,
                                0,
                              ),
                              child: quill.QuillSimpleToolbar(
                                controller: _quillController,
                                config: const quill.QuillSimpleToolbarConfig(
                                  multiRowsDisplay: false,
                                  showBoldButton: true,
                                  showItalicButton: true,
                                  showUnderLineButton: true,
                                  showAlignmentButtons: false,
                                  showBackgroundColorButton: false,
                                  showCenterAlignment: false,
                                  showClearFormat: false,
                                  showCodeBlock: false,
                                  showColorButton: false,
                                  showDirection: false,
                                  showDividers: false,
                                  showFontFamily: false,
                                  showFontSize: false,
                                  showHeaderStyle: false,
                                  showIndent: false,
                                  showInlineCode: false,
                                  showJustifyAlignment: false,
                                  showLeftAlignment: false,
                                  showLink: true,
                                  showListBullets: false,
                                  showListCheck: false,
                                  showListNumbers: false,
                                  showQuote: false,
                                  showRightAlignment: false,
                                  showSearchButton: false,
                                  showStrikeThrough: false,
                                  showSubscript: false,
                                  showSuperscript: false,
                                ),
                              ),
                            )
                            : const SizedBox.shrink(),
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
                        // Quill rich text input
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _replyFocusNode.requestFocus(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              constraints: const BoxConstraints(
                                minHeight: 40,
                                maxHeight: 120,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(24.0),
                                border:
                                    _showToolbar
                                        ? Border.all(
                                          color: colorScheme.primary,
                                          width: 1.5,
                                        )
                                        : Border.all(color: Colors.transparent),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 10.0,
                              ),
                              child: quill.QuillEditor(
                                controller: _quillController,
                                scrollController: _editorScrollController,
                                focusNode: _replyFocusNode,
                                config: quill.QuillEditorConfig(
                                  placeholder: 'post.reply_placeholder'.tr(),
                                  padding: EdgeInsets.zero,
                                  scrollable: true,
                                  autoFocus: false,
                                  expands: false,
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
                                  : Icon(
                                    Icons.send,
                                    color: colorScheme.primary,
                                  ),
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
      ),
    );
  }
}
