import '/post/widgets/post.dart';

import '/shared/platform/image_helper.dart' show imageFromPath;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:file_selector/file_selector.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class FileMessageWrite extends StatefulWidget {
  const FileMessageWrite({super.key, required this.roomId, this.eventId});

  final String roomId;
  final String? eventId;

  static FileMessageWriteState of(BuildContext context) {
    return context.findAncestorStateOfType<FileMessageWriteState>()!;
  }

  @override
  FileMessageWriteState createState() => FileMessageWriteState();
}

class FileMessageWriteState extends State<FileMessageWrite> {
  List<String> imageExtensions = const ['jpg', 'jpeg', 'png', 'gif'];
  List<String> videoExtensions = const ['mp4']; // todo: test ogg etc

  late final XTypeGroup imgTypeGroup = XTypeGroup(
    label: 'JPEGs',
    extensions: imageExtensions,
  );
  late final XTypeGroup videoTypeGroup = XTypeGroup(
    label: 'PNGs',
    extensions: videoExtensions,
  );

  /*final adressContrainer = TextEditingController(
    text: 'matrix.org',
  );*/

  List<({XFile file, TextEditingController textEditController})> files = [];

  // todo: make client a mixin
  Client get client => Provider.of<Client>(context, listen: false);
  Room? get room => client.getRoomById(widget.roomId);
  //Future<Timeline?> get timeline async => await room?.getTimeline(eventContextId: widget.eventId);
  //Future<Event?> get event async => widget.eventId == null ? null : (await timeline)?.getEventById(widget.eventId!);
  Future<Event?> get event async => widget.eventId == null || room == null
      ? null
      : Event.fromMatrixEvent(
          await client.getOneRoomEvent(widget.roomId, widget.eventId!), room!);

  Future<({Event event, Event displayEvent})?> get eventData async {
    final e = await event;
    if (e == null) return null;

    final timeline = await e.room.getTimeline(eventContextId: e.eventId);
    return (event: e, displayEvent: e.getDisplayEvent(timeline));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      if (widget.eventId != null) ...[
        const Text("write.answer").tr(),

        //eventTuple
        FutureBuilder(
            future: eventData,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              return PostWidget(
                  event: (snapshot.data!.event),
                  displayEvent: (snapshot.data!.displayEvent));
            }),
      ],
      if (room != null) ...[
        const Text("write.roomheader").tr(args: [""]),
        ListTile(
          title: const Text('write.roomheader').tr(args: [room!.name]),
          subtitle: Text(room!.id),
          leading: room!.avatar != null
              ? Image.network(room!.avatar!.getDownloadUri(client).toString())
              : const Text("error_no_image").tr(),
        )
      ],
      // hier will ich ein upload bt und dann die liste um den dateien Titel (namen) zu geben
      TextButton(
        onPressed: () async {
          for (var f in files) {
            f.textEditController.dispose();
          }

          // TODO: change for ios, file types are unsupported
          List<XFile> newFiles = await openFiles(acceptedTypeGroups: [
            imgTypeGroup,
            videoTypeGroup,
          ]);

          files = newFiles
              .map((f) => (
                    file: f,
                    textEditController: TextEditingController(
                        text: f.name
                            .split('.')
                            .reversed
                            .skip(1)
                            .toList()
                            .reversed
                            .join())
                  ))
              .toList();

          setState(() {});
        },
        // todo: nicer design...
        child: Row(children: [
          const Spacer(),
          const Icon(Icons.add),
          const Spacer(),
          const Text("write.filemessage.upload_files").tr(),
          const Spacer()
        ]),
      ),
      if (files != []) ...[
        ...files.map((f) => Column(children: [
              TextFormField(
                  controller: f.textEditController,
                  decoration: InputDecoration(
                    labelText: "write.filemessage.title_header".tr(),
                  )),

              //Text("Name: ${f.name}, ${f.file.mimeType}"),
              if (imageExtensions.contains(f.file.name.split('.').last)) ...[
                imageFromPath(f.file.path),
              ] else ...[
                Text("movie"), // todo implement this...
              ]
            ])),
      ],

      Row(children: [
        const Spacer(),
        IconButton(
            onPressed: () async {
              final scavMsg = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final goRouter = GoRouter.of(context);

              // many of this is equivalent to the textmessage widget, so we should make it a mixin
              // send text
              //Room r = (await room)!;
              debugPrint("started sending message...");

              // TODO: this could be a seperated widget to give updates to the user via setState rather than
              // always showing new windows...

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
                          const Text(
                                  "write.filemessage.upload_files.upload_start")
                              .tr()
                        ]))),
                  );
                },
              );

              Event? answerEvent = await event;
              var eventThreadId = widget.eventId;

              if (answerEvent?.relationshipType == RelationshipTypes.thread) {
                // commenting a comment => we can't start a new thread, rather use the existing one
                eventThreadId = answerEvent?.relationshipEventId;
              }

              navigator.pop(); // pop the "starting upload" overlay

              for (var f in files) {
                String? ret;
                bool userCancel = false;
                // try to uploading the file as long as it did not succeed or as long as the user did not cancel
                while (ret == null || userCancel) {
                  String uploadFileName = [
                    f.textEditController.text,
                    f.file.name.split(".").last
                  ].join(".");

                  // TODO: make it a mixin, its almost the same as in login.dart
                  if (!mounted) return;
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
                              const Text(
                                      "write.filemessage.upload_file_process")
                                  .tr(args: [uploadFileName])
                            ]))),
                      );
                    },
                  );

                  MatrixFile uploadFile = MatrixFile(
                      bytes: await f.file.readAsBytes(), name: uploadFileName);
                  ret = await room!.sendFileEvent(uploadFile,
                      threadRootEventId: eventThreadId, inReplyTo: answerEvent);

                  navigator.pop(); // pop the Uploading file ... dialog

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
                                            "write.filemessage.upload_error")
                                        .tr(args: [f.textEditController.text]),
                                  )),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text(
                                          "write.filemessage.upload_stop")
                                      .tr(),
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                ),
                                TextButton(
                                    child: const Text(
                                            "write.filemessage.upload_retry")
                                        .tr(),
                                    onPressed: () {
                                      Navigator.of(context).pop(false);
                                    })
                              ],
                            );
                          },
                        ) ??
                        false;
                  } else {
                    scavMsg.showSnackBar(SnackBar(
                      content:
                          const Text("write.filemessage.upload_file_complete")
                              .tr(args: [uploadFileName]),
                    ));
                  }
                }

                //answerEvent = Event.fromMatrixEvent(
                //    await client.getOneRoomEvent(widget.roomId, (ret!)),
                //    room!);
              }

              //ret = await room!.sendFileEvent(); // TODO: HIER WEITER

              /*ret = await room!.sendEvent({
                  "body": _controller.document.toPlainText(),
                  'format': 'org.matrix.custom.html',
                  'formatted_body': _html,
                  'msgtype': MessageTypes.Text
                }, threadRootEventId: eventThreadId, inReplyTo: await event);*/
/*
                debugPrint("send message complete with ret ${ret}...");*/
              // todo: show complete action and route to home or so
              scavMsg.showSnackBar(SnackBar(
                content: const Text("write.filemessage.upload_complete").tr(),
              ));

              if (answerEvent != null) {
                goRouter.go(Uri(
                    path: "/post/${answerEvent.eventId}",
                    queryParameters: {'room': answerEvent.room.id}).toString());
              } else if (room != null) {
                goRouter.go("/feed/${room!.id}");
              } else {
                goRouter.go("/");
              }
            },
            icon: const Icon(Icons.send))
      ])
    ]);
  }
}
