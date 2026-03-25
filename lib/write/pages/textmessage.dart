import '/write/widgets/room_header.dart';
import '/write/widgets/reply_preview.dart';
import '/write/widgets/send_progress_dialog.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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

class TextMessageWriteState extends State<TextMessageWrite> {
  // todo: make client a mixin
  Client get client => Provider.of<Client>(context, listen: false);
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

  // TODO: same method as in settings(pages/followfeeds.dart) -> make it abstract/mixin/...
  // TODO: client id is only valid if a user logged in! Only show this option to logged in users!
  // TODO: this throws an exception if the account data is not valid!
  // so we have to ensure, that the account data exists!
  Future<Map<String, Object?>> get accountData async =>
      await client.getAccountData(client.userID!, "substitution.servers");

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
    if (_isEmpty) return;

    final scavMsg = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final goRouter = GoRouter.of(context);
    debugPrint("started sending message...");

    final deltaJson = _controller.document.toDelta().toJson();
    final converter = QuillDeltaToHtmlConverter(
      List.castFrom(deltaJson),
      ConverterOptions.forEmail(),
    );

    final html = converter.convert();

    String? ret;
    var eventThreadId = widget.eventId;
    bool userCancel = false;
    // try to send the message as long as it did not succeed or the user did not cancel
    // TODO: this is the same as in filemessage.dart => make it modular somehow?
    while (ret == null && !userCancel) {
      // TODO: make it a mixin, its almost the same as in login.dart
      if (!mounted) return;
      showSendLoadingDialog(
        context,
        messageKey: 'write.textmessage.send_start',
      );

      if ((await event)?.relationshipType == RelationshipTypes.thread) {
        // commenting a comment => we can't start a new thread, rather use the existing one
        eventThreadId = (await event)?.relationshipEventId;
      }

      ret = await room!.sendEvent(
        {
          "body": _controller.document.toPlainText(),
          'format': 'org.matrix.custom.html',
          'formatted_body': html,
          'msgtype': MessageTypes.Text,
        },
        threadRootEventId: eventThreadId,
        inReplyTo: await event,
      );

      navigator.pop(); // pop the send started window

      if (ret == null) {
        if (!mounted) break;
        userCancel = await showSendErrorDialog(
          context,
          errorMessageKey: 'write.textmessage.send_failed',
          retryKey: 'write.textmessage.buttons.resend',
          cancelKey: 'write.textmessage.buttons.send_stop',
        );
      } else {
        if (mounted) {
          scavMsg.showSnackBar(
            SnackBar(content: Text('write.textmessage.send_complete'.tr())),
          );
        }
      }
    }

    if (eventThreadId != null) {
      Event answerEvent = Event.fromMatrixEvent(
        await client.getOneRoomEvent(widget.roomId, eventThreadId),
        room!,
      );
      goRouter.go(
        Uri(
          path: "/post/${answerEvent.eventId}",
          queryParameters: {'room': answerEvent.room.id},
        ).toString(),
      );
    } else if (room != null) {
      goRouter.go("/feed/${room!.id}");
    } else {
      goRouter.go("/");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top section: reply preview + room info
        if (widget.eventId != null || room != null)
          Flexible(
            flex: 0,
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
  }
}
