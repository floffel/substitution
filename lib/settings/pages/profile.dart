import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:substitution/settings/widgets/dialog_delete_account.dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
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
        await client.setProfileField(
          client.userID!,
          'displayname',
          {'displayname': _displayNameController.text},
        );
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
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to update profile: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar
                Center(
                  child: Stack(
                    children: [
                      if (_selectedAvatarFile != null)
                        FutureBuilder<Uint8List>(
                          future: _selectedAvatarFile!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return CircleAvatar(
                                radius: 60,
                                backgroundImage: MemoryImage(snapshot.data!),
                              );
                            }
                            return const CircleAvatar(
                              radius: 60,
                              child: Icon(Icons.person, size: 60),
                            );
                          },
                        )
                      else if (_currentProfile?.avatarUrl != null)
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: NetworkImage(
                            _currentProfile!.avatarUrl!
                                .getDownloadUri(
                                    Provider.of<Client>(context, listen: false))
                                .toString(),
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: 60,
                          child: Text(
                            _currentProfile?.displayName?.isNotEmpty ?? false
                                ? _currentProfile!.displayName![0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: FloatingActionButton(
                          mini: true,
                          onPressed: _pickAvatar,
                          child: const Icon(Icons.camera_alt),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Display Name
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Display name cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Profile'),
                ),
                const SizedBox(height: 64),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete Account'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const DialogDeleteAccount(),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
