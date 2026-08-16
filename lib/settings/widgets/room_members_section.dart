import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '/shared/widgets/avatar.dart';
import 'form_section_card.dart';

/// Edit-mode-only members and banned-members sections of the room form.
///
/// Stateless and callback-driven: the parent owns the [User] lists (which
/// it refreshes by re-loading the room after any kick/ban/power-level
/// change) and implements the actual server-side mutations.
class RoomMembersSection extends StatelessWidget {
  const RoomMembersSection({
    super.key,
    required this.members,
    required this.bannedMembers,
    required this.room,
    required this.client,
    required this.onSetPowerLevel,
    required this.onKickMember,
    required this.onBanMember,
    required this.onUnbanMember,
  });

  /// Active + invited members of the room.
  final List<User> members;

  /// Members currently banned from the room.
  final List<User> bannedMembers;

  /// The room being edited. Used to look up power levels. If `null`,
  /// member tiles render as empty (the parent should pass `null` only
  /// during the brief loading window before the room has been loaded).
  final Room? room;

  /// Matrix client for avatar resolution + own-user checks.
  final Client client;

  /// Invoked when the user picks a new power level (0 = user, 50 = mod,
  /// 100 = admin) from a member's overflow menu.
  final void Function(User member, int newPowerLevel) onSetPowerLevel;

  /// Invoked when the user picks "Kick" from a member's overflow menu.
  final void Function(User member) onKickMember;

  /// Invoked when the user picks "Ban" from a member's overflow menu.
  final void Function(User member) onBanMember;

  /// Invoked when the user taps "Unban" on a banned member row.
  final void Function(User member) onUnbanMember;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FormSectionCard(
          title: 'settings.room_form.section_members'.tr(),
          children: [
            if (members.isEmpty)
              const _EmptyMessage(keyValue: 'settings.room_form.members_empty')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                itemBuilder:
                    (ctx, i) => MemberTile(
                      member: members[i],
                      room: room,
                      client: client,
                      onSetPowerLevel: onSetPowerLevel,
                      onKickMember: onKickMember,
                      onBanMember: onBanMember,
                    ),
              ),
          ],
        ),
        FormSectionCard(
          title: 'settings.room_form.section_banned'.tr(),
          children: [
            if (bannedMembers.isEmpty)
              const _EmptyMessage(keyValue: 'settings.room_form.banned_empty')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bannedMembers.length,
                itemBuilder:
                    (ctx, i) => BannedMemberTile(
                      member: bannedMembers[i],
                      client: client,
                      onUnban: () => onUnbanMember(bannedMembers[i]),
                    ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One member row with an avatar, name, role chip, and an overflow menu
/// for power-level / kick / ban actions.
class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    required this.room,
    required this.client,
    required this.onSetPowerLevel,
    required this.onKickMember,
    required this.onBanMember,
  });

  final User member;
  final Room? room;
  final Client client;
  final void Function(User member, int newPowerLevel) onSetPowerLevel;
  final void Function(User member) onKickMember;
  final void Function(User member) onBanMember;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (room == null) return const SizedBox.shrink();
    final int powerLevel = room!.getPowerLevelByUserId(member.id).level;
    final isSelf = member.id == client.userID;
    final int ownPowerLevel = room!.ownPowerLevel.level;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Avatar(
        mxContent: member.avatarUrl,
        name: member.displayName ?? member.id,
        client: client,
        size: 40,
      ),
      title: Text(
        member.displayName ?? member.id,
        style: theme.textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _roleColor(
                powerLevel,
                colorScheme,
              ).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _roleLabel(powerLevel),
              style: theme.textTheme.labelSmall?.copyWith(
                color: _roleColor(powerLevel, colorScheme),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      trailing:
          isSelf
              ? null
              : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) {
                  switch (action) {
                    case 'user':
                      onSetPowerLevel(member, 0);
                    case 'mod':
                      onSetPowerLevel(member, 50);
                    case 'admin':
                      onSetPowerLevel(member, 100);
                    case 'kick':
                      onKickMember(member);
                    case 'ban':
                      onBanMember(member);
                  }
                },
                itemBuilder:
                    (ctx) => [
                      PopupMenuItem(
                        value: 'user',
                        enabled: powerLevel != 0 && ownPowerLevel > powerLevel,
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('settings.room_form.member_role_user'.tr()),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'mod',
                        enabled: powerLevel != 50 && ownPowerLevel >= 50,
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'settings.room_form.member_role_moderator'.tr(),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'admin',
                        enabled: powerLevel != 100 && ownPowerLevel >= 100,
                        child: Row(
                          children: [
                            const Icon(Icons.shield_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('settings.room_form.member_role_admin'.tr()),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'kick',
                        enabled: ownPowerLevel > powerLevel,
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_remove_outlined,
                              size: 18,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'settings.room_form.member_kick'.tr(),
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'ban',
                        enabled: ownPowerLevel > powerLevel,
                        child: Row(
                          children: [
                            Icon(
                              Icons.block_rounded,
                              size: 18,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'settings.room_form.member_ban'.tr(),
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
    );
  }
}

/// One banned-member row with an avatar, name, full userId subtitle,
/// and an "Unban" button on the trailing side.
class BannedMemberTile extends StatelessWidget {
  const BannedMemberTile({
    super.key,
    required this.member,
    required this.client,
    required this.onUnban,
  });

  final User member;
  final Client client;
  final VoidCallback onUnban;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Avatar(
        mxContent: member.avatarUrl,
        name: member.displayName ?? member.id,
        client: client,
        size: 40,
      ),
      title: Text(
        member.displayName ?? member.id,
        style: theme.textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        member.id,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
        ),
        icon: const Icon(Icons.lock_open_rounded, size: 16),
        label: Text('settings.room_form.member_unban'.tr()),
        onPressed: onUnban,
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.keyValue});
  final String keyValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        keyValue.tr(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Color of the role chip — admin (red), moderator (tertiary), user (muted).
Color _roleColor(int powerLevel, ColorScheme colorScheme) {
  if (powerLevel >= 100) return colorScheme.error;
  if (powerLevel >= 50) return colorScheme.tertiary;
  return colorScheme.onSurfaceVariant;
}

/// Localized role label for the chip.
String _roleLabel(int powerLevel) {
  if (powerLevel >= 100) return 'settings.room_form.member_role_admin'.tr();
  if (powerLevel >= 50) {
    return 'settings.room_form.member_role_moderator'.tr();
  }
  return 'settings.room_form.member_role_user'.tr();
}
