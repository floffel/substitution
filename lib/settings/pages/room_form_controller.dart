import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:matrix/matrix.dart' as matrix;
import 'package:matrix/matrix.dart';

import '/shared/services/substitution_service.dart';

/// Data + save/create logic for the room form, extracted from
/// `_RoomFormPageState` so the page can become a thin shell that just
/// wires the controller to the UI.
///
/// The controller is **UI-context-free**: it never holds a `BuildContext`
/// and never shows snackbars / dialogs / navigates. Methods that need
/// user interaction (e.g. the kick/ban reason dialog) take a
/// [RoomFormPrompter] from the caller — the page implements the prompts
/// and the controller does the work. Errors are surfaced via the
/// `loadError` / `lastError` fields and the boolean return values, so
/// the page can decide how to present them.
///
/// Listens to the controller via `ListenableBuilder` / `provider`'s
/// `ListenableProvider` and rebuilds when state changes.
class RoomFormController extends ChangeNotifier {
  RoomFormController({required Client client, required this.isCreateMode})
    : _client = client {
    // Seed default values for create mode.
    if (isCreateMode) {
      _isPublic = false; // private by default
      _isSubstitutionRoom = true; // true by default for new rooms
    }
  }

  final Client _client;
  final bool isCreateMode;

  // ── Identity (edit mode only) ──────────────────────────────────────

  /// The Matrix room ID when in edit mode, `null` for create mode.
  String? get roomId => _room?.id;

  // ── Text controllers ──────────────────────────────────────────────

  final nameController = TextEditingController();
  final aliasController = TextEditingController();
  final topicController = TextEditingController();

  // ── Avatar ─────────────────────────────────────────────────────────

  XFile? _pickedAvatarFile;
  Uri? _existingAvatarUrl;

  XFile? get pickedAvatarFile => _pickedAvatarFile;
  Uri? get existingAvatarUrl => _existingAvatarUrl;

  /// Opens the platform file picker filtered to image types. The
  /// selected file is stashed in [pickedAvatarFile]; the controller
  /// does not upload anything until [submit] is called.
  Future<void> pickAvatar() async {
    const imageTypes = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [imageTypes]);
    if (file != null) {
      _pickedAvatarFile = file;
      notifyListeners();
    }
  }

  // ── Settings toggles ──────────────────────────────────────────────

  bool? _isPublic = false;
  bool? get isPublic => _isPublic;
  set isPublic(bool? v) {
    if (_isPublic == v) return;
    _isPublic = v;
    notifyListeners();
  }

  bool? _isEncrypted;
  bool? get isEncrypted => _isEncrypted;
  set isEncrypted(bool? v) {
    if (_isEncrypted == v) return;
    _isEncrypted = v;
    notifyListeners();
  }

  bool _isBlogMode = false;
  bool get isBlogMode => _isBlogMode;
  set isBlogMode(bool v) {
    if (_isBlogMode == v) return;
    _isBlogMode = v;
    notifyListeners();
  }

  bool _isSubstitutionRoom = true;
  bool get isSubstitutionRoom => _isSubstitutionRoom;
  set isSubstitutionRoom(bool v) {
    if (_isSubstitutionRoom == v) return;
    _isSubstitutionRoom = v;
    notifyListeners();
  }

  // ── Edit-mode internal state ──────────────────────────────────────

  /// `true` once we've loaded the existing room. Encryption can only
  /// be enabled (not disabled), so once it's on we render a read-only
  /// "already on" tile.
  bool _alreadyEncrypted = false;
  bool get alreadyEncrypted => _alreadyEncrypted;

  /// The substitution-room value as it was on the server when we
  /// loaded the room. Used to detect a toggle in [_saveRoom].
  bool _originalIsSubstitutionRoom = false;

  // ── Edit-mode loaded data ─────────────────────────────────────────

  Room? _room;
  Room? get room => _room;
  List<User> _members = [];
  List<User> get members => List.unmodifiable(_members);
  List<User> _bannedMembers = [];
  List<User> get bannedMembers => List.unmodifiable(_bannedMembers);

  bool _isLoadingRoom = false;
  bool get isLoadingRoom => _isLoadingRoom;

  String? _loadError;
  String? get loadError => _loadError;

  // ── Submission ─────────────────────────────────────────────────────

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// Holds the most recent error message from a save / create operation.
  /// Cleared at the start of each new [submit] call. The page reads this
  /// to show a snackbar / dialog with retry.
  String? _lastError;
  String? get lastError => _lastError;

  // ── Invite list (create mode) ─────────────────────────────────────

  List<String> _inviteUserIds = [];
  List<String> get inviteUserIds => List.unmodifiable(_inviteUserIds);

  void setInviteUserIds(List<String> ids) {
    _inviteUserIds = List.of(ids);
    notifyListeners();
  }

  // ── Data loading (edit mode) ──────────────────────────────────────

  /// Loads the existing room (and its state events) into this
  /// controller. Idempotent — safe to call from "retry" buttons.
  ///
  /// [substitutionService] is injected (and may be `null` in test
  /// environments that don't provide one). The page resolves it from
  /// `Provider.of<SubstitutionService>(context)` when available; if
  /// absent, the substitution toggle is left at its create-mode default
  /// (`true`) and the user can still edit the room normally.
  Future<void> loadRoom({
    required String roomId,
    required SubstitutionService? substitutionService,
  }) async {
    if (roomId.isEmpty) {
      _loadError = 'settings.room_form.room_not_found';
      notifyListeners();
      return;
    }

    _isLoadingRoom = true;
    _loadError = null;
    notifyListeners();

    try {
      final room = _client.getRoomById(roomId);
      if (room == null) {
        _loadError = 'settings.room_form.room_not_found';
        _isLoadingRoom = false;
        notifyListeners();
        return;
      }

      // Power levels → blog mode flag.
      final powerLevelEvent = room.getState('m.room.power_levels');
      final powerLevelContent =
          powerLevelEvent != null
              ? Map<String, dynamic>.from(powerLevelEvent.content)
              : <String, dynamic>{};
      final eventsDefault = powerLevelContent['events_default'] ?? 0;
      final isBlog = (eventsDefault as num).toInt() >= 50;

      // Join rules → public flag.
      final joinRulesEvent = room.getState('m.room.join_rules');
      final joinRule =
          joinRulesEvent?.content['join_rule'] as String? ?? 'public';
      final isPublic = joinRule == 'public';

      // Encryption (one-way).
      final encryptionEvent = room.getState('m.room.encryption');
      final isEncrypted = encryptionEvent != null;

      // Alias (strip the leading "#" and the ":server" suffix so the
      // user sees the editable localpart).
      final canonicalAlias = room.canonicalAlias;
      String aliasLocal = '';
      if (canonicalAlias.startsWith('#')) {
        aliasLocal = canonicalAlias.split(':').first.replaceFirst('#', '');
      }

      // Substitution room status (from local cache, if available).
      bool isSubstitution = true; // create-mode default
      if (substitutionService != null) {
        try {
          await substitutionService.init();
          isSubstitution = substitutionService.isSubstitutionRoom(roomId);
        } catch (e) {
          debugPrint('SubstitutionService lookup failed (non-fatal): $e');
        }
      }

      // Members / banned.
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

      _room = room;
      nameController.text = room.name;
      topicController.text = room.topic;
      aliasController.text = aliasLocal;
      _existingAvatarUrl = room.avatar;
      _isBlogMode = isBlog;
      _isPublic = isPublic;
      _isEncrypted = isEncrypted;
      _alreadyEncrypted = isEncrypted;
      _isSubstitutionRoom = isSubstitution;
      _originalIsSubstitutionRoom = isSubstitution;
      _members = activeMembers;
      _bannedMembers = bannedMembers;
      _isLoadingRoom = false;
      notifyListeners();
    } catch (e) {
      _loadError = '$e';
      _isLoadingRoom = false;
      notifyListeners();
    }
  }

  // ── Submission ─────────────────────────────────────────────────────

  /// Runs the create or save flow depending on [isCreateMode].
  /// Returns `true` on success (room created / saved and the page can
  /// pop), `false` if validation failed or an error occurred (in which
  /// case the page should consult [lastError]).
  ///
  /// [substitutionService] is optional (may be `null` in test/isolated
  /// views). When null, the substitution-status side of the create /
  /// save flow is skipped (e.g. the `addRoomId` / `removeRoomId` /
  /// `triggerRefresh` calls are no-ops).
  Future<bool> submit({
    required SubstitutionService? substitutionService,
  }) async {
    _lastError = null;
    _isSaving = true;
    notifyListeners();
    try {
      if (isCreateMode) {
        await _createRoom(substitutionService: substitutionService);
      } else {
        await _saveRoom(substitutionService: substitutionService);
      }
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _createRoom({
    required SubstitutionService? substitutionService,
  }) async {
    final alias =
        aliasController.text.trim().isNotEmpty
            ? aliasController.text.trim()
            : null;

    final initialState = <StateEvent>[];

    if (_isEncrypted == true) {
      initialState.add(
        StateEvent(
          content: {'algorithm': 'm.megolm.v1.aes-sha2'},
          type: 'm.room.encryption',
        ),
      );
    }

    // Blog mode: set events_default to 50 via power levels.
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

    final roomId = await _client.createRoom(
      isDirect: false,
      name: nameController.text.trim(),
      topic:
          topicController.text.trim().isNotEmpty
              ? topicController.text.trim()
              : null,
      roomAliasName: alias,
      visibility:
          _isPublic == true
              ? matrix.Visibility.public
              : matrix.Visibility.private,
      preset:
          _isPublic == true
              ? CreateRoomPreset.publicChat
              : CreateRoomPreset.privateChat,
      invite: _inviteUserIds,
      initialState: initialState.isNotEmpty ? initialState : null,
    );

    final room = _client.getRoomById(roomId);
    if (room == null || room.membership != Membership.join) {
      await _client.waitForRoomInSync(roomId, join: true);
    }

    // Upload avatar (non-fatal if it fails — room was already created).
    if (_pickedAvatarFile != null) {
      try {
        final bytes = await _pickedAvatarFile!.readAsBytes();
        final matrixFile = MatrixFile(
          bytes: bytes,
          name: _pickedAvatarFile!.name,
        );
        final createdRoom = _client.getRoomById(roomId);
        if (createdRoom != null) {
          await createdRoom.setAvatar(matrixFile);
        }
      } catch (e) {
        debugPrint('Avatar upload failed (non-fatal): $e');
      }
    }

    // Mark as substitution room (server + local cache).
    await _client.setAccountDataPerRoom(
      _client.userID!,
      roomId,
      'substitution',
      {'joined': true},
    );
    substitutionService?.addRoomId(roomId);
    substitutionService?.triggerRefresh();
  }

  Future<void> _saveRoom({
    required SubstitutionService? substitutionService,
  }) async {
    if (_room == null) {
      throw StateError('Cannot save: no room loaded.');
    }
    final room = _room!;

    // Collect per-field errors so we can show one consolidated message
    // if some succeeded and some failed.
    final errors = <String>[];

    // Name.
    if (nameController.text.trim() != room.name) {
      try {
        await room.setName(nameController.text.trim());
      } catch (e) {
        errors.add('Name: $e');
      }
    }

    // Topic.
    final newTopic = topicController.text.trim();
    if (newTopic != room.topic) {
      try {
        await _client.setRoomStateWithKey(room.id, 'm.room.topic', '', {
          'topic': newTopic,
        });
      } catch (e) {
        errors.add('Topic: $e');
      }
    }

    // Avatar.
    if (_pickedAvatarFile != null) {
      try {
        final bytes = await _pickedAvatarFile!.readAsBytes();
        final matrixFile = MatrixFile(
          bytes: bytes,
          name: _pickedAvatarFile!.name,
        );
        await room.setAvatar(matrixFile);
      } catch (e) {
        errors.add('Avatar: $e');
      }
    }

    // Visibility (join rules).
    if (_isPublic != null) {
      final currentIsPublic =
          (room.getState('m.room.join_rules')?.content['join_rule'] ??
              'public') ==
          'public';
      if (_isPublic != currentIsPublic) {
        try {
          await _client.setRoomStateWithKey(room.id, 'm.room.join_rules', '', {
            'join_rule': _isPublic! ? 'public' : 'invite',
          });
        } catch (e) {
          errors.add('Visibility: $e');
        }
      }
    }

    // Encryption (one-way: enable-only).
    if (_isEncrypted == true && !_alreadyEncrypted) {
      try {
        await _client.setRoomStateWithKey(room.id, 'm.room.encryption', '', {
          'algorithm': 'm.megolm.v1.aes-sha2',
        });
      } catch (e) {
        errors.add('Encryption: $e');
      }
    }

    // Posting mode (power levels).
    final powerLevelEvent = room.getState('m.room.power_levels');
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
        await _client.setRoomStateWithKey(
          room.id,
          'm.room.power_levels',
          '',
          updated,
        );
      } catch (e) {
        errors.add('Posting mode: $e');
      }
    }

    // Substitution status.
    if (_isSubstitutionRoom != _originalIsSubstitutionRoom) {
      try {
        await _client.setAccountDataPerRoom(
          _client.userID!,
          room.id,
          'substitution',
          _isSubstitutionRoom ? {'joined': true} : {},
        );
        if (_isSubstitutionRoom) {
          substitutionService?.addRoomId(room.id);
        } else {
          substitutionService?.removeRoomId(room.id);
        }
        substitutionService?.triggerRefresh();
      } catch (e) {
        errors.add('Substitution status: $e');
      }
    }

    if (errors.isNotEmpty) {
      // Surface as an exception so the page's catch block shows a
      // consolidated error snackbar.
      throw StateError(errors.join('; '));
    }
  }

  // ── Member actions ────────────────────────────────────────────────

  /// Kicks [member] from the room. Returns `true` on success.
  Future<bool> kickMember(User member) async {
    if (_room == null) return false;
    try {
      await _room!.kick(member.id);
      await _refreshMembers();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Bans [member] from the room. Returns `true` on success.
  Future<bool> banMember(User member) async {
    if (_room == null) return false;
    try {
      await _room!.ban(member.id);
      await _refreshMembers();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Unbans [member]. Returns `true` on success.
  Future<bool> unbanMember(User member) async {
    if (_room == null) return false;
    try {
      await _room!.unban(member.id);
      await _refreshMembers();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Sets [member]'s power level to [level] (0 = user, 50 = mod,
  /// 100 = admin). Returns `true` on success.
  Future<bool> setPowerLevel(User member, int level) async {
    if (_room == null) return false;
    try {
      await _room!.setPower(member.id, level);
      await _refreshMembers();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Leaves the room. Returns `true` on success.
  Future<bool> deleteRoom() async {
    if (_room == null) return false;
    try {
      await _room!.leave();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Re-fetches the member + banned lists from the room and notifies.
  /// Called after any successful moderation action so the UI reflects
  /// the new state without a full reload.
  Future<void> _refreshMembers() async {
    if (_room == null) return;
    final members = _room!.getParticipants();
    _members =
        members
            .where(
              (m) =>
                  m.membership == Membership.join ||
                  m.membership == Membership.invite,
            )
            .toList();
    _bannedMembers =
        members.where((m) => m.membership == Membership.ban).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    nameController.dispose();
    aliasController.dispose();
    topicController.dispose();
    super.dispose();
  }
}

/// UI-side-effect prompts the page implements for the controller.
/// The page is responsible for showing dialogs / snackbars / navigation;
/// the controller never holds a [BuildContext].
abstract class RoomFormPrompter {
  /// Asks the user for a reason + confirmation. Returns the reason if
  /// the user confirmed, or `null` if they cancelled.
  Future<String?> promptForReason({
    required String title,
    required String body,
    required String actionLabel,
    required String reasonHint,
    bool isDestructive = false,
  });

  /// Asks the user to confirm a destructive action. Returns `true`
  /// if the user confirmed, `false` otherwise.
  Future<bool> confirmDestructive({
    required String title,
    required String body,
    required String actionLabel,
  });
}
