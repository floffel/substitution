import '/post/pages/post.dart';
import '/shared/services/loading_service.dart';

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:go_router/go_router.dart';
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
  late Future<({Event? origEvent, Event? displayEvent})?> _eventFuture;

  @override
  void initState() {
    super.initState();
    _eventFuture = _loadEvent();
  }

  Future<({Event? origEvent, Event? displayEvent})?> _loadEvent() async {
    final client = Provider.of<Client>(context, listen: false);
    final loadingService = Provider.of<LoadingService>(context, listen: false);

    loadingService.setLoading('post');
    try {
      // Check if room exists
      final Room? room = client.getRoomById(widget.roomId);
      if (room == null) {
        debugPrint("Room ${widget.roomId} not found.");
        return null;
      }

      // Check if event exists
      final Event? event = await room.getEventById(widget.eventId);
      if (event == null) {
        debugPrint(
          "Event ${widget.eventId} not found in room ${widget.roomId}.",
        );
        return null;
      }

      final Timeline timeline = await event.room.getTimeline(
        eventContextId: event.eventId,
      );

      return (origEvent: event, displayEvent: event.getDisplayEvent(timeline));
    } finally {
      loadingService.setDone('post');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({Event? origEvent, Event? displayEvent})?>(
      future: _eventFuture,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // TopLoadingBar handles the loading indicator — no spinner here.
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("post.error.not_found").tr(),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
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
