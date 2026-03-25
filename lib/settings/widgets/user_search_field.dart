import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import '/shared/widgets/avatar.dart';

/// A user search input that shows autocomplete results from the Matrix user
/// directory and lets the caller collect a list of invited users as chips.
class UserSearchField extends StatefulWidget {
  /// Currently selected / invited user IDs.
  final List<String> selectedUserIds;

  /// Called when the user adds or removes an invitee.
  final void Function(List<String> updatedIds) onChanged;

  const UserSearchField({
    super.key,
    required this.selectedUserIds,
    required this.onChanged,
  });

  @override
  State<UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends State<UserSearchField> {
  Client get client => Provider.of<Client>(context, listen: false);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Profile> _results = [];
  bool _isSearching = false;
  bool _hasError = false;
  String _lastQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _hasError = false;
        _lastQuery = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query == _lastQuery) return;
    _lastQuery = query;

    setState(() {
      _isSearching = true;
      _hasError = false;
    });

    try {
      final resp = await client.searchUserDirectory(query, limit: 10);
      if (!mounted) return;
      setState(() {
        _results = resp.results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _hasError = true;
      });
    }
  }

  void _addUser(Profile profile) {
    if (widget.selectedUserIds.contains(profile.userId)) return;
    final updated = [...widget.selectedUserIds, profile.userId];
    widget.onChanged(updated);
    _searchController.clear();
    setState(() {
      _results = [];
      _lastQuery = '';
    });
    _focusNode.requestFocus();
  }

  void _removeUser(String userId) {
    final updated = widget.selectedUserIds.where((id) => id != userId).toList();
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Selected user chips ──────────────────────────────────────────
        if (widget.selectedUserIds.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children:
                widget.selectedUserIds.map((userId) {
                  return InputChip(
                    avatar: Avatar(
                      mxContent: null,
                      name: userId,
                      client: client,
                      size: 24,
                    ),
                    label: Text(
                      _displayNameFor(userId),
                      style: theme.textTheme.bodySmall,
                    ),
                    onDeleted: () => _removeUser(userId),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
          ),
          const SizedBox(height: 8),
        ],

        // ── Search text field ────────────────────────────────────────────
        TextFormField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'settings.room_form.invite_search_hint'.tr(),
            prefixIcon: const Icon(Icons.person_search_rounded),
            suffixIcon:
                _isSearching
                    ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _results = [];
                          _lastQuery = '';
                          _hasError = false;
                        });
                      },
                    )
                    : null,
          ),
          onChanged: _onSearchChanged,
        ),

        // ── Results / error ──────────────────────────────────────────────
        if (_hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: () => _search(_searchController.text),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'settings.room_form.invite_search_error'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final profile = _results[index];
                final alreadyAdded = widget.selectedUserIds.contains(
                  profile.userId,
                );
                return ListTile(
                  dense: true,
                  leading: Avatar(
                    mxContent: profile.avatarUrl,
                    name: profile.displayName ?? profile.userId,
                    client: client,
                    size: 36,
                  ),
                  title: Text(
                    profile.displayName ?? profile.userId,
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    profile.userId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing:
                      alreadyAdded
                          ? Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          )
                          : Icon(
                            Icons.add_circle_outline_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                  onTap: alreadyAdded ? null : () => _addUser(profile),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              },
            ),
          )
        else if (!_isSearching &&
            _searchController.text.isNotEmpty &&
            _lastQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'settings.room_form.invite_empty'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  /// Returns the display name for a selected user, looking it up from
  /// search results first (for freshly-added users) then falling back to
  /// the raw Matrix ID.
  String _displayNameFor(String userId) {
    final match = _results.where((p) => p.userId == userId).firstOrNull;
    if (match?.displayName != null) return match!.displayName!;
    // Try the Matrix ID in a readable format: @name:server → "name"
    final localPart = userId.split(':').first.replaceFirst('@', '');
    return localPart.isNotEmpty ? localPart : userId;
  }
}
