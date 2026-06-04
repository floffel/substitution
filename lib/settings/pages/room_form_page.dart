import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import '/settings/widgets/form_section_card.dart';
import '/settings/widgets/room_avatar_picker.dart';
import '/settings/widgets/room_basic_info_form.dart';
import '/settings/widgets/room_danger_zone.dart';
import '/settings/widgets/room_members_section.dart';
import '/settings/widgets/room_settings_section.dart';
import '/settings/widgets/user_search_field.dart';
import '/shared/services/substitution_service.dart';
import 'room_form_controller.dart';

/// Full-page form to create a new room or edit an existing one.
///
/// Pass [roomId] to enter edit mode (existing room), omit it for create
/// mode. The page is a thin shell: it owns a [RoomFormController], wraps
/// it in a [ListenableBuilder], and delegates the actual save logic to
/// the controller. All UI side effects (snackbars, dialogs, navigation)
/// stay in the page because the controller is intentionally
/// `BuildContext`-free.
///
/// Extracted to `lib/settings/widgets/`:
/// - `RoomAvatarPicker` (avatar with camera overlay)
/// - `RoomBasicInfoForm` (name / alias / topic)
/// - `RoomSettingsSection` (visibility / encryption / substitution / blog)
/// - `RoomMembersSection` (active members + banned members)
/// - `RoomDangerZone` (delete room)
/// - `FormSectionCard` + `FormToggleTile` (shared building blocks)
///
/// State and data are owned by `RoomFormController`
/// (`lib/settings/pages/room_form_controller.dart`).
class RoomFormPage extends StatefulWidget {
  /// The Matrix room ID to edit. When `null` the page is in create mode.
  final String? roomId;

  const RoomFormPage({super.key, this.roomId});

  bool get isCreateMode => roomId == null;

  @override
  State<RoomFormPage> createState() => _RoomFormPageState();
}

class _RoomFormPageState extends State<RoomFormPage> implements RoomFormPrompter {
  // ── Controller ──────────────────────────────────────────────────────
  late final RoomFormController _controller;
  late final GlobalKey<FormState> _formKey;

  Client get client => Provider.of<Client>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _controller = RoomFormController(
      client: Provider.of<Client>(context, listen: false),
      isCreateMode: widget.isCreateMode,
    );
    _formKey = GlobalKey<FormState>();

    if (!widget.isCreateMode) {
      // Defer to first frame so we can read `Provider.of` for the
      // substitution service without a `context` at construction time.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // SubstitutionService is optional — tests and isolated views
        // may not have one. The controller falls back to the create-mode
        // default (true) when it's missing.
        SubstitutionService? service;
        try {
          service = Provider.of<SubstitutionService>(context, listen: false);
        } catch (_) {
          service = null;
        }
        _controller.loadRoom(
          roomId: widget.roomId!,
          substitutionService: service,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Submission ──────────────────────────────────────────────────────

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final service = _readSubstitutionService();
    final success = await _controller.submit(substitutionService: service);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isCreateMode
                ? 'settings.room_form.create_success'.tr()
                : 'settings.room_form.save_success'.tr(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (context.mounted) {
        // canPop() guards against the test / isolated case where the
        // form was pushed onto an empty stack; in that case fall back
        // to navigating home.
        if (GoRouter.of(context).canPop()) {
          context.pop(true);
        } else {
          context.go('/');
        }
      }
    } else {
      _showRetrySnackbar(
        widget.isCreateMode
            ? 'settings.room_form.create_error'.tr()
            : 'settings.room_form.save_error'
                .tr(args: [_controller.lastError ?? '']),
        onRetry: _onSubmit,
      );
    }
  }

  /// Looks up the optional [SubstitutionService] from the widget tree.
  /// Returns `null` when the service isn't provided (e.g. in unit tests
  /// or other isolated views). The controller falls back gracefully.
  SubstitutionService? _readSubstitutionService() {
    try {
      return Provider.of<SubstitutionService>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onDeleteRoom() async {
    final confirmed = await confirmDestructive(
      title: 'settings.room_form.delete_confirm_title'.tr(),
      body: 'settings.room_form.delete_confirm_body'.tr(
        args: [_controller.room?.name ?? ''],
      ),
      actionLabel: 'settings.room_form.delete_action'.tr(),
    );
    if (confirmed != true || !mounted) return;

    final ok = await _controller.deleteRoom();
    if (!ok || !mounted) {
      _showRetrySnackbar(
        'settings.room_form.delete_error'.tr(
          args: [_controller.lastError ?? ''],
        ),
        onRetry: _onDeleteRoom,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('settings.room_form.delete_success'.tr()),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (context.mounted) context.go('/');
  }

  // ── Member actions ──────────────────────────────────────────────────

  Future<void> _onKickMember(User member) async {
    final reason = await promptForReason(
      title: 'settings.room_form.kick_confirm_title'.tr(),
      body: 'settings.room_form.kick_confirm_body'.tr(
        args: [member.displayName ?? member.id],
      ),
      actionLabel: 'settings.room_form.kick_action'.tr(),
      reasonHint: 'settings.room_form.kick_reason_hint'.tr(),
      isDestructive: true,
    );
    if (reason == null) return;

    final ok = await _controller.kickMember(member);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.room_form.kick_success'.tr(
              args: [member.displayName ?? member.id],
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showRetrySnackbar(
        'settings.room_form.member_action_error'.tr(
          args: [_controller.lastError ?? ''],
        ),
        onRetry: () => _onKickMember(member),
      );
    }
  }

  Future<void> _onBanMember(User member) async {
    final reason = await promptForReason(
      title: 'settings.room_form.ban_confirm_title'.tr(),
      body: 'settings.room_form.ban_confirm_body'.tr(
        args: [member.displayName ?? member.id],
      ),
      actionLabel: 'settings.room_form.ban_action'.tr(),
      reasonHint: 'settings.room_form.ban_reason_hint'.tr(),
      isDestructive: true,
    );
    if (reason == null) return;

    final ok = await _controller.banMember(member);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.room_form.ban_success'.tr(
              args: [member.displayName ?? member.id],
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showRetrySnackbar(
        'settings.room_form.member_action_error'.tr(
          args: [_controller.lastError ?? ''],
        ),
        onRetry: () => _onBanMember(member),
      );
    }
  }

  Future<void> _onUnbanMember(User member) async {
    final confirmed = await confirmDestructive(
      title: 'settings.room_form.unban_confirm_title'.tr(),
      body: 'settings.room_form.unban_confirm_body'.tr(
        args: [member.displayName ?? member.id],
      ),
      actionLabel: 'settings.room_form.unban_action'.tr(),
    );
    if (confirmed != true) return;

    final ok = await _controller.unbanMember(member);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.room_form.unban_success'.tr(
              args: [member.displayName ?? member.id],
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showRetrySnackbar(
        'settings.room_form.member_action_error'.tr(
          args: [_controller.lastError ?? ''],
        ),
        onRetry: () => _onUnbanMember(member),
      );
    }
  }

  Future<void> _onSetPowerLevel(User member, int level) async {
    final ok = await _controller.setPowerLevel(member, level);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.room_form.power_level_success'.tr(
              args: [member.displayName ?? member.id],
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showRetrySnackbar(
        'settings.room_form.member_action_error'.tr(
          args: [_controller.lastError ?? ''],
        ),
        onRetry: () => _onSetPowerLevel(member, level),
      );
    }
  }

  // ── UI helpers ──────────────────────────────────────────────────────

  void _showRetrySnackbar(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action:
            onRetry != null
                ? SnackBarAction(label: 'Retry', onPressed: onRetry)
                : null,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  // ── RoomFormPrompter implementation ────────────────────────────────

  @override
  Future<String?> promptForReason({
    required String title,
    required String body,
    required String actionLabel,
    required String reasonHint,
    bool isDestructive = false,
  }) async {
    final reasonController = TextEditingController();
    final theme = Theme.of(context);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(body),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(hintText: reasonHint),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('cancel'.tr()),
                ),
                FilledButton(
                  style:
                      isDestructive
                          ? FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          )
                          : null,
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(actionLabel),
                ),
              ],
            ),
      );
      if (confirmed != true) return null;
      return reasonController.text;
    } finally {
      reasonController.dispose();
    }
  }

  @override
  Future<bool> confirmDestructive({
    required String title,
    required String body,
    required String actionLabel,
  }) async {
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: Icon(
              Icons.warning_rounded,
              color: theme.colorScheme.error,
              size: 32,
            ),
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(actionLabel),
              ),
            ],
          ),
    );
    return result == true;
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditMode = !widget.isCreateMode;
    final isAdmin =
        _controller.room == null || _controller.room!.ownPowerLevel >= 100;

    // ── Edit-mode loading / error / no-permission states ──────────────

    if (isEditMode && _controller.isLoadingRoom) {
      return Scaffold(
        appBar: AppBar(title: Text('settings.room_form.title_edit'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (isEditMode && _controller.loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text('settings.room_form.title_edit'.tr())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _controller.loadError!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: () {
                    SubstitutionService? service;
                    try {
                      service = Provider.of<SubstitutionService>(
                        context,
                        listen: false,
                      );
                    } catch (_) {
                      service = null;
                    }
                    _controller.loadRoom(
                      roomId: widget.roomId!,
                      substitutionService: service,
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isEditMode && !isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('settings.room_form.title_edit'.tr())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'settings.room_form.no_permission'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Main form ──────────────────────────────────────────────────────

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isCreateMode
              ? 'settings.room_form.title_create'.tr()
              : 'settings.room_form.title_edit'.tr(),
        ),
        actions: [
          if (!_controller.isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _onSubmit,
                icon: Icon(
                  widget.isCreateMode ? Icons.add_rounded : Icons.save_rounded,
                  size: 18,
                ),
                label: Text(
                  widget.isCreateMode
                      ? 'settings.room_form.create_button'.tr()
                      : 'settings.room_form.save_button'.tr(),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ── Avatar ─────────────────────────────────────────────
            const SizedBox(height: 24),
            Center(
              child: RoomAvatarPicker(
                pickedAvatarFile: _controller.pickedAvatarFile,
                existingAvatarUrl: _controller.existingAvatarUrl,
                nameFallback: _controller.nameController.text,
                client: client,
                onPickAvatar: _controller.pickAvatar,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'settings.room_form.avatar_hint'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Basic info ─────────────────────────────────────────
            FormSectionCard(
              title: 'settings.room_form.section_basic'.tr(),
              children: [
                RoomBasicInfoForm(
                  nameController: _controller.nameController,
                  aliasController: _controller.aliasController,
                  topicController: _controller.topicController,
                  homeserverSuffix: client.userID?.split(':').last,
                ),
              ],
            ),

            // ── Server info (create mode only) ───────────────────
            if (widget.isCreateMode) ...[
              FormSectionCard(
                title: 'settings.room_form.section_server'.tr(),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.dns_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'settings.room_form.server_info'.tr(
                                args: [
                                  client.userID?.split(':').last ??
                                      'your homeserver',
                                ],
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'settings.room_form.server_info_subtitle'.tr(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],

            // ── Settings ───────────────────────────────────────────
            RoomSettingsSection(
              isPublic: _controller.isPublic,
              onIsPublicChanged: (v) => _controller.isPublic = v,
              isEncrypted: _controller.isEncrypted,
              alreadyEncrypted: _controller.alreadyEncrypted,
              canChangeEncryption: !_controller.alreadyEncrypted,
              onIsEncryptedChanged: (v) => _controller.isEncrypted = v,
              isSubstitutionRoom: _controller.isSubstitutionRoom,
              onIsSubstitutionRoomChanged: (v) =>
                  _controller.isSubstitutionRoom = v,
              isBlogMode: _controller.isBlogMode,
              onIsBlogModeChanged: (v) => _controller.isBlogMode = v,
              isEditMode: isEditMode,
            ),

            // ── Invite Users ───────────────────────────────────────
            FormSectionCard(
              title: 'settings.room_form.section_invite'.tr(),
              children: [
                UserSearchField(
                  selectedUserIds: _controller.inviteUserIds,
                  onChanged: _controller.setInviteUserIds,
                ),
                if (widget.isCreateMode) ...[
                  const SizedBox(height: 8),
                  Text(
                    'settings.room_form.invite_note'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),

            // ── Members (edit mode only) ──────────────────────────
            if (isEditMode) ...[
              RoomMembersSection(
                members: _controller.members,
                bannedMembers: _controller.bannedMembers,
                room: _controller.room,
                client: client,
                onSetPowerLevel: _onSetPowerLevel,
                onKickMember: _onKickMember,
                onBanMember: _onBanMember,
                onUnbanMember: _onUnbanMember,
              ),

              // ── Danger zone ───────────────────────────────────
              RoomDangerZone(onDeleteRoom: _onDeleteRoom),
            ],
          ],
        ),
      ),
    );
  }
}
