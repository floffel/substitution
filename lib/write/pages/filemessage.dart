import 'package:substitution/settings/widgets/menu.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:substitution/post/widgets/post.dart';

import 'package:file_selector/file_selector.dart';

import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

@immutable
class FileMessageWrite extends StatefulWidget {
  FileMessageWrite({super.key, required this.roomId, this.eventId});

  final String roomId;
  final String? eventId;

  static FileMessageWriteState of(BuildContext context) {
    return context.findAncestorStateOfType<FileMessageWriteState>()!;
  }

  @override
  FileMessageWriteState createState() => FileMessageWriteState();
}

class FileMessageWriteState extends State<FileMessageWrite> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  Future<({Event event, Event displayEvent})> get eventTuple async => (
        event: (await event)!,
        displayEvent: (await event)!.getDisplayEvent(await (await event)!
            .room
            .getTimeline(eventContextId: (await event)!.eventId))
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => {context.pop(true)},
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text("Substitution"),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            onPressed: () => {
              _scaffoldKey.currentState?.openEndDrawer(),
            },
            icon: const Icon(Icons.menu),
          )
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(children: [
            if (widget.eventId != null) ...[
              Text("Antwort auf:"),

              //eventTuple
              FutureBuilder(
                  future: eventTuple,
                  builder: (ctx, snapshot) {
                    if (snapshot.data != null) {
                      return PostWidget(
                          event: (snapshot.data!.event),
                          displayEvent: (snapshot.data!.displayEvent));
                    } else
                      return Text("loading...");
                  }),
            ],
            if (room != null) ...[
              Text("Raum:"),
              ListTile(
                title: Text('Raum: ${room!.name}'),
                subtitle: Text(room!.id),
                leading: room!.avatar != null
                    ? Image.network(
                        room!.avatar!.getDownloadLink(client).toString())
                    : const Text("no img"),
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
                Spacer(),
                Icon(Icons.add),
                Spacer(),
                Text("Neue Dateien zum upload hinzufügen"),
                Spacer()
              ]),
            ),
            if (files != []) ...[
              ...files.map((f) => Column(children: [
                    TextFormField(
                        controller: f.textEditController,
                        decoration: InputDecoration(
                          labelText: "Titel: ",
                          //labelText: AppLocalizations.of(context)!
                          //    .authHostHomeserverInputLabel,
                        )),

                    //Text("Name: ${f.name}, ${f.file.mimeType}"),
                    if (imageExtensions
                        .contains(f.file.name.split('.').last)) ...[
                      kIsWeb
                          ? Image.network(f.file.path)
                          : Image.file(File(f.file.path)),
                    ] else ...[
                      Text("movie"),
                    ]
                  ])),
            ],

            Row(children: [
              Spacer(),
              IconButton(
                  onPressed: () async {
                    // many of this is equivalent to the textmessage widget, so we should make it a mixin
                    // send text
                    //Room r = (await room)!;
                    debugPrint("started sending message...");

                    //late final String? ret;
                    var eventThreadId = widget.eventId;

                    if ((await event)?.relationshipType ==
                        RelationshipTypes.thread) {
                      // commenting a comment => we can't start a new thread, rather use the existing one
                      eventThreadId = (await event)?.relationshipEventId;
                    }

                    // TODO: das erste soll eine Antwort sein auf das gegebene Event, if any
                    // die nachfolgenden auf das jeweils vorhergehende
                    // so können wir ncahher eine Zusammenfassung erzeugen bei der Darstellung
                    // und der spam anteil ist nicht so hoch weil wir eine Nachricht statt vieler haben

                    Event? answerEvent = await event;
                    for (var f in files) {
                      MatrixFile uploadFile = MatrixFile(
                          bytes: await f.file.readAsBytes(),
                          name: [
                            f.textEditController.text,
                            f.file.name.split(".").last
                          ].join("."));
                      String? ret = await room!.sendFileEvent(uploadFile,
                          threadRootEventId: eventThreadId,
                          inReplyTo: answerEvent);

                      if (ret == null) {
                        debugPrint("Upload failed!");
                      }

                      answerEvent = Event.fromMatrixEvent(
                          await client.getOneRoomEvent(widget.roomId, (ret!)),
                          room!);
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
                    context.go(
                        "/"); // todo: go to the room feed where one posted the new message
                  },
                  icon: Icon(Icons.send))
            ])
          ])),
      endDrawer: const Menu(),
    );
  }
}
