import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_selector/file_selector.dart';

import '/shared/utils/relative_time.dart';
import '/shared/widgets/avatar.dart';
import '/shared/widgets/mxc_image.dart';
import '/write/widgets/send_progress_dialog.dart';

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
    } catch (e) {
      debugPrint('ChatPage: failed to load history: $e');
    }
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

  Future<void> _pickAndSendFile() async {
    final room = _room;
    if (room == null) return;

    final imgTypeGroup = XTypeGroup(
      label: 'Images',
      extensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
    );
    final videoTypeGroup = XTypeGroup(
      label: 'Videos',
      extensions: const ['mp4', 'mov', 'webm'],
    );
    final docTypeGroup = XTypeGroup(
      label: 'Documents',
      extensions: const ['pdf', 'doc', 'docx', 'txt', 'zip'],
    );

    final List<XFile> picked = await openFiles(
      acceptedTypeGroups: [imgTypeGroup, videoTypeGroup, docTypeGroup],
    );
    if (picked.isEmpty) return;

    // Capture context-dependent objects before any await.
    // ignore: use_build_context_synchronously
    final navigator = Navigator.of(context);
    // ignore: use_build_context_synchronously
    final scavMsg = ScaffoldMessenger.of(context);

    for (final xfile in picked) {
      String? ret;
      bool userCancel = false;

      while (ret == null && !userCancel) {
        if (!mounted) return;

        showSendLoadingDialog(context, messageKey: 'chat.upload_start');

        try {
          final bytes = await xfile.readAsBytes();
          final matrixFile = MatrixFile(bytes: bytes, name: xfile.name);
          ret = await room.sendFileEvent(matrixFile);
        } catch (e) {
          debugPrint('Chat: file upload error: $e');
        }

        navigator.pop(); // pop loading dialog

        if (ret == null) {
          if (!mounted) break;
          userCancel = await showSendErrorDialog(
            context,
            errorMessageKey: 'chat.upload_error',
          );
        } else {
          if (mounted) {
            scavMsg.showSnackBar(
              SnackBar(content: Text('chat.upload_complete'.tr())),
            );
          }
        }
      }
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

  Widget _buildAvatarWidget(Uri? avatarUri, String displayName, double radius) {
    return Avatar(
      mxContent: avatarUri,
      name: displayName,
      client: client,
      size: radius * 2,
      fontSize: radius * 0.8,
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
    } else if (event.messageType == MessageTypes.Image) {
      // Inline image rendering using MxcImage
      final mxcUrl = event.content.tryGet<String>('url');
      final uri = mxcUrl != null ? Uri.tryParse(mxcUrl) : null;
      if (uri != null) {
        content = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
            child: MxcImage(
              uri: uri,
              client: client,
              fit: BoxFit.cover,
              isThumbnail: true,
              errorBuilder:
                  (context, error) => Icon(
                    Icons.broken_image_rounded,
                    size: 48,
                    color:
                        isMe
                            ? colorScheme.onPrimary.withValues(alpha: 0.5)
                            : colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        );
      } else {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(event.body, style: theme.textTheme.bodyMedium),
          ],
        );
      }
    } else {
      // Video, audio, file
      final IconData mediaIcon = switch (event.messageType) {
        MessageTypes.Video => Icons.videocam_rounded,
        MessageTypes.Audio => Icons.audiotrack_rounded,
        _ => Icons.attach_file_rounded,
      };
      final filename = event.content.tryGet<String>('filename');
      final hasCaption = filename != null && event.body != filename;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                  hasCaption
                      ? filename
                      : (event.body.isNotEmpty
                          ? event.body
                          : 'chat.media_message'.tr()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (hasCaption) ...[
            const SizedBox(height: 4),
            Text(
              event.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
            child: _buildAvatarWidget(avatarUri, sender.displayName ?? '?', 16),
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
    Uri? appBarAvatarUri;

    if (room != null) {
      final otherUserId = room.directChatMatrixID;
      if (otherUserId != null) {
        final otherUser = room.unsafeGetUserFromMemoryOrFallback(otherUserId);
        appBarTitle = otherUser.displayName ?? otherUserId;
        appBarAvatarUri = otherUser.avatarUrl;
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
            _buildAvatarWidget(appBarAvatarUri, appBarTitle, 18),
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
                // Attachment button
                IconButton(
                  onPressed: _isSending ? null : _pickAndSendFile,
                  icon: Icon(
                    Icons.attach_file_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'chat.attach_file'.tr(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                const SizedBox(width: 4),
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
