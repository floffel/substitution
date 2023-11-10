import '/post/pages/post.dart';

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class Post extends StatefulWidget {
  const Post({super.key, required this.eventId, required this.roomId});

  final String eventId;
  final String roomId;

  static PostState of(BuildContext context) {
    return context.findAncestorStateOfType<PostState>()!;
  }

  @override
  PostState createState() => PostState();
}

class PostState extends State<Post> {
  Future<({Event? origEvent, Event? displayEvent})> get event async {
    Room room = Provider.of<Client>(context, listen: false).getRoomById(widget
        .roomId)!; // todo: passive programming, go to 404 or smthg if room does not exist

    Event event = (await room.getEventById(
        widget.eventId))!; // TODO: passive programming! Error handling!

    Timeline timeline =
        await event.room.getTimeline(eventContextId: event.eventId);

    return (origEvent: event, displayEvent: event.getDisplayEvent(timeline));
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: event,
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return const Text("loading").tr();
          }

          // TODO: passive programming, error handling, if data == null or origEvent == null
          return PostPage(
              event: (snapshot.data!.origEvent!),
              displayEvent: (snapshot.data!.displayEvent!));
        });
  }
}
