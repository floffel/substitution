import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '/shared/extensions/client_extensions.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Client get client => Provider.of<Client>(context, listen: false);

  late Future<Profile> _profileFuture;
  late Future<List<Room>> _roomsFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = client.getProfileFromUserId(widget.userId);
    _roomsFuture = _fetchUserRooms();
  }

  Future<List<Room>> _fetchUserRooms() async {
    final rooms = <Room>[];
    final allRooms = client.rooms;

    for (final room in allRooms) {
      final powerLevel = room.getPowerLevelByUserId(widget.userId);
      if (powerLevel >= 50) {
        // Check if room is in substitution (user's feeds)
        final isInSubstitution = await client.isRoomInSubstitution(room.id);
        if (isInSubstitution) {
          rooms.add(room);
        }
      }
    }

    return rooms;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (profileSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('User not found'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        }

        final profile = profileSnapshot.data!;

        return SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 60,
                      backgroundImage:
                          profile.avatarUrl != null
                              ? NetworkImage(
                                profile.avatarUrl!
                                    .getDownloadUri(client)
                                    .toString(),
                              )
                              : null,
                      child:
                          profile.avatarUrl == null
                              ? Text(
                                (profile.displayName ?? 'User')[0],
                                style: const TextStyle(fontSize: 32),
                              )
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // Display Name
                    Text(
                      profile.displayName ?? 'Unknown User',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),

                    // Matrix ID
                    Text(
                      widget.userId,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    // Rooms Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Rooms',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Rooms List
              FutureBuilder<List<Room>>(
                future: _roomsFuture,
                builder: (context, roomsSnapshot) {
                  if (roomsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (roomsSnapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Failed to load rooms',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }

                  final rooms = roomsSnapshot.data ?? [];

                  if (rooms.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No rooms found',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return ListTile(
                        title: Text(room.name),
                        subtitle: Text(room.id),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () {
                          final roomId =
                              room.canonicalAlias.isNotEmpty
                                  ? room.canonicalAlias.replaceAll('#', '')
                                  : room.id;
                          context.push('/feed/$roomId');
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
