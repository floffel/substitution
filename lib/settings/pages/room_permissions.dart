import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// Room Permissions Page - allows admins to configure room power levels and posting permissions
class RoomPermissionsPage extends StatefulWidget {
  final String roomId;

  const RoomPermissionsPage({required this.roomId, super.key});

  @override
  State<RoomPermissionsPage> createState() => _RoomPermissionsPageState();
}

class _RoomPermissionsPageState extends State<RoomPermissionsPage> {
  Client get client => Provider.of<Client>(context, listen: false);
  Room? room;
  bool isLoading = true;
  Map<String, dynamic> powerLevelState = {};
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    try {
      setState(() => isLoading = true);
      room = client.getRoomById(widget.roomId);

      if (room == null) {
        setState(() {
          errorMessage = 'Room not found';
          isLoading = false;
        });
        return;
      }

      // Check if user is admin (power >= 100)
      if (room!.ownPowerLevel < 100) {
        setState(() {
          errorMessage =
              'You do not have permission to manage room permissions';
          isLoading = false;
        });
        return;
      }

      // Load power level state
      final powerLevelEvent = room!.getState('m.room.power_levels');
      if (powerLevelEvent != null) {
        powerLevelState = Map<String, dynamic>.from(powerLevelEvent.content);
      } else {
        // Initialize with default power levels
        powerLevelState = {
          'ban': 50,
          'kick': 50,
          'redact': 50,
          'invite': 50,
          'events_default': 0,
          'state_default': 50,
          'users_default': 0,
          'events': {},
          'users': {},
        };
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading room: $e';
        isLoading = false;
      });
    }
  }

  bool get isBlogMode => (powerLevelState['events_default'] ?? 0) >= 50;

  Future<void> _toggleMode(bool isBlog) async {
    try {
      final updatedState = Map<String, dynamic>.from(powerLevelState);
      updatedState['events_default'] = isBlog ? 50 : 0;

      // Use the correct method to set room state
      await room!.client.setRoomStateWithKey(
        room!.id,
        'm.room.power_levels',
        '',
        updatedState,
      );

      setState(() => powerLevelState = updatedState);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBlog
                  ? 'Switched to Blog mode (admins only)'
                  : 'Switched to Community mode (anyone can post)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating permissions: $e')),
        );
      }
    }
  }

  Future<void> _setMemberPowerLevel(String userId, int level) async {
    try {
      await room!.setPower(userId, level);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Power level updated for $userId')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating power level: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Permissions')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Permissions')),
        body: Center(child: Text(errorMessage!)),
      );
    }

    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Permissions')),
        body: const Center(child: Text('Room not found')),
      );
    }

    // Check if user is admin
    final isAdmin = room!.ownPowerLevel >= 100;

    return Scaffold(
      appBar: AppBar(title: Text(room!.name)),
      body: isAdmin ? _buildAdminView() : _buildReadOnlyView(),
    );
  }

  Widget _buildAdminView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blog/Community Mode Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Posting Permissions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isBlogMode ? 'Blog Mode' : 'Community Mode',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                isBlogMode
                                    ? 'Only admins can post'
                                    : 'Anyone can post',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(value: isBlogMode, onChanged: _toggleMode),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Members Section
            const Text(
              'Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMembersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Posting Permissions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBlogMode ? 'Blog Mode' : 'Community Mode',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              isBlogMode
                                  ? 'Only admins can post'
                                  : 'Anyone can post',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          isBlogMode ? Icons.lock : Icons.lock_open,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildReadOnlyMembersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    if (room == null || room!.states.isEmpty) {
      return const Center(child: Text('No members'));
    }

    final members = room!.getParticipants();
    if (members.isEmpty) {
      return const Center(child: Text('No members'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final powerLevel = room!.getPowerLevelByUserId(member.id);

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                member.displayName != null && member.displayName!.isNotEmpty
                    ? member.displayName!.characters.first.toUpperCase()
                    : member.id.characters.first,
              ),
            ),
            title: Text(member.displayName ?? member.id),
            subtitle: Text('Power Level: $powerLevel'),
            trailing: PopupMenuButton<int>(
              onSelected: (level) => _setMemberPowerLevel(member.id, level),
              itemBuilder:
                  (BuildContext context) => [
                    const PopupMenuItem(value: 0, child: Text('User (0)')),
                    const PopupMenuItem(
                      value: 50,
                      child: Text('Moderator (50)'),
                    ),
                    const PopupMenuItem(value: 100, child: Text('Admin (100)')),
                  ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadOnlyMembersList() {
    if (room == null || room!.states.isEmpty) {
      return const Center(child: Text('No members'));
    }

    final members = room!.getParticipants();
    if (members.isEmpty) {
      return const Center(child: Text('No members'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final powerLevel = room!.getPowerLevelByUserId(member.id);

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                member.displayName != null && member.displayName!.isNotEmpty
                    ? member.displayName!.characters.first.toUpperCase()
                    : member.id.characters.first,
              ),
            ),
            title: Text(member.displayName ?? member.id),
            subtitle: Text('Power Level: $powerLevel'),
          ),
        );
      },
    );
  }
}
