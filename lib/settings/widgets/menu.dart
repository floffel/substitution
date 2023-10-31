import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// Define a custom Form widget.
class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  _MenuState createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  Client get client => Provider.of<Client>(context, listen: false);
  // Helper methods
  Future<Profile> get profile async =>
      (await client.fetchOwnProfileFromServer());
  Future<String?> get avatarURL async => (await profile).avatarUrl?.toString();
  Future<bool> get hasAvatarURL async => (await avatarURL) != null;
  Future<String> get username async => (await profile).displayName!;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
        onDestinationSelected: (int index) => {
              if (index == 0 && !client.isLogged())
                {
                  // login
                  context.push("/auth/host")
                }
              else if (index == 1)
                {
                  // Home
                  context.go("/")
                }
              else if (index == 2)
                {
                  // Feeds/Räume
                  context.push("/settings/feed")
                }
              else if (index == 3)
                {
                  // Settings
                  context.push("/settings/")
                }
            },
        children: [
          const SizedBox(height: 22),
          if (client.isLogged()) ...[
            NavigationDrawerDestination(
              icon: CircleAvatar(
                  child: FutureBuilder(
                      future: profile,
                      builder: (ctx, snapshot) {
                        if (snapshot.data == null) {
                          return const Text("...");
                        }
                        // TODO: check if image is svg
                        return snapshot.data?.avatarUrl == null
                            ? Text(snapshot.data!.displayName![0])
                            : Image.network(snapshot.data!.avatarUrl!
                                .getDownloadLink(client)
                                .toString());
                      })),
              label: Flex(direction: Axis.vertical, children: [
                const Spacer(),
                FutureBuilder(
                    future: profile,
                    builder: (ctx, snapshot) {
                      if (snapshot.data == null) {
                        return const Text("loading...");
                      }

                      return Text(
                          'Eingeloggt als ${snapshot.data!.displayName}');
                    }),
                TextButton(
                  child: const Text("ausloggen"),
                  onPressed: () async {
                    await client.logoutAll();
                    if (!mounted) return;
                    context.go("/");
                  },
                ),
                const Spacer()
              ]),
            )
          ] else ...[
            NavigationDrawerDestination(
              icon: CircleAvatar(
                child: Icon(Icons
                    .public_off_outlined), //widget.hasAvatarURL ? Image.network(widget.avatarURL!) : Text(widget.username[0])
              ),
              label: Text("Jetzt einloggen"),
            ),
          ],
          const SizedBox(height: 22),
          NavigationDrawerDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: Text('Home'),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.signpost_outlined),
            selectedIcon: const Icon(Icons.signpost),
            label: Text('Feeds/Räume'),
          ),
          /*const SizedBox(height: 22),
          NavigationDrawerDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: Text('Einstellungen'),
          ),*/
        ]);
  }
}
