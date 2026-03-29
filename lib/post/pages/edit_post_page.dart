import '/write/widgets/send_progress_dialog.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:easy_localization/easy_localization.dart';

/// Page for editing an existing text post.
///
/// Loads the current post content into a Quill editor, and on save sends a
/// Matrix edit event (`m.replace` relationship) with the updated content.
class EditPostPage extends StatefulWidget {
  const EditPostPage({super.key, required this.roomId, required this.eventId});

  final String roomId;
  final String eventId;

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  Client get client => Provider.of<Client>(context, listen: false);
  Room? get room => client.getRoomById(widget.roomId);

  final quill.QuillController _controller = quill.QuillController.basic();
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  bool _isEmpty = true;
  bool _isLoading = true;
  Event? _originalEvent;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onEditorChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvent());
  }

  @override
  void dispose() {
    _controller.removeListener(_onEditorChanged);
    _controller.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  void _onEditorChanged() {
    final empty = _controller.document.isEmpty();
    if (empty != _isEmpty) setState(() => _isEmpty = empty);
  }

  Future<void> _loadEvent() async {
    final r = room;
    if (r == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final matrixEvent = await client.getOneRoomEvent(
        widget.roomId,
        widget.eventId,
      );
      final event = Event.fromMatrixEvent(matrixEvent, r);
      final timeline = await r.getTimeline(eventContextId: event.eventId);
      final displayEvent = event.getDisplayEvent(timeline);

      // Pre-populate editor with existing plain text.
      // Note: we load plain text rather than HTML because converting HTML back
      // to Quill Delta is not straightforward. Formatting is preserved in the
      // stored Delta if available, but we fall back to plain text here.
      final plainText = displayEvent.plaintextBody;
      if (plainText.isNotEmpty) {
        _controller.document = quill.Document()..insert(0, plainText);
        _controller.updateSelection(
          TextSelection.collapsed(offset: plainText.length),
          quill.ChangeSource.local,
        );
      }

      if (mounted) {
        setState(() {
          _originalEvent = event;
          _isLoading = false;
          _isEmpty = plainText.isEmpty;
        });
      }
    } catch (e) {
      debugPrint('EditPostPage: failed to load event: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_isEmpty || _originalEvent == null) return;

    final r = room;
    if (r == null) return;

    final scavMsg = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final goRouter = GoRouter.of(context);

    final deltaJson = _controller.document.toDelta().toJson();
    final converter = QuillDeltaToHtmlConverter(
      List.castFrom(deltaJson),
      ConverterOptions.forEmail(),
    );
    final html = converter.convert();
    final plainText = _controller.document.toPlainText();

    String? ret;
    bool userCancel = false;

    while (ret == null && !userCancel) {
      if (!mounted) return;

      showSendLoadingDialog(context, messageKey: 'post.edit.send_start');

      try {
        // Send a Matrix edit event using the m.replace relationship.
        ret = await r.sendEvent({
          'msgtype': MessageTypes.Text,
          'body': '* $plainText',
          'format': 'org.matrix.custom.html',
          'formatted_body': '* $html',
          'm.new_content': {
            'msgtype': MessageTypes.Text,
            'body': plainText,
            'format': 'org.matrix.custom.html',
            'formatted_body': html,
          },
          'm.relates_to': {
            'rel_type': RelationshipTypes.edit,
            'event_id': _originalEvent!.eventId,
          },
        });
      } catch (e) {
        debugPrint('EditPostPage: save error: $e');
      }

      navigator.pop(); // pop loading dialog

      if (ret == null) {
        if (!mounted) break;
        userCancel = await showSendErrorDialog(
          context,
          errorMessageKey: 'post.edit.send_failed',
        );
      } else {
        if (mounted) {
          scavMsg.showSnackBar(
            SnackBar(content: Text('post.edit.send_complete'.tr())),
          );
        }
      }
    }

    if (!userCancel && mounted) {
      goRouter.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('post.edit.title').tr(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: (_isEmpty || _isLoading) ? null : _save,
              child: const Text('post.edit.save_button').tr(),
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Toolbar
                    quill.QuillSimpleToolbar(
                      controller: _controller,
                      config: const quill.QuillSimpleToolbarConfig(
                        multiRowsDisplay: false,
                        showAlignmentButtons: false,
                        showBackgroundColorButton: false,
                        showCenterAlignment: false,
                        showClearFormat: false,
                        showCodeBlock: false,
                        showColorButton: false,
                        showDirection: false,
                        showFontFamily: false,
                        showFontSize: false,
                        showHeaderStyle: true,
                        showIndent: false,
                        showInlineCode: false,
                        showJustifyAlignment: false,
                        showLeftAlignment: false,
                        showRightAlignment: false,
                        showSearchButton: false,
                        showStrikeThrough: false,
                        showSubscript: false,
                        showSuperscript: false,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Editor area
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outline),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: quill.QuillEditor(
                          controller: _controller,
                          scrollController: _editorScrollController,
                          focusNode: _editorFocusNode,
                          config: quill.QuillEditorConfig(
                            placeholder:
                                'write.textmessage.input_placeholder'.tr(),
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
