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
    Room? room = Provider.of<Client>(context, listen: false)
        .getRoomById(widget.roomId);
    if (room == null) {
      // Room not found
      return (origEvent: null, displayEvent: null);
    }

    Event? event = await room.getEventById(widget.eventId);
    if (event == null) {
      // Event not found in the room
      return (origEvent: null, displayEvent: null);
    }

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
    return FutureBuilder<({Event? origEvent, Event? displayEvent})>(
        future: event,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: const Text("loading").tr()); // More standard loading
          }

          if (snapshot.hasError) {
            return Center(
                child: Text("post.error_loading".tr(args: ['${snapshot.error}'])));
          }

          if (!snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!.origEvent == null) {
            return Center(child: const Text("post.not_found_or_error_loading").tr());
          }

          // At this point, snapshot.data, snapshot.data!.origEvent are non-null.
          // And if origEvent is non-null, getDisplayEvent should also return non-null.
          // However, to be absolutely safe, we could check displayEvent or make PostPage accept nullable.
          // For now, let's assume displayEvent will be non-null if origEvent is non-null.
          return PostPage(
              event: snapshot.data!.origEvent!,
              displayEvent: snapshot.data!.displayEvent!);
        });
  }
}
