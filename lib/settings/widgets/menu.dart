import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
        onDestinationSelected: (int index) {
          if (index == 0 && !client.isLogged()) {
            // login
            context.push("/auth/host");
          } else if (index == 1) {
            // Home
            context.go("/");
          } else if (index == 2) {
            // Feeds/Räume
            context.push("/settings/feed");
          } else if (index == 3) {
            // Settings
            context.push("/settings/ownfeeds");
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
                        if (!snapshot.hasData) {
                          return const Text("loading").tr();
                        }
                        // TODO: check if image is svg
                        return snapshot.data?.avatarUrl == null
                            ? Text(snapshot.data!.displayName![0])
                            : Image.network(
                                snapshot.data!.avatarUrl!
                                    .getDownloadLink(client)
                                    .toString(),
                                width: 40,
                                height: 40, errorBuilder: (ctx, obj, stack) {
                                // todo: find a way to check if we have a svg beforehand!
                                return SvgPicture.network(
                                  snapshot.data!.avatarUrl!
                                      .getDownloadLink(client)
                                      .toString(),
                                  width: 40,
                                  height: 40,
                                );
                              });
                      })),
              label: Flex(direction: Axis.vertical, children: [
                const Spacer(),
                FutureBuilder(
                    future: profile,
                    builder: (ctx, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text("loading").tr();
                      }

                      return const Text("settings.menu.logged_in_as")
                          .tr(args: [snapshot.data!.displayName!]);
                    }),
                TextButton(
                  child: const Text("settings.menu.logout").tr(),
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
              icon: const CircleAvatar(
                child: Icon(Icons
                    .public_off_outlined), //widget.hasAvatarURL ? Image.network(widget.avatarURL!) : Text(widget.username[0])
              ),
              label: const Text("settings.menu.login").tr(),
            ),
          ],
          const SizedBox(height: 22),
          NavigationDrawerDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: const Text('settings.menu.home_site_label').tr(),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.signpost_outlined),
            selectedIcon: const Icon(Icons.signpost),
            label: const Text('settings.menu.feeds_site_label').tr(),
          ),
          const SizedBox(height: 22),
          NavigationDrawerDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: const Text('Eigene Feeds'), // todo: intl
          ),
        ]);
  }
}
