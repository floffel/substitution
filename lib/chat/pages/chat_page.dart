import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '/shared/utils/relative_time.dart';

class ChatPage extends StatefulWidget {
  final String roomId;

  const ChatPage({super.key, required this.roomId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Client get client => Provider.of<Client>(context, listen: false);
  Room? get _room => client.getRoomById(widget.roomId);

  Timeline? _timeline;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  bool _isLoadingTimeline = true;
  bool _isLoadingHistory = false;

  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _syncSub = client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTimeline());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _syncSub?.cancel();
    super.dispose();
  }

  // ── Timeline init ──────────────────────────────────────────────────────────

  Future<void> _initTimeline() async {
    final room = _room;
    if (room == null) {
      if (mounted) setState(() => _isLoadingTimeline = false);
      return;
    }
    try {
      final timeline = await room.getTimeline();
      if (!mounted) return;
      setState(() {
        _timeline = timeline;
        _isLoadingTimeline = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingTimeline = false);
    }
  }

  // ── History loading ────────────────────────────────────────────────────────

  void _onScroll() {
    final tl = _timeline;
    if (tl == null) return;
    // With reverse:true ListView, maxScrollExtent is toward the oldest messages.
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingHistory &&
        tl.canRequestHistory) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    final tl = _timeline;
    if (tl == null || _isLoadingHistory) return;
    setState(() => _isLoadingHistory = true);
    try {
      await tl.requestHistory(historyCount: 50);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingHistory = false);
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final room = _room;
    if (room == null) return;

    _inputController.clear();
    setState(() => _isSending = true);
    try {
      await room.sendTextEvent(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('chat.error_sending'.tr())));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Message list ───────────────────────────────────────────────────────────

  /// Returns messages in newest-first order (matches ListView reverse:true).
  List<Event> get _messages {
    return (_timeline?.events ?? [])
        .where(
          (e) =>
              e.type == EventTypes.Message &&
              !e.redacted &&
              e.messageType.isNotEmpty,
        )
        .toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildAvatarWidget(
    String? avatarUrl,
    String displayName,
    double radius,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: colorScheme.primaryContainer,
        onBackgroundImageError: (_, _) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.8,
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Message bubble ─────────────────────────────────────────────────────────

  Widget _buildMessageBubble(Event event) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMe = event.senderId == client.userID;
    final sender = event.senderFromMemoryOrFallback;
    final timestamp = relativeTime(event.originServerTs);

    // Build the bubble content based on message type
    final Widget content;
    if (event.messageType == MessageTypes.Text) {
      content = Text(
        event.body,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      );
    } else {
      // Other media types: image, video, audio, file
      final IconData mediaIcon = switch (event.messageType) {
        MessageTypes.Image => Icons.image_rounded,
        MessageTypes.Video => Icons.videocam_rounded,
        MessageTypes.Audio => Icons.audiotrack_rounded,
        _ => Icons.attach_file_rounded,
      };
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            mediaIcon,
            size: 18,
            color:
                isMe
                    ? colorScheme.onPrimary.withValues(alpha: 0.8)
                    : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              event.body.isNotEmpty ? event.body : 'chat.media_message'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          content,
          const SizedBox(height: 4),
          Text(
            timestamp,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color:
                  isMe
                      ? colorScheme.onPrimary.withValues(alpha: 0.65)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );

    if (isMe) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [bubble],
        ),
      );
    }

    // Other user: show avatar on the left
    final avatarUri = sender.avatarUrl;
    final avatarUrl = avatarUri?.getDownloadUri(client).toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap:
                () => context.push(
                  '/profile/${Uri.encodeComponent(event.senderId)}',
                ),
            child: _buildAvatarWidget(avatarUrl, sender.displayName ?? '?', 16),
          ),
          const SizedBox(width: 8),
          bubble,
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final room = _room;
    final messages = _messages;

    // Resolve the other user's display info for the app bar
    String appBarTitle = 'chat.title'.tr();
    String? appBarAvatarUrl;

    if (room != null) {
      final otherUserId = room.directChatMatrixID;
      if (otherUserId != null) {
        final otherUser = room.unsafeGetUserFromMemoryOrFallback(otherUserId);
        appBarTitle = otherUser.displayName ?? otherUserId;
        if (otherUser.avatarUrl != null) {
          appBarAvatarUrl =
              otherUser.avatarUrl!.getDownloadUri(client).toString();
        }
      } else {
        appBarTitle = room.name.isNotEmpty ? room.name : 'chat.title'.tr();
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAvatarWidget(appBarAvatarUrl, appBarTitle, 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                appBarTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (room?.directChatMatrixID != null)
            IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              tooltip: 'chat.view_profile'.tr(),
              onPressed: () {
                final userId = room!.directChatMatrixID!;
                context.push('/profile/${Uri.encodeComponent(userId)}');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ────────────────────────────────────────────────
          Expanded(
            child:
                _isLoadingTimeline
                    ? const Center(child: CircularProgressIndicator())
                    : room == null
                    ? Center(
                      child: Text(
                        'chat.error_loading'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                    : Stack(
                      children: [
                        messages.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 56,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'chat.no_messages'.tr(),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              controller: _scrollController,
                              // newest-first order + reverse:true = newest at bottom
                              reverse: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: messages.length,
                              itemBuilder:
                                  (_, i) => _buildMessageBubble(messages[i]),
                            ),
                        // Top loading indicator while fetching history
                        if (_isLoadingHistory)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                            ),
                          ),
                      ],
                    ),
          ),

          // ── Input bar ────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom > 0
                      ? 8
                      : MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom
                      : 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'chat.input_placeholder'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : _sendMessage,
                  icon:
                      _isSending
                          ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                          : const Icon(Icons.send_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
