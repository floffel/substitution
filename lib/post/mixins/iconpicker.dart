import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:go_router/go_router.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;

mixin IconPicker {
  Future<void> pickIcon(BuildContext context, Event event,
      {Event? postEvent}) async {
    // fallack method. Not pritty
    await showDialog(
      //isScrollControlled: false,
      context: context,
      builder: (BuildContext subcontext) {
        return EmojiPicker(
          config: Config(
            height: 256,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              // Issue: https://github.com/flutter/flutter/issues/28894
              emojiSizeMax: 28 *
                  (foundation.defaultTargetPlatform == TargetPlatform.iOS
                      ? 1.20
                      : 1.0),
            ),
            viewOrderConfig: const ViewOrderConfig(
              top: EmojiPickerItem.categoryBar,
              middle: EmojiPickerItem.emojiView,
              bottom: EmojiPickerItem.searchBar,
            ),
            skinToneConfig: const SkinToneConfig(),
            categoryViewConfig: const CategoryViewConfig(),
            bottomActionBarConfig: const BottomActionBarConfig(),
            searchViewConfig: const SearchViewConfig(),
          ),
          onEmojiSelected: (category, emoji) {
            event.room.sendReaction(event.eventId, emoji.emoji);
            Navigator.of(subcontext).pop();
          },
        );
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
