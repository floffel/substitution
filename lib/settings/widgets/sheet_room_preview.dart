import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import '/post/widgets/post.dart';
import '/shared/models/substitution_room.dart';
import '/shared/services/substitution_service.dart';
import '/shared/widgets/post_skeleton.dart';
import '/shared/widgets/mxc_image.dart';

/// A bottom-sheet that shows a preview of the latest posts in a room.
/// It can peek into rooms with `world_readable` history without joining.
class RoomPreviewSheet extends StatefulWidget {
  const RoomPreviewSheet({
    super.key,
    required this.room,
    required this.onJoin,
    required this.onLeave,
  });

  final SubstitutionRoom room;
  final Future<void> Function(String roomId) onJoin;
  final Future<void> Function(String roomId) onLeave;

  @override
  State<RoomPreviewSheet> createState() => _RoomPreviewSheetState();
}

class _RoomPreviewSheetState extends State<RoomPreviewSheet> {
  Client get client => Provider.of<Client>(context, listen: false);

  List<({Event origEvent, Event displayEvent})> _posts = [];
  bool _isLoadingPosts = true;
  bool _cannotPeek = false;
  bool _isJoining = false;
  bool _isLeaving = false;

  // Track joined state locally so the button updates without rebuilding the list
  late bool _joined;

  @override
  void initState() {
    super.initState();
    _joined = widget.room.joined;
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoadingPosts = true;
      _cannotPeek = false;
    });

    try {
      Room? room = client.getRoomById(widget.room.id);
      List<Event> rawEvents;

      if (room != null && _joined) {
        // User is a member – use timeline for best results
        final timeline = await room.getTimeline().timeout(
          const Duration(seconds: 15),
        );

        // Request some history
        if (timeline.canRequestHistory) {
          await timeline
              .requestHistory(historyCount: 30)
              .timeout(const Duration(seconds: 15));
        }

        rawEvents =
            timeline.events
                .where(
                  (e) =>
                      e.type == 'm.room.message' &&
                      e.relationshipType != RelationshipTypes.reference &&
                      e.relationshipType != RelationshipTypes.thread &&
                      e.relationshipType != RelationshipTypes.edit,
                )
                .map((e) => e.getDisplayEvent(timeline))
                .toList();
      } else {
        // Not a member – try peeking via getRoomEvents
        final resp = await client
            .getRoomEvents(
              widget.room.id,
              Direction.b,
              limit: 30,
              filter: jsonEncode(StateFilter(lazyLoadMembers: true).toJson()),
            )
            .timeout(const Duration(seconds: 15));

        // Build a lightweight temporary Room for event construction
        final tempRoom = Room(
          id: widget.room.id,
          client: client,
          membership: Membership.leave,
          prev_batch: resp.end,
        );

        rawEvents =
            resp.chunk
                .map(
                  (matrixEvent) => Event.fromMatrixEvent(matrixEvent, tempRoom),
                )
                .where(
                  (e) =>
                      e.type == 'm.room.message' &&
                      e.relationshipType != RelationshipTypes.reference &&
                      e.relationshipType != RelationshipTypes.thread &&
                      e.relationshipType != RelationshipTypes.edit,
                )
                .toList();
      }

      if (!mounted) return;

      final posts =
          rawEvents
              .map((e) => (origEvent: e, displayEvent: e))
              .take(20)
              .toList();

      setState(() {
        _posts = posts;
        _isLoadingPosts = false;
        _cannotPeek = false;
      });
    } on MatrixException catch (e) {
      if (!mounted) return;
      // 403 = room is not world_readable / no peek access
      debugPrint('RoomPreviewSheet: MatrixException peeking room: $e');
      setState(() {
        _isLoadingPosts = false;
        _cannotPeek = true;
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingPosts = false;
        _cannotPeek = true;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('RoomPreviewSheet: Error loading posts: $e');
      setState(() {
        _isLoadingPosts = false;
        _cannotPeek = true;
      });
    }
  }

  Future<void> _handleJoin() async {
    setState(() => _isJoining = true);
    try {
      await widget.onJoin(widget.room.id);
      if (!mounted) return;
      setState(() {
        _joined = true;
        _isJoining = false;
      });
      // Reload posts now that we have joined
      await _loadPosts();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isJoining = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleLeave() async {
    setState(() => _isLeaving = true);
    try {
      await widget.onLeave(widget.room.id);
      if (!mounted) return;
      setState(() {
        _joined = false;
        _isLeaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLeaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    final fallback = CircleAvatar(
      radius: 28,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        widget.room.name.isNotEmpty ? widget.room.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    );

    if (widget.room.avatarUrl != null &&
        widget.room.avatarUrl!.startsWith('mxc://')) {
      return SizedBox(
        width: 56,
        height: 56,
        child: ClipOval(
          child: MxcImage(
            uri: Uri.parse(widget.room.avatarUrl!),
            client: client,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            isThumbnail: true,
            placeholder: (_) => fallback,
            errorBuilder: (_, _) => fallback,
          ),
        ),
      );
    }
    return fallback;
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    final isInsideSubstitution = widget.room.isInsideSubstitution;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(colorScheme),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.room.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.room.topic != null &&
                    widget.room.topic!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.room.topic!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (widget.room.numJoinedMembers != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'settings.room_preview.members'.tr(
                          args: [widget.room.numJoinedMembers.toString()],
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Join / Leave button
          if (_isJoining || _isLeaving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_joined && isInsideSubstitution)
            IconButton(
              icon: Icon(Icons.person_remove_rounded, color: colorScheme.error),
              tooltip: 'settings.room.leave'.tr(),
              onPressed: _handleLeave,
            )
          else
            FilledButton.tonal(
              onPressed: _handleJoin,
              child: Text('settings.room.join_short'.tr()),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoadingPosts) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: PostSkeletonList(count: 3),
      );
    }

    if (_cannotPeek) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'settings.room_preview.no_peek'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (!_joined) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isJoining ? null : _handleJoin,
                icon:
                    _isJoining
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.person_add_rounded),
                label: Text('settings.room_preview.join_to_see'.tr()),
              ),
            ],
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'settings.room_preview.no_posts'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'settings.room_preview.latest_posts'.tr(),
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ..._posts.map(
          (post) => GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              context.push(
                Uri(
                  path: '/post/${post.origEvent.eventId}',
                  queryParameters: {'room': post.origEvent.roomId},
                ).toString(),
              );
            },
            child: PostWidget(
              event: post.origEvent,
              displayEvent: post.displayEvent,
              isDetailView: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header is outside the scroll so it stays pinned
              _buildHeader(theme, colorScheme),
              const Divider(height: 1),
              // Scrollable post list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [_buildContent(theme, colorScheme)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shows the [RoomPreviewSheet] as a modal bottom sheet.
Future<void> showRoomPreview({
  required BuildContext context,
  required SubstitutionRoom room,
  required Future<void> Function(String roomId) onJoin,
  required Future<void> Function(String roomId) onLeave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => MultiProvider(
          providers: [
            Provider<Client>.value(
              value: Provider.of<Client>(context, listen: false),
            ),
            ChangeNotifierProvider<SubstitutionService>.value(
              value: Provider.of<SubstitutionService>(context, listen: false),
            ),
          ],
          child: RoomPreviewSheet(room: room, onJoin: onJoin, onLeave: onLeave),
        ),
  );
}
