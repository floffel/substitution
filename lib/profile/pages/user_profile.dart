import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '/shared/extensions/client_extensions.dart';
import '/shared/extensions/go_router_extensions.dart';
import '/shared/widgets/avatar.dart';
import '/shared/utils/share_helper.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Client get client => Provider.of<Client>(context, listen: false);

  late Future<Profile> _profileFuture;
  late Future<List<Room>> _roomsFuture;
  bool _isStartingChat = false;

  bool get _isOwnProfile => widget.userId == client.userID;

  @override
  void initState() {
    super.initState();
    _profileFuture = client.getProfileFromUserId(widget.userId);
    _roomsFuture = _fetchUserRooms();
  }

  Future<List<Room>> _fetchUserRooms() async {
    final rooms = <Room>[];
    final allRooms = client.rooms;

    for (final room in allRooms) {
      final powerLevel = room.getPowerLevelByUserId(widget.userId);
      if (powerLevel >= 50) {
        final isInSubstitution = await client.isRoomInSubstitution(room.id);
        if (isInSubstitution) {
          rooms.add(room);
        }
      }
    }

    return rooms;
  }

  // ── Send Message ──────────────────────────────────────────────────────────

  Future<void> _startDirectChat() async {
    setState(() => _isStartingChat = true);
    try {
      final roomId = await client.startDirectChat(widget.userId);
      if (!mounted) return;
      context.push('/chat/${Uri.encodeComponent(roomId)}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile.error_start_chat'.tr(args: [e.toString()])),
        ),
      );
    } finally {
      if (mounted) setState(() => _isStartingChat = false);
    }
  }

  // ── Block User ────────────────────────────────────────────────────────────

  void _showBlockDialog(Profile profile) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('profile.block_title'.tr()),
            content: Text(
              'profile.block_desc'.tr(
                args: [profile.displayName ?? widget.userId],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _blockUser();
                },
                child: Text('profile.block_confirm'.tr()),
              ),
            ],
          ),
    );
  }

  Future<void> _blockUser() async {
    try {
      await client.ignoreUser(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('profile.block_success'.tr())));
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.block_error'.tr(args: [e.toString()]))),
      );
    }
  }

  // ── Report User ───────────────────────────────────────────────────────────

  void _showReportDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('profile.report_title'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('profile.report_desc'.tr()),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'profile.report_reason'.tr(),
                    hintText: 'profile.report_reason_hint'.tr(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('profile.report_success'.tr())),
                  );
                },
                child: Text('profile.report_submit'.tr()),
              ),
            ],
          ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<Profile>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (profileSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: colorScheme.error.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text('User not found', style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        }

        final profile = profileSnapshot.data!;

        return SingleChildScrollView(
          child: Column(
            children: [
              // --- Profile Header ---
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.4),
                      colorScheme.surface.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Avatar(
                        mxContent: profile.avatarUrl,
                        name: profile.displayName ?? 'User',
                        client: client,
                        size: 104,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display Name
                    Text(
                      profile.displayName ?? 'Unknown User',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Matrix ID chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.userId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Share Button ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed:
                        () => ShareHelper.shareProfile(context, widget.userId),
                    icon: Icon(
                      Icons.share_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'share.share_profile'.tr(),
                  ),
                ),
              ),

              // --- Action Buttons (only for other users) ---
              if (!_isOwnProfile) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Send Message (primary, takes most space)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isStartingChat ? null : _startDirectChat,
                          icon:
                              _isStartingChat
                                  ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                  : const Icon(Icons.message_rounded, size: 18),
                          label: Text('profile.send_message'.tr()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Block (icon-only outlined button)
                      Tooltip(
                        message: 'profile.block_title'.tr(),
                        child: OutlinedButton(
                          onPressed: () => _showBlockDialog(profile),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.error,
                            side: BorderSide(
                              color: colorScheme.error.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.all(12),
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Icon(Icons.block_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Report (icon-only outlined button)
                      Tooltip(
                        message: 'profile.report_title'.tr(),
                        child: OutlinedButton(
                          onPressed: _showReportDialog,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Icon(Icons.flag_outlined, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 8),

              // --- Feeds Section ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'profile.feeds_section'.tr(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Rooms List
              FutureBuilder<List<Room>>(
                future: _roomsFuture,
                builder: (context, roomsSnapshot) {
                  if (roomsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (roomsSnapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Failed to load feeds',
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }

                  final rooms = roomsSnapshot.data ?? [];

                  if (rooms.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 40,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'profile.no_feeds'.tr(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: colorScheme.secondaryContainer,
                              child: Text(
                                room.name.isNotEmpty
                                    ? room.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            title: Text(
                              room.name,
                              style: theme.textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              room.id,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_rounded,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                              size: 20,
                            ),
                            onTap: () {
                              final roomId =
                                  room.canonicalAlias.isNotEmpty
                                      ? room.canonicalAlias.replaceAll('#', '')
                                      : room.id;
                              context.pushIfNew('/feed/$roomId');
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
