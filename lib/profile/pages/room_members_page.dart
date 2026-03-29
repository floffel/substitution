import '/shared/widgets/avatar.dart';
import '/shared/extensions/go_router_extensions.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

/// Displays the full member list for a given room.
///
/// Shows each member with their avatar, display name, Matrix ID, and role.
/// Tapping a member opens their profile page.
class RoomMembersPage extends StatefulWidget {
  const RoomMembersPage({super.key, required this.roomId});

  final String roomId;

  @override
  State<RoomMembersPage> createState() => _RoomMembersPageState();
}

class _RoomMembersPageState extends State<RoomMembersPage> {
  Client get client => Provider.of<Client>(context, listen: false);

  late Future<List<User>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  Future<List<User>> _loadMembers() async {
    final room = client.getRoomById(widget.roomId);
    if (room == null) return [];
    final participants = room.getParticipants();
    // Sort: admins first, then moderators, then users; within each group alphabetically.
    participants.sort((a, b) {
      final plA = room.getPowerLevelByUserId(a.id);
      final plB = room.getPowerLevelByUserId(b.id);
      if (plA != plB) return plB.compareTo(plA); // higher power first
      return (a.displayName ?? a.id).compareTo(b.displayName ?? b.id);
    });
    return participants.where((u) => u.membership == Membership.join).toList();
  }

  String _roleLabel(int powerLevel) {
    if (powerLevel >= 100) return 'settings.room_form.member_role_admin'.tr();
    if (powerLevel >= 50) {
      return 'settings.room_form.member_role_moderator'.tr();
    }
    return 'settings.room_form.member_role_user'.tr();
  }

  Color _roleColor(int powerLevel, ColorScheme cs) {
    if (powerLevel >= 100) return cs.error;
    if (powerLevel >= 50) return cs.tertiary;
    return cs.onSurfaceVariant.withValues(alpha: 0.6);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final room = client.getRoomById(widget.roomId);
    final memberCount = room?.summary.mJoinedMemberCount;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'members.title'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (memberCount != null)
              Text(
                'members.count'.tr(args: [memberCount.toString()]),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: FutureBuilder<List<User>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'members.error'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final members = snapshot.data ?? [];
          if (members.isEmpty) {
            return Center(child: Text('members.empty'.tr()));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: members.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = members[index];
              final powerLevel = room?.getPowerLevelByUserId(user.id) ?? 0;
              final roleLbl = _roleLabel(powerLevel);
              final roleClr = _roleColor(powerLevel, colorScheme);

              return ListTile(
                leading: Avatar(
                  mxContent: user.avatarUrl,
                  name: user.displayName ?? user.id,
                  client: client,
                  size: 40,
                ),
                title: Text(
                  user.displayName ?? user.id,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  user.id,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing:
                    powerLevel >= 50
                        ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: roleClr.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            roleLbl,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: roleClr,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        : null,
                onTap:
                    () => context.pushIfNew(
                      '/profile/${Uri.encodeComponent(user.id)}',
                    ),
              );
            },
          );
        },
      ),
    );
  }
}
