import '/write/mixins/send_with_retry.dart';
import '/write/widgets/room_header.dart';
import '/write/widgets/reply_preview.dart';
import '/shared/mixins/matrix_essentials.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class TextMessageWrite extends StatefulWidget {
  const TextMessageWrite({super.key, required this.roomId, this.eventId});

  final String roomId;
  final String? eventId;

  static TextMessageWriteState of(BuildContext context) {
    return context.findAncestorStateOfType<TextMessageWriteState>()!;
  }

  @override
  TextMessageWriteState createState() => TextMessageWriteState();
}

class TextMessageWriteState extends State<TextMessageWrite>
    with MatrixEssentials, SendWithRetry {
  Room? get room => client.getRoomById(widget.roomId);
  Future<Event?> get event async =>
      widget.eventId == null || room == null
          ? null
          : Event.fromMatrixEvent(
            await client.getOneRoomEvent(widget.roomId, widget.eventId!),
            room!,
          );

  Future<({Event event, Event displayEvent})?> get eventData async {
    final e = await event;
    if (e == null) return null;

    final timeline = await e.room.getTimeline(eventContextId: e.eventId);
    return (event: e, displayEvent: e.getDisplayEvent(timeline));
  }

  final quill.QuillController _controller = quill.QuillController.basic();
  quill.QuillController get controller => _controller;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onEditorChanged);
  }

  void _onEditorChanged() {
    final empty = _controller.document.isEmpty();
    if (empty != _isEmpty) {
      setState(() => _isEmpty = empty);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onEditorChanged);
    _controller.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isEmpty || room == null) return;

    debugPrint('started sending message...');

    // The thread relationship is decided once (before the retry loop):
    // commenting on a comment joins its existing thread, anything else
    // starts a new reply chain. Computing this inside the loop would
    // re-fetch the same event on every retry, which is wasteful.
    var eventThreadId = widget.eventId;
    final parentEvent = await event;
    if (parentEvent?.relationshipType == RelationshipTypes.thread) {
      eventThreadId = parentEvent?.relationshipEventId;
    }

    // Compute the HTML body once — the quill document is constant during
    // the retry loop, and re-converting on every retry would be a
    // pointless duplicate of the same work.
    final deltaJson = _controller.document.toDelta().toJson();
    final converter = QuillDeltaToHtmlConverter(
      List.castFrom(deltaJson),
      ConverterOptions.forEmail(),
    );
    final html = converter.convert();

    // ignore: use_build_context_synchronously
    // The mixin captures `context` synchronously at entry, so passing
    // it across the `await` above is safe.
    await sendWithRetry(
      // ignore: use_build_context_synchronously
      context: context,
      room: room!,
      client: client,
      threadRootEventId: eventThreadId,
      loadingMessageKey: 'write.textmessage.send_start',
      errorMessageKey: 'write.textmessage.send_failed',
      successMessageKey: 'write.textmessage.send_complete',
      send:
          () => room!.sendEvent(
            {
              'body': _controller.document.toPlainText(),
              'format': 'org.matrix.custom.html',
              'formatted_body': html,
              'msgtype': MessageTypes.Text,
            },
            threadRootEventId: eventThreadId,
            inReplyTo: parentEvent,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cap the reply preview + room header section so a long reply preview
        // can never push the editor or send button off-screen (which used to
        // cause a RenderFlex overflow on smaller / desktop viewports).
        final maxHeaderHeight = constraints.maxHeight * 0.35;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top section: reply preview + room info
            if (widget.eventId != null || room != null)
              Flexible(
                flex: 0,
                fit: FlexFit.loose,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeaderHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.eventId != null)
                          ReplyPreviewWidget(future: eventData),
                        if (room != null) ...[
                          const SizedBox(height: 4),
                          RoomHeaderWidget(room: room!),
                        ],
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),

            // Formatting toolbar
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

            // Editor area (fills remaining space)
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
                    placeholder: "write.textmessage.input_placeholder".tr(),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Send button
            FilledButton.icon(
              onPressed: _isEmpty ? null : _send,
              icon: const Icon(Icons.send_rounded),
              label: Text('write.textmessage.send_button'.tr()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}
