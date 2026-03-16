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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: colorScheme.error.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text('User not found', style: theme.textTheme.titleMedium),
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
              // --- Profile Header with gradient background ---
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.4),
                      colorScheme.surface.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: colorScheme.primaryContainer,
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
                                  style: theme.textTheme.headlineLarge
                                      ?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display Name
                    Text(
                      profile.displayName ?? 'Unknown User',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Matrix ID as a chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.userId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // --- Rooms Section ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Rooms',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

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
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }

                  final rooms = roomsSnapshot.data ?? [];

                  if (rooms.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 40,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No rooms found',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: colorScheme.secondaryContainer,
                              child: Text(
                                room.name.isNotEmpty
                                    ? room.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            title: Text(
                              room.name,
                              style: theme.textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              room.id,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_rounded,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                              size: 20,
                            ),
                            onTap: () {
                              final roomId =
                                  room.canonicalAlias.isNotEmpty
                                      ? room.canonicalAlias.replaceAll('#', '')
                                      : room.id;
                              context.push('/feed/$roomId');
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
