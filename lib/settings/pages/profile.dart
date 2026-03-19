import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:substitution/settings/widgets/dialog_delete_account.dart';
import '/shared/widgets/avatar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _displayNameController;
  Profile? _currentProfile;
  XFile? _selectedAvatarFile;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final client = Provider.of<Client>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await client.getProfileFromUserId(client.userID!);
      setState(() {
        _currentProfile = profile;
        _displayNameController.text = profile.displayName ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    }
  }

  Future<void> _pickAvatar() async {
    const XTypeGroup imageTypeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'png', 'gif', 'jpeg', 'webp'],
    );

    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[imageTypeGroup],
    );

    if (file != null) {
      setState(() {
        _selectedAvatarFile = file;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_displayNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty')),
      );
      return;
    }

    final client = Provider.of<Client>(context, listen: false);

    setState(() {
      _isSaving = true;
    });

    try {
      // Update display name if changed
      if (_displayNameController.text != (_currentProfile?.displayName ?? '')) {
        await client.setProfileField(client.userID!, 'displayname', {
          'displayname': _displayNameController.text,
        });
      }

      // Update avatar if a new file was selected
      if (_selectedAvatarFile != null) {
        final bytes = await _selectedAvatarFile!.readAsBytes();
        final matrixFile = MatrixFile(
          bytes: bytes,
          name: _selectedAvatarFile!.name,
        );
        await client.setAvatar(matrixFile);
      }

      setState(() {
        _isSaving = false;
        _selectedAvatarFile = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                icon: Icon(
                  Icons.error_outline_rounded,
                  color: Theme.of(ctx).colorScheme.error,
                  size: 32,
                ),
                title: const Text('Error'),
                content: Text('Failed to update profile: $e'),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  Widget _buildAvatar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget avatarContent;

    if (_selectedAvatarFile != null) {
      avatarContent = FutureBuilder<Uint8List>(
        future: _selectedAvatarFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return CircleAvatar(
              radius: 56,
              backgroundImage: MemoryImage(snapshot.data!),
            );
          }
          return CircleAvatar(
            radius: 56,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person_rounded,
              size: 56,
              color: colorScheme.primary,
            ),
          );
        },
      );
    } else if (_currentProfile?.avatarUrl != null) {
      avatarContent = Avatar(
        mxContent: _currentProfile!.avatarUrl,
        name: _currentProfile?.displayName,
        client: Provider.of<Client>(context, listen: false),
        size: 112,
      );
    } else {
      avatarContent = CircleAvatar(
        radius: 56,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          _currentProfile?.displayName?.isNotEmpty ?? false
              ? _currentProfile!.displayName![0].toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Avatar section
        const SizedBox(height: 16),
        Center(child: _buildAvatar()),
        if (_currentProfile?.avatarUrl != null || _selectedAvatarFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'Tap the camera to change',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        const SizedBox(height: 32),

        // Profile info card
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Information',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Display name cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon:
                        _isSaving
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Danger zone
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: colorScheme.errorContainer.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                      'Danger Zone',
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
                    label: const Text('Delete Account'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const DialogDeleteAccount(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
