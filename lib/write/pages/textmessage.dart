import '/post/widgets/post.dart';

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
  Future<Event?> get event async => widget.eventId == null || room == null
      ? null
      : Event.fromMatrixEvent(
          await client.getOneRoomEvent(widget.roomId, widget.eventId!), room!);

  Future<({Event event, Event displayEvent})> get eventTuple async => (
        event: (await event)!,
        displayEvent: (await event)!.getDisplayEvent(await (await event)!
            .room
            .getTimeline(eventContextId: (await event)!.eventId))
      );

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

  // TODO: same method as in settings(pages/followfeeds.dart) -> make it abstract/mixin/...
  // TODO: client id is only valid if a user logged in! Only show this option to logged in users!
  // TODO: this throws an exception if the account data is not valid!
  // so we have to ensure, that the account data exists!
  Future<Map<String, Object?>> get accountData async =>
      await client.getAccountData(client.userID!, "substitution.servers");

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      if (widget.eventId != null) ...[
        const Text("write.answer").tr(),

        //eventTuple
        FutureBuilder(
            future: eventTuple,
            builder: (ctx, snapshot) {
              if (snapshot.data != null) {
                return PostWidget(
                    event: (snapshot.data!.event),
                    displayEvent: (snapshot.data!.displayEvent));
              } else {
                return const Text("loading").tr();
              }
            }),
      ],
      if (room != null) ...[
        const Text("write.roomheader").tr(args: [""]),
        ListTile(
          title: const Text('write.roomheader').tr(args: [room!.name]),
          subtitle: Text(room!.id),
          leading: room!.avatar != null
              ? Image.network(room!.avatar!.getDownloadLink(client).toString())
              : const Text("error_no_image").tr(),
        )
      ],
      const Text("write.textmessage.answer_promt").tr(),


      Column(
          children: [
              quill.QuillToolbar.simple(),
              Expanded(
                  child: quill.QuillEditor.basic(
                  configurations: quill.QuillEditorConfigurations(controller: _controller),
                  ),
              )
          ],
      ),

      Row(children: [
        const Spacer(),
        IconButton(
            onPressed: () async {
              var scavMsg = ScaffoldMessenger.of(context);
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
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("loading".tr()),
                      content: AspectRatio(
                          aspectRatio: .7,
                          child: FittedBox(
                              child: Column(children: [
                            const CircularProgressIndicator(),
                            const Text("write.textmessage.send_start").tr()
                          ]))),
                    );
                  },
                );

                if ((await event)?.relationshipType ==
                    RelationshipTypes.thread) {
                  // commenting a comment => we can't start a new thread, rather use the existing one
                  eventThreadId = (await event)?.relationshipEventId;
                }

                ret = await room!.sendEvent({
                  "body": _controller.document.toPlainText(),
                  'format': 'org.matrix.custom.html',
                  'formatted_body': html,
                  'msgtype': MessageTypes.Text
                }, threadRootEventId: eventThreadId, inReplyTo: await event);

                if (!mounted) return;

                context.pop(); // pop the send started window

                if (ret == null) {
                  userCancel = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("loading").tr(),
                            content: AspectRatio(
                                aspectRatio: 1,
                                child: FittedBox(
                                  child: const Text(
                                          "write.textmessage.send_failed")
                                      .tr(),
                                )),
                            actions: <Widget>[
                              TextButton(
                                child: const Text("write.textmessage.send_stop")
                                    .tr(),
                                onPressed: () {
                                  context.pop(true);
                                },
                              ),
                              TextButton(
                                  child: const Text("write.textmessage.resend")
                                      .tr(),
                                  onPressed: () {
                                    context.pop(false);
                                  })
                            ],
                          );
                        },
                      ) ??
                      false;
                  if (!mounted) return;
                } else {
                  scavMsg.showSnackBar(SnackBar(
                    content: const Text("write.textmessage.send_complete").tr(),
                  ));
                }
              }

              if (eventThreadId != null) {
                Event answerEvent = Event.fromMatrixEvent(
                    await client.getOneRoomEvent(
                        widget.roomId, (eventThreadId)),
                    room!);
                if (!mounted) return;

                context.go(Uri(
                    path: "/post/${answerEvent.eventId}",
                    queryParameters: {'room': answerEvent.room.id}).toString());
              } else if (room != null) {
                context.go("/feed/${room!.id}");
              } else {
                context.go("/");
              }
            },
            icon: const Icon(Icons.send))
      ])
    ]);
  }
}
