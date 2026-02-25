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
  Future<({Event? origEvent, Event? displayEvent})?> get event async {
    final client = Provider.of<Client>(context, listen: false);

    // Check if room exists
    final Room? room = client.getRoomById(widget.roomId);
    if (room == null) {
      debugPrint("Room ${widget.roomId} not found.");
      return null;
    }

    // Check if event exists
    final Event? event = await room.getEventById(widget.eventId);
    if (event == null) {
      debugPrint("Event ${widget.eventId} not found in room ${widget.roomId}.");
      return null;
    }

    Timeline timeline = await event.room.getTimeline(
      eventContextId: event.eventId,
    );

    return (origEvent: event, displayEvent: event.getDisplayEvent(timeline));
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({Event? origEvent, Event? displayEvent})?>(
      future: event,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("post.error.not_found").tr(), // Add translation key
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Go Back"),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        if (data.origEvent == null || data.displayEvent == null) {
          return const Center(child: Text("Event data incomplete"));
        }

        return PostPage(
          event: data.origEvent!,
          displayEvent: data.displayEvent!,
        );
      },
    );
  }
}
