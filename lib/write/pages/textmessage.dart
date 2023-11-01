import 'package:substitution/settings/widgets/menu.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:substitution/post/widgets/post.dart';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

// hier will ich eigentlich als übergabe einen raum haben
// optional ein post oder kommentar, den ich dann darüber anzeige, zum antworten
// und dann da eine neue Text-Message reinsenden

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  quill.QuillController _controller = quill.QuillController.basic();

  // TODO: same method as in settings(pages/followfeeds.dart) -> make it abstract/mixin/...
  // TODO: client id is only valid if a user logged in! Only show this option to logged in users!
  // TODO: this throws an exception if the account data is not valid!
  // so we have to ensure, that the account data exists!
  Future<Map<String, Object?>> get accountData async =>
      await client.getAccountData(client.userID!, "substitution.servers");

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
      body: ListView(children: [
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
                } else {
                  return Text("loading...");
                }
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
        Text("Antwort eingeben:"),
        quill.QuillProvider(
          configurations: quill.QuillConfigurations(
            controller: _controller,
            sharedConfigurations: const quill.QuillSharedConfigurations(),
          ),
          child: Column(
            children: [
              const quill.QuillToolbar(),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 100,
                ),
                child: quill.QuillEditor.basic(
                  configurations: const quill.QuillEditorConfigurations(
                    readOnly: false, // true for view only mode
                  ),
                ),
              )
            ],
          ),
        ),
        Row(children: [
          const Spacer(),
          IconButton(
              onPressed: () async {
                // send text
                //Room r = (await room)!;
                debugPrint("started sending message...");

                final deltaJson = _controller.document.toDelta().toJson();
                final converter = QuillDeltaToHtmlConverter(
                  List.castFrom(deltaJson),
                  ConverterOptions.forEmail(),
                );

                final _html = converter.convert();

                debugPrint((await event)?.relationshipType);

                late final String? ret;
                var eventThreadId = widget.eventId;

                if ((await event)?.relationshipType ==
                    RelationshipTypes.thread) {
                  // commenting a comment => we can't start a new thread, rather use the existing one
                  eventThreadId = (await event)?.relationshipEventId;
                }

                ret = await room!.sendEvent({
                  "body": _controller.document.toPlainText(),
                  'format': 'org.matrix.custom.html',
                  'formatted_body': _html,
                  'msgtype': MessageTypes.Text
                }, threadRootEventId: eventThreadId, inReplyTo: await event);

                debugPrint("send message complete with ret ${ret}...");

                if (!mounted) return;
                if (eventThreadId != null) {
                  context.go("/post/${eventThreadId}");
                } else if (room != null) {
                  context.go("/feed/${room!.id}");
                } else {
                  context.go("/");
                }
              },
              icon: const Icon(Icons.send))
        ])
      ]),
      endDrawer: const Menu(),
    );
  }
}
