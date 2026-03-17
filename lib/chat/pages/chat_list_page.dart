import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '/shared/utils/relative_time.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  Client get client => Provider.of<Client>(context, listen: false);

  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _syncSub = client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  List<Room> get _dmRooms {
    final rooms =
        client.rooms.where((r) => r.directChatMatrixID != null).toList();
    // Sort newest conversation first by last event timestamp
    rooms.sort((a, b) {
      final aTs =
          a.lastEvent?.originServerTs ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTs =
          b.lastEvent?.originServerTs ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTs.compareTo(aTs);
    });
    return rooms;
  }

  // ── Widgets ─────────────────────────────────────────────────────────────────

  Widget _buildRoomTile(Room room) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final otherUserId = room.directChatMatrixID ?? '';
    final otherUser = room.unsafeGetUserFromMemoryOrFallback(otherUserId);
    final displayName = otherUser.displayName ?? otherUserId;
    final avatarUri = otherUser.avatarUrl;
    final avatarUrl = avatarUri?.getDownloadUri(client).toString();

    final lastEvent = room.lastEvent;
    String lastMessageText = '';
    String lastMessageTime = '';
    if (lastEvent != null) {
      if (lastEvent.type == EventTypes.Message) {
        if (lastEvent.messageType == MessageTypes.Text) {
          lastMessageText = lastEvent.body;
        } else {
          lastMessageText =
              '📎 ${lastEvent.body.isNotEmpty ? lastEvent.body : 'chat.media_message'.tr()}';
        }
      } else if (lastEvent.type == EventTypes.RoomMember) {
        lastMessageText = 'chat.conversation_started'.tr();
      }
      lastMessageTime = relativeTime(lastEvent.originServerTs);
    }

    final unreadCount = room.notificationCount;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          // Avatar
          avatarUrl != null
              ? CircleAvatar(
                radius: 26,
                backgroundImage: NetworkImage(avatarUrl),
                backgroundColor: colorScheme.primaryContainer,
                onBackgroundImageError: (_, _) {},
              )
              : CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
          // Unread badge
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lastMessageTime.isNotEmpty)
            Text(
              lastMessageTime,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
      subtitle:
          lastMessageText.isNotEmpty
              ? Text(
                lastMessageText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight:
                      unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              )
              : null,
      onTap: () {
        context.push('/chat/${Uri.encodeComponent(room.id)}');
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dmRooms = _dmRooms;

    if (dmRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'chat.no_conversations'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'chat.no_conversations_hint'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: dmRooms.length,
      separatorBuilder:
          (_, _) => Divider(
            height: 1,
            indent: 72,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
      itemBuilder: (_, i) => _buildRoomTile(dmRooms[i]),
    );
  }
}
