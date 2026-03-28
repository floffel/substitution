import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/matrix.dart' as matrix_lib;
import 'package:provider/provider.dart';

import '/settings/widgets/user_search_field.dart';
import '/shared/services/substitution_service.dart';
import '/shared/widgets/avatar.dart';
import '/shared/widgets/mxc_image.dart';

/// Full-page form to create a new room or edit an existing one.
///
/// Pass [roomId] to enter edit mode (existing room), omit it for create mode.
///
/// TODO(decompose): This class is large (~1500 lines). Planned extractions:
/// - `RoomAvatarPicker` widget (lines ~1146–1237 + state fields)
/// - `RoomBasicInfoForm` widget (name/alias/topic fields)
/// - `RoomSettingsSection` widget (visibility/encryption/blog-mode toggles)
/// - `RoomMembersSection` widget (member list, kick/ban/power-level)
/// - `RoomDangerZone` widget (delete room)
/// - `RoomFormController` ChangeNotifier (data loading + save/create logic)
class RoomFormPage extends StatefulWidget {
  /// The Matrix room ID to edit. When `null` the page is in create mode.
  final String? roomId;

  const RoomFormPage({super.key, this.roomId});

  bool get isCreateMode => roomId == null;

  @override
  State<RoomFormPage> createState() => _RoomFormPageState();
}

class _RoomFormPageState extends State<RoomFormPage> {
  // ── Providers ─────────────────────────────────────────────────────────
  Client get client => Provider.of<Client>(context, listen: false);

  // ── Form state ────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _aliasController;
  late final TextEditingController _topicController;

  // Avatar
  XFile? _pickedAvatarFile;
  Uri? _existingAvatarUrl; // mxc:// from existing room (edit mode)

  // Settings toggles
  bool? _isPublic = false; // defaults to private in create mode
  bool? _isEncrypted; // null = unset in create mode
  bool _isBlogMode = false;
  bool _isSubstitutionRoom = true; // default to true for create mode

  // Invite
  List<String> _inviteUserIds = [];

  // Edit-mode data
  Room? _room;
  List<User> _members = [];
  List<User> _bannedMembers = [];
  bool _isLoadingRoom = false;
  String? _loadError;

  // Submission
  bool _isSaving = false;

  // For identifying which encryption state we're in during edit
  bool _alreadyEncrypted = false;
  bool _originalIsSubstitutionRoom = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _aliasController = TextEditingController();
    _topicController = TextEditingController();

    if (!widget.isCreateMode) {
      _loadRoomData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  // ── Data loading (edit mode) ──────────────────────────────────────────

  Future<void> _loadRoomData() async {
    setState(() {
      _isLoadingRoom = true;
      _loadError = null;
    });

    try {
      final room = client.getRoomById(widget.roomId!);
      if (room == null) {
        setState(() {
          _loadError = 'settings.room_form.room_not_found'.tr();
          _isLoadingRoom = false;
        });
        return;
      }

      // Power levels
      final powerLevelEvent = room.getState('m.room.power_levels');
      final powerLevelContent =
          powerLevelEvent != null
              ? Map<String, dynamic>.from(powerLevelEvent.content)
              : <String, dynamic>{};
      final eventsDefault = powerLevelContent['events_default'] ?? 0;
      final isBlog = (eventsDefault as num).toInt() >= 50;

      // Join rules (public/private)
      final joinRulesEvent = room.getState('m.room.join_rules');
      final joinRule =
          joinRulesEvent?.content['join_rule'] as String? ?? 'public';
      final isPublic = joinRule == 'public';

      // Encryption
      final encryptionEvent = room.getState('m.room.encryption');
      final isEncrypted = encryptionEvent != null;

      // Avatar
      final avatarUrl = room.avatar;

      // Alias
      final canonicalAlias = room.canonicalAlias;
      String aliasLocal = '';
      if (canonicalAlias.startsWith('#')) {
        aliasLocal = canonicalAlias.split(':').first.replaceFirst('#', '');
      }

      // Substitution room status
      final substitutionService = Provider.of<SubstitutionService>(
        context,
        listen: false,
      );
      await substitutionService.init();
      final isSubstitution = substitutionService.isSubstitutionRoom(
        widget.roomId!,
      );

      // Members
      final members = room.getParticipants();
      final activeMembers =
          members
              .where(
                (m) =>
                    m.membership == Membership.join ||
                    m.membership == Membership.invite,
              )
              .toList();
      final bannedMembers =
          members.where((m) => m.membership == Membership.ban).toList();

      setState(() {
        _room = room;
        _nameController.text = room.name;
        _topicController.text = room.topic;
        _aliasController.text = aliasLocal;
        _existingAvatarUrl = avatarUrl;
        _isBlogMode = isBlog;
        _isPublic = isPublic;
        _isEncrypted = isEncrypted;
        _alreadyEncrypted = isEncrypted;
        _isSubstitutionRoom = isSubstitution;
        _originalIsSubstitutionRoom = isSubstitution;
        _members = activeMembers;
        _bannedMembers = bannedMembers;
        _isLoadingRoom = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'settings.room_form.load_error'.tr(args: ['$e']);
        _isLoadingRoom = false;
      });
    }
  }

  // ── Avatar picker ─────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    const imageTypes = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [imageTypes]);
    if (file != null) {
      setState(() => _pickedAvatarFile = file);
    }
  }

  // ── Submission ────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (widget.isCreateMode) {
        await _createRoom();
      } else {
        await _saveRoom();
      }
    } catch (e) {
      if (!mounted) return;
      _showRetrySnackbar(
        widget.isCreateMode
            ? 'settings.room_form.create_error'.tr()
            : 'settings.room_form.save_error'.tr(args: ['$e']),
        onRetry: _submit,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _createRoom() async {
    final alias =
        _aliasController.text.trim().isNotEmpty
            ? _aliasController.text.trim()
            : null;

    // Build initial state events
    final List<StateEvent> initialState = [];

    if (_isEncrypted == true) {
      initialState.add(
        StateEvent(
          content: {'algorithm': 'm.megolm.v1.aes-sha2'},
          type: 'm.room.encryption',
        ),
      );
    }

    // Blog mode: set events_default to 50 via power levels
    if (_isBlogMode) {
      initialState.add(
        StateEvent(
          content: {
            'ban': 50,
            'kick': 50,
            'redact': 50,
            'invite': 50,
            'events_default': 50,
            'state_default': 50,
            'users_default': 0,
            'events': <String, dynamic>{},
            'users': <String, dynamic>{},
          },
          type: 'm.room.power_levels',
        ),
      );
    }

    final roomId = await client.createRoom(
      isDirect: false,
      name: _nameController.text.trim(),
      topic:
          _topicController.text.trim().isNotEmpty
              ? _topicController.text.trim()
              : null,
      roomAliasName: alias,
      visibility:
          _isPublic == true
              ? matrix_lib.Visibility.public
              : matrix_lib.Visibility.private,
      preset:
          _isPublic == true
              ? CreateRoomPreset.publicChat
              : CreateRoomPreset.privateChat,
      invite: _inviteUserIds,
      initialState: initialState.isNotEmpty ? initialState : null,
    );

    // Wait for room to appear in sync
    final room = client.getRoomById(roomId);
    if (room == null || room.membership != Membership.join) {
      await client.waitForRoomInSync(roomId, join: true);
    }

    // Upload avatar if selected
    if (_pickedAvatarFile != null) {
      try {
        final bytes = await _pickedAvatarFile!.readAsBytes();
        final matrixFile = MatrixFile(
          bytes: bytes,
          name: _pickedAvatarFile!.name,
        );
        final createdRoom = client.getRoomById(roomId);
        if (createdRoom != null) {
          await createdRoom.setAvatar(matrixFile);
        }
      } catch (_) {
        // Avatar upload failure is non-fatal; room was already created.
      }
    }

    // Mark as substitution room (server + local cache)
    await client.setAccountDataPerRoom(client.userID!, roomId, 'substitution', {
      'joined': true,
    });
    if (mounted) {
      final substitutionService = Provider.of<SubstitutionService>(
        context,
        listen: false,
      );
      substitutionService.addRoomId(roomId);
      substitutionService.triggerRefresh();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('settings.room_form.create_success'.tr()),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop(true);
  }

  Future<void> _saveRoom() async {
    if (_room == null) return;

    // Collect changes and apply them.
    final errors = <String>[];

    // Name
    if (_nameController.text.trim() != _room!.name) {
      try {
        await _room!.setName(_nameController.text.trim());
      } catch (e) {
        errors.add('Name: $e');
      }
    }

    // Topic
    final newTopic = _topicController.text.trim();
    if (newTopic != _room!.topic) {
      try {
        await client.setRoomStateWithKey(_room!.id, 'm.room.topic', '', {
          'topic': newTopic,
        });
      } catch (e) {
        errors.add('Topic: $e');
      }
    }

    // Avatar
    if (_pickedAvatarFile != null) {
      try {
        final bytes = await _pickedAvatarFile!.readAsBytes();
        final matrixFile = MatrixFile(
          bytes: bytes,
          name: _pickedAvatarFile!.name,
        );
        await _room!.setAvatar(matrixFile);
      } catch (e) {
        errors.add('Avatar: $e');
      }
    }

    // Visibility (join rules)
    if (_isPublic != null) {
      final currentIsPublic =
          (_room!.getState('m.room.join_rules')?.content['join_rule'] ??
              'public') ==
          'public';
      if (_isPublic != currentIsPublic) {
        try {
          await client.setRoomStateWithKey(_room!.id, 'm.room.join_rules', '', {
            'join_rule': _isPublic! ? 'public' : 'invite',
          });
        } catch (e) {
          errors.add('Visibility: $e');
        }
      }
    }

    // Encryption (one-way: can only enable, never disable)
    if (_isEncrypted == true && !_alreadyEncrypted) {
      try {
        await client.setRoomStateWithKey(_room!.id, 'm.room.encryption', '', {
          'algorithm': 'm.megolm.v1.aes-sha2',
        });
      } catch (e) {
        errors.add('Encryption: $e');
      }
    }

    // Posting mode (power levels)
    final powerLevelEvent = _room!.getState('m.room.power_levels');
    final powerContent =
        powerLevelEvent != null
            ? Map<String, dynamic>.from(powerLevelEvent.content)
            : <String, dynamic>{};
    final currentEventsDefault =
        (powerContent['events_default'] as num?)?.toInt() ?? 0;
    final wantedEventsDefault = _isBlogMode ? 50 : 0;
    if (currentEventsDefault != wantedEventsDefault) {
      try {
        final updated = Map<String, dynamic>.from(powerContent);
        updated['events_default'] = wantedEventsDefault;
        await client.setRoomStateWithKey(
          _room!.id,
          'm.room.power_levels',
          '',
          updated,
        );
      } catch (e) {
        errors.add('Posting mode: $e');
      }
    }

    // Substitution room status
    if (_isSubstitutionRoom != _originalIsSubstitutionRoom) {
      try {
        await client.setAccountDataPerRoom(
          client.userID!,
          _room!.id,
          'substitution',
          _isSubstitutionRoom ? {'joined': true} : {},
        );
        if (mounted) {
          final substitutionService = Provider.of<SubstitutionService>(
            context,
            listen: false,
          );
          if (_isSubstitutionRoom) {
            substitutionService.addRoomId(_room!.id);
          } else {
            substitutionService.removeRoomId(_room!.id);
          }
          substitutionService.triggerRefresh();
        }
      } catch (e) {
        errors.add('Substitution status: $e');
      }
    }

    if (!mounted) return;

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.room_form.save_error'.tr(args: [errors.join('; ')]),
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Retry', onPressed: _submit),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.room_form.save_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    }
  }

  // ── Member actions ────────────────────────────────────────────────────

  Future<void> _kickMember(User member) async {
    final reason = await _showReasonDialog(
      title: 'settings.room_form.kick_confirm_title'.tr(),
      body: 'settings.room_form.kick_confirm_body'.tr(
        args: [member.displayName ?? member.id],
      ),
      actionLabel: 'settings.room_form.kick_action'.tr(),
      reasonHint: 'settings.room_form.kick_reason_hint'.tr(),
      isDestructive: true,
    );
    if (reason == null) return; // cancelled

    try {
      await _room!.kick(member.id);
      if (!mounted) return;
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
      await _loadRoomData();
    } catch (e) {
      if (!mounted) return;
      _showRetrySnackbar(
        'settings.room_form.member_action_error'.tr(args: ['$e']),
        onRetry: () => _kickMember(member),
      );
    }
  }

  Future<void> _banMember(User member) async {
    final reason = await _showReasonDialog(
      title: 'settings.room_form.ban_confirm_title'.tr(),
      body: 'settings.room_form.ban_confirm_body'.tr(
        args: [member.displayName ?? member.id],
      ),
      actionLabel: 'settings.room_form.ban_action'.tr(),
      reasonHint: 'settings.room_form.ban_reason_hint'.tr(),
      isDestructive: true,
    );
    if (reason == null) return; // cancelled

    try {
      await _room!.ban(member.id);
      if (!mounted) return;
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
      await _loadRoomData();
    } catch (e) {
      if (!mounted) return;
      _showRetrySnackbar(
        'settings.room_form.member_action_error'.tr(args: ['$e']),
        onRetry: () => _banMember(member),
      );
    }
  }

  Future<void> _unbanMember(User member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('settings.room_form.unban_confirm_title'.tr()),
            content: Text(
              'settings.room_form.unban_confirm_body'.tr(
                args: [member.displayName ?? member.id],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('settings.room_form.unban_action'.tr()),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await _room!.unban(member.id);
      if (!mounted) return;
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
      await _loadRoomData();
    } catch (e) {
      if (!mounted) return;
      _showRetrySnackbar(
        'settings.room_form.member_action_error'.tr(args: ['$e']),
        onRetry: () => _unbanMember(member),
      );
    }
  }

  Future<void> _setPowerLevel(User member, int level) async {
    try {
      await _room!.setPower(member.id, level);
      if (!mounted) return;
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
      await _loadRoomData();
    } catch (e) {
      if (!mounted) return;
      _showRetrySnackbar(
        'settings.room_form.member_action_error'.tr(args: ['$e']),
        onRetry: () => _setPowerLevel(member, level),
      );
    }
  }

  Future<void> _deleteRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: Icon(
              Icons.warning_rounded,
              color: Theme.of(ctx).colorScheme.error,
              size: 32,
            ),
            title: Text('settings.room_form.delete_confirm_title'.tr()),
            content: Text(
              'settings.room_form.delete_confirm_body'.tr(
                args: [_room?.name ?? ''],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('settings.room_form.delete_action'.tr()),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await _room!.leave();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.room_form.delete_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      _showRetrySnackbar(
        'settings.room_form.delete_error'.tr(args: ['$e']),
        onRetry: _deleteRoom,
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

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

  /// Shows a confirmation dialog with an optional reason text field.
  /// Returns the reason string if confirmed, or `null` if cancelled.
  Future<String?> _showReasonDialog({
    required String title,
    required String body,
    required String actionLabel,
    required String reasonHint,
    bool isDestructive = false,
  }) async {
    final reasonController = TextEditingController();
    final theme = Theme.of(context);

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

    if (confirmed != true) {
      reasonController.dispose();
      return null;
    }
    final reason = reasonController.text;
    reasonController.dispose();
    return reason;
  }

  String _roleLabel(int powerLevel) {
    if (powerLevel >= 100) return 'settings.room_form.member_role_admin'.tr();
    if (powerLevel >= 50) {
      return 'settings.room_form.member_role_moderator'.tr();
    }
    return 'settings.room_form.member_role_user'.tr();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditMode = !widget.isCreateMode;
    final isAdmin = _room == null || _room!.ownPowerLevel >= 100;

    // Edit mode: show loading/error states
    if (isEditMode && _isLoadingRoom) {
      return Scaffold(
        appBar: AppBar(title: Text('settings.room_form.title_edit'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (isEditMode && _loadError != null) {
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
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: _loadRoomData,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isCreateMode
              ? 'settings.room_form.title_create'.tr()
              : 'settings.room_form.title_edit'.tr(),
        ),
        actions: [
          if (!_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _submit,
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
            // ── Avatar ─────────────────────────────────────────────────
            const SizedBox(height: 24),
            Center(child: _buildAvatar(colorScheme, theme)),
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

            // ── Basic info ─────────────────────────────────────────────
            _buildSectionCard(
              theme: theme,
              title: 'settings.room_form.section_basic'.tr(),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'settings.room_form.name_label'.tr(),
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'settings.room_form.name_required'.tr();
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aliasController,
                  decoration: InputDecoration(
                    labelText: 'settings.room_form.alias_label'.tr(),
                    hintText: 'settings.room_form.alias_hint'.tr(),
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    // Show the homeserver suffix inline so users understand
                    // what the full alias will look like.
                    suffixText:
                        ':${client.userID?.split(':').last ?? 'homeserver'}',
                    prefixText: '#',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null; // optional
                    final valid = RegExp(r'^[a-z0-9._=\-/]+$').hasMatch(v);
                    if (!valid) {
                      return 'settings.room_form.alias_invalid'.tr();
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    labelText: 'settings.room_form.topic_label'.tr(),
                    hintText: 'settings.room_form.topic_hint'.tr(),
                    prefixIcon: const Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  minLines: 2,
                  textInputAction: TextInputAction.newline,
                ),
              ],
            ),

            // ── Server info (create mode only) ─────────────────────────
            if (widget.isCreateMode) ...[
              _buildSectionCard(
                theme: theme,
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

            // ── Settings ───────────────────────────────────────────────
            _buildSectionCard(
              theme: theme,
              title: 'settings.room_form.section_settings'.tr(),
              children: [
                // Visibility
                _buildToggleTile(
                  theme: theme,
                  colorScheme: colorScheme,
                  icon:
                      _isPublic == true
                          ? Icons.public_rounded
                          : Icons.lock_outline_rounded,
                  title: 'settings.room_form.visibility_label'.tr(),
                  subtitle:
                      _isPublic == true
                          ? 'settings.room_form.visibility_public_desc'.tr()
                          : 'settings.room_form.visibility_private_desc'.tr(),
                  value: _isPublic ?? false,
                  tristate: false,
                  onChanged: (v) => setState(() => _isPublic = v),
                ),
                const Divider(height: 1),

                // Encryption
                if (_alreadyEncrypted)
                  ListTile(
                    leading: Icon(
                      Icons.lock_rounded,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      'settings.room_form.encryption_label'.tr(),
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      'settings.room_form.encryption_already_on'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    trailing: Icon(
                      Icons.check_circle_rounded,
                      color: colorScheme.primary,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildToggleTile(
                        theme: theme,
                        colorScheme: colorScheme,
                        icon:
                            _isEncrypted == true
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                        title: 'settings.room_form.encryption_label'.tr(),
                        subtitle: 'settings.room_form.encryption_desc'.tr(),
                        value: _isEncrypted ?? false,
                        tristate: widget.isCreateMode && _isEncrypted == null,
                        onChanged: (v) => setState(() => _isEncrypted = v),
                      ),
                      if (_isEncrypted == true)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: colorScheme.tertiary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'settings.room_form.encryption_warning'.tr(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.tertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                const Divider(height: 1),

                // Substitution room toggle (edit mode only)
                if (isEditMode) ...[
                  _buildToggleTile(
                    theme: theme,
                    colorScheme: colorScheme,
                    icon:
                        _isSubstitutionRoom
                            ? Icons.dynamic_feed_rounded
                            : Icons.dynamic_feed_outlined,
                    title: 'settings.room_form.substitution_label'.tr(),
                    subtitle:
                        _isSubstitutionRoom
                            ? 'settings.room_form.substitution_on_desc'.tr()
                            : 'settings.room_form.substitution_off_desc'.tr(),
                    value: _isSubstitutionRoom,
                    onChanged: (v) => setState(() => _isSubstitutionRoom = v),
                  ),
                  const Divider(height: 1),
                ],

                // Posting mode
                _buildToggleTile(
                  theme: theme,
                  colorScheme: colorScheme,
                  icon:
                      _isBlogMode ? Icons.edit_off_rounded : Icons.edit_rounded,
                  title: 'settings.room_form.posting_mode_label'.tr(),
                  subtitle:
                      _isBlogMode
                          ? 'settings.room_form.posting_blog_desc'.tr()
                          : 'settings.room_form.posting_community_desc'.tr(),
                  value: _isBlogMode,
                  onChanged: (v) => setState(() => _isBlogMode = v),
                ),
              ],
            ),

            // ── Invite Users (only in create mode, or edit-admin mode) ──
            _buildSectionCard(
              theme: theme,
              title: 'settings.room_form.section_invite'.tr(),
              children: [
                UserSearchField(
                  selectedUserIds: _inviteUserIds,
                  onChanged: (ids) => setState(() => _inviteUserIds = ids),
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

            // ── Members (edit mode only) ────────────────────────────────
            if (isEditMode) ...[
              _buildSectionCard(
                theme: theme,
                title: 'settings.room_form.section_members'.tr(),
                children: [
                  if (_members.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'settings.room_form.members_empty'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _members.length,
                      itemBuilder:
                          (ctx, i) =>
                              _buildMemberTile(theme, colorScheme, _members[i]),
                    ),
                ],
              ),

              // ── Banned members ──────────────────────────────────────
              _buildSectionCard(
                theme: theme,
                title: 'settings.room_form.section_banned'.tr(),
                children: [
                  if (_bannedMembers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'settings.room_form.banned_empty'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _bannedMembers.length,
                      itemBuilder:
                          (ctx, i) => _buildBannedMemberTile(
                            theme,
                            colorScheme,
                            _bannedMembers[i],
                          ),
                    ),
                ],
              ),

              // ── Danger zone ─────────────────────────────────────────
              _buildDangerZone(theme, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────

  Widget _buildAvatar(ColorScheme colorScheme, ThemeData theme) {
    Widget avatarContent;

    if (_pickedAvatarFile != null) {
      avatarContent = FutureBuilder<Uint8List>(
        future: _pickedAvatarFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return CircleAvatar(
              radius: 52,
              backgroundImage: MemoryImage(snapshot.data!),
            );
          }
          return _defaultAvatarCircle(colorScheme);
        },
      );
    } else if (_existingAvatarUrl != null) {
      avatarContent = SizedBox(
        width: 104,
        height: 104,
        child: ClipOval(
          child: MxcImage(
            uri: _existingAvatarUrl!,
            client: client,
            width: 104,
            height: 104,
            fit: BoxFit.cover,
            placeholder: (_) => _defaultAvatarCircle(colorScheme),
            errorBuilder: (_, _) => _defaultAvatarCircle(colorScheme),
          ),
        ),
      );
    } else {
      avatarContent = _defaultAvatarCircle(colorScheme);
    }

    return Stack(
      children: [
        avatarContent,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.camera_alt_rounded,
                color: colorScheme.onPrimary,
                size: 18,
              ),
              onPressed: _pickAvatar,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatarCircle(ColorScheme colorScheme) {
    final name = _nameController.text;
    return CircleAvatar(
      radius: 52,
      backgroundColor: colorScheme.primaryContainer,
      child:
          name.isNotEmpty
              ? Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              )
              : Icon(
                Icons.groups_rounded,
                size: 40,
                color: colorScheme.onPrimaryContainer,
              ),
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool tristate = false,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: colorScheme.primary),
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildMemberTile(
    ThemeData theme,
    ColorScheme colorScheme,
    User member,
  ) {
    if (_room == null) return const SizedBox.shrink();
    final powerLevel = _room!.getPowerLevelByUserId(member.id);
    final isSelf = member.id == client.userID;
    final ownPowerLevel = _room!.ownPowerLevel;

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
                onSelected: (action) async {
                  switch (action) {
                    case 'user':
                      await _setPowerLevel(member, 0);
                    case 'mod':
                      await _setPowerLevel(member, 50);
                    case 'admin':
                      await _setPowerLevel(member, 100);
                    case 'kick':
                      await _kickMember(member);
                    case 'ban':
                      await _banMember(member);
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

  Widget _buildBannedMemberTile(
    ThemeData theme,
    ColorScheme colorScheme,
    User member,
  ) {
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
        onPressed: () => _unbanMember(member),
      ),
    );
  }

  Widget _buildDangerZone(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: colorScheme.errorContainer.withValues(alpha: 0.15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'settings.room_form.section_danger'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                  label: Text('settings.room_form.delete_room'.tr()),
                  onPressed: _deleteRoom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(int powerLevel, ColorScheme colorScheme) {
    if (powerLevel >= 100) return colorScheme.error;
    if (powerLevel >= 50) return colorScheme.tertiary;
    return colorScheme.onSurfaceVariant;
  }
}
