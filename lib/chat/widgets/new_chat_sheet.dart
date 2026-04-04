import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '/shared/widgets/avatar.dart';

/// A modal bottom sheet that lets the user search for a Matrix user and start
/// a direct chat with them.
class NewChatSheet extends StatefulWidget {
  const NewChatSheet({super.key});

  @override
  State<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<NewChatSheet> {
  Client get client => Provider.of<Client>(context, listen: false);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Profile> _results = [];
  bool _isSearching = false;
  bool _isStartingChat = false;
  bool _hasError = false;
  String _lastQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Search ──────────────────────────────────────────────────────────────────

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
        // Filter out the current user from results.
        _results =
            resp.results.where((p) => p.userId != client.userID).toList();
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

  // ── Start Chat ──────────────────────────────────────────────────────────────

  Future<void> _startChat(Profile profile) async {
    setState(() => _isStartingChat = true);

    try {
      final roomId = await client.startDirectChat(profile.userId);
      if (!mounted) return;
      // Close the bottom sheet first, then navigate.
      Navigator.of(context).pop();
      context.push('/chat/${Uri.encodeComponent(roomId)}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStartingChat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('chat.error_start_chat'.tr(args: [e.toString()])),
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Drag handle ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'chat.new_chat'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_isStartingChat)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            // ── Search field ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                enabled: !_isStartingChat,
                decoration: InputDecoration(
                  hintText: 'chat.search_users'.tr(),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            const SizedBox(height: 8),

            // ── Results ─────────────────────────────────────────────────
            Expanded(
              child: _buildResultsArea(theme, colorScheme, scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultsArea(
    ThemeData theme,
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    // Error state
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              'chat.search_error'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _search(_searchController.text),
              child: Text('chat.retry'.tr()),
            ),
          ],
        ),
      );
    }

    // Empty query hint
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'chat.search_hint'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // No results
    if (!_isSearching && _results.isEmpty && _lastQuery.isNotEmpty) {
      return Center(
        child: Text(
          'chat.search_empty'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Results list
    return ListView.builder(
      controller: scrollController,
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final profile = _results[index];
        final displayName = profile.displayName ?? profile.userId;

        return ListTile(
          enabled: !_isStartingChat,
          leading: Avatar(
            mxContent: profile.avatarUrl,
            name: displayName,
            client: client,
            size: 44,
          ),
          title: Text(
            displayName,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            profile.userId,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(
            Icons.chat_bubble_outline_rounded,
            color: colorScheme.primary,
            size: 20,
          ),
          onTap: () => _startChat(profile),
        );
      },
    );
  }
}
