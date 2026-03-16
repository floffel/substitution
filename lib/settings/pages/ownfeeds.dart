import '/settings/widgets/roomwidget.dart';
import '/settings/widgets/dialogcreateroom.dart';
import '/shared/extensions/client_extensions.dart';
import '/shared/models/substitution_room.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:matrix/matrix.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class OwnFeedSettings extends StatefulWidget {
  const OwnFeedSettings({super.key});

  static OwnFeedSettingsState of(BuildContext context) {
    return context.findAncestorStateOfType<OwnFeedSettingsState>()!;
  }

  @override
  OwnFeedSettingsState createState() => OwnFeedSettingsState();
}

class OwnFeedSettingsState extends State<OwnFeedSettings> {
  Client get client => Provider.of<Client>(context, listen: false);

  String selectedServer = "";

  List<SubstitutionRoom> data = [];

  @override
  void initState() {
    super.initState();
  }

  Future<List<SubstitutionRoom>> _getJoinedRooms() async {
    List<SubstitutionRoom> newData = [];

    for (String roomId in await client.getJoinedRooms()) {
      Room r = client.getRoomById(roomId)!;
      bool isInSubstitution = await client.isRoomInSubstitution(roomId);

      if (!isInSubstitution) {
        continue;
      }

      if (r.ownPowerLevel < 50) {
        continue;
      }

      newData.add(
        SubstitutionRoom(
          name: r.name,
          id: r.id,
          avatarUrl: r.avatar?.getDownloadUri(client).toString(),
          isInsideSubstitution: isInSubstitution,
          joined: true,
        ),
      );
    }

    return newData;
  }

  Future<Map<String, Object?>> get accountData async =>
      await client.getAccountData(client.userID!, "substitution.servers");

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rss_feed_rounded,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "settings.ownfeeds.header".tr(),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Create room button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.add_rounded),
              label: const Text("settings.ownfeeds.buttons.create_room").tr(),
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  barrierDismissible: true,
                  builder: (BuildContext context) {
                    return const DialogCreateRoom();
                  },
                );
                setState(() {});
              },
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Room list
        Expanded(
          child: FutureBuilder(
            future: _getJoinedRooms(),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No feeds yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (ctx, index) {
                  return RoomWidget(room: snapshot.data![index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
