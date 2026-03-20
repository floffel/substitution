import '/post/widgets/post.dart';
import '/shared/widgets/mxc_image.dart';

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
  //Future<Timeline?> get timeline async => await room?.getTimeline(eventContextId: widget.eventId);
  //Future<Event?> get event async => widget.eventId == null ? null : (await timeline)?.getEventById(widget.eventId!);
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

  /*
    Future<Timeline> getTimeline(
      {void Function(int index)? onChange,
      void Function(int index)? onRemove,
      void Function(int insertID)? onInsert,
      void Function()? onNewEvent,
      void Function()? onUpdate,
      String? eventContextId}) async {


  */

  final quill.QuillController _controller = quill.QuillController.basic();
  quill.QuillController get controller => _controller;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  // TODO: same method as in settings(pages/followfeeds.dart) -> make it abstract/mixin/...
  // TODO: client id is only valid if a user logged in! Only show this option to logged in users!
  // TODO: this throws an exception if the account data is not valid!
  // so we have to ensure, that the account data exists!
  Future<Map<String, Object?>> get accountData async =>
      await client.getAccountData(client.userID!, "substitution.servers");

  @override
  void dispose() {
    _controller.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top section: reply preview + room info (scrollable if needed)
        if (widget.eventId != null || room != null)
          Flexible(
            flex: 0,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.eventId != null) ...[
                    const Text("write.answer").tr(),
                    FutureBuilder(
                      future: eventData,
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                          );
                        }
                        if (snapshot.data != null) {
                          return PostWidget(
                            event: (snapshot.data!.event),
                            displayEvent: (snapshot.data!.displayEvent),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  ],
                  if (room != null) ...[
                    const Text("write.roomheader").tr(args: [""]),
                    ListTile(
                      title: const Text(
                        'write.roomheader',
                      ).tr(args: [room!.name]),
                      subtitle: Text(room!.id),
                      leading:
                          room!.avatar != null
                              ? SizedBox(
                                width: 40,
                                height: 40,
                                child: ClipOval(
                                  child: MxcImage(
                                    uri: room!.avatar!,
                                    client: client,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    isThumbnail: true,
                                  ),
                                ),
                              )
                              : const Text("error_no_image").tr(),
                    ),
                  ],
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
              border: Border.all(color: Theme.of(context).colorScheme.outline),
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
        const SizedBox(height: 8),
        // Send button row
        Row(
          children: [
            const Spacer(),
            IconButton(
              onPressed: () async {
                final scavMsg = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final goRouter = GoRouter.of(context);
                // send text
                //Room r = (await room)!;
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
                // try to send the message as long as it did not succeed or as long as the user did not cancel
                // TODO: this is the same as in filemessage.dart => make it modular somehow?
                while (ret == null || userCancel) {
                  // TODO: make it a mixin, its almost the same as in login.dart
                  if (!context.mounted) return;
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("loading".tr()),
                        content: AspectRatio(
                          aspectRatio: .7,
                          child: FittedBox(
                            child: Column(
                              children: [
                                const CircularProgressIndicator(),
                                const Text("write.textmessage.send_start").tr(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );

                  if ((await event)?.relationshipType ==
                      RelationshipTypes.thread) {
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
                    if (!context.mounted) break;
                    userCancel =
                        await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("loading").tr(),
                              content: AspectRatio(
                                aspectRatio: 1,
                                child: FittedBox(
                                  child:
                                      const Text(
                                        "write.textmessage.send_failed",
                                      ).tr(),
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child:
                                      const Text(
                                        "write.textmessage.send_stop",
                                      ).tr(),
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                ),
                                TextButton(
                                  child:
                                      const Text(
                                        "write.textmessage.resend",
                                      ).tr(),
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                ),
                              ],
                            );
                          },
                        ) ??
                        false;
                  } else {
                    if (mounted) {
                      scavMsg.showSnackBar(
                        SnackBar(
                          content:
                              const Text(
                                "write.textmessage.send_complete",
                              ).tr(),
                        ),
                      );
                    }
                  }
                }

                if (eventThreadId != null) {
                  Event answerEvent = Event.fromMatrixEvent(
                    await client.getOneRoomEvent(
                      widget.roomId,
                      (eventThreadId),
                    ),
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
              },
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}
