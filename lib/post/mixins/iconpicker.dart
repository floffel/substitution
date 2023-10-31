import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:emoji_selector/emoji_selector.dart';
import 'package:go_router/go_router.dart';

mixin IconPicker {
  Future<void> pickIcon(BuildContext context, Event event,
      {Event? postEvent}) async {
    await showDialog(
      //isScrollControlled: false,
      context: context,
      builder: (BuildContext subcontext) {
        return AlertDialog(
            title: const Text('Coose an Icon'),
            content: EmojiSelector(
              onSelected: (emoji) {
                // add emoji to the event
                event.room.sendReaction(event.eventId, emoji.char);
                Navigator.of(subcontext).pop();
              },
            ));
      },
    );

    if (!context.mounted) {
      return;
    }

    if (postEvent != null) {
      context.push(Uri(
          path: "/post/${postEvent.eventId}",
          queryParameters: {'room': postEvent.roomId}).toString());
    } else {
      context.push(Uri(
          path: "/post/${event.eventId}",
          queryParameters: {'room': event.roomId}).toString());
    }
  }
}
