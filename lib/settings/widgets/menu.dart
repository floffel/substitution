import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:substitution/shared/services/theme_service.dart';
import '/feed/feed.dart';
import '/shared/widgets/avatar.dart';

// Define a custom Form widget.
class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  Client get client => Provider.of<Client>(context, listen: false);
  // Helper methods
  Future<Profile> get profile async => (await client.fetchOwnProfile());
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
      onDestinationSelected: (int index) async {
        if (client.isLogged()) {
          if (index == 0) {
            // Profile header — no navigation
          } else if (index == 1) {
            // Logout
            try {
              await client.logout();
              await client.database
                  .clear(); // Also clear the local database cache to prevent session leaks
            } catch (e) {
              debugPrint('Logout error (ignored): $e');
            }
            if (!context.mounted) return;
            context.go("/");
          } else if (index == 2) {
            // Home
            context.go("/");
          } else if (index == 3) {
            // Feeds/Räume — switch to Discover tab if inside Feed, else push route
            final feedState = context.findAncestorStateOfType<FeedState>();
            if (feedState != null) {
              Navigator.of(context).pop(); // close drawer
              feedState.switchToDiscover();
            } else {
              context.push("/settings/feed");
            }
          } else if (index == 4) {
            // Eigene Feeds
            context.push("/settings/ownfeeds");
          } else if (index == 5) {
            // Edit Profile
            context.push("/settings/profile");
          } else if (index == 6) {
            // Security
            context.push("/settings/security");
          } else if (index == 7) {
            // Legal
            context.push("/settings/legal");
          } else if (index == 8) {
            // Help
            context.push("/help");
          }
        } else {
          if (index == 0) {
            // login
            context.push("/auth/host");
          } else if (index == 1) {
            // Home
            context.go("/");
          } else if (index == 2) {
            // Feeds/Räume — switch to Discover tab if inside Feed, else push route
            final feedState = context.findAncestorStateOfType<FeedState>();
            if (feedState != null) {
              Navigator.of(context).pop(); // close drawer
              feedState.switchToDiscover();
            } else {
              context.push("/settings/feed");
            }
          } else if (index == 3) {
            // Eigene Feeds
            context.push("/settings/ownfeeds");
          } else if (index == 4) {
            // Legal (not logged in)
            context.push("/settings/legal");
          } else if (index == 5) {
            // Help (not logged in)
            context.push("/help");
          }
        }
      },
      children: [
        const SizedBox(height: 22),
        if (client.isLogged()) ...[
          NavigationDrawerDestination(
            icon: FutureBuilder<Profile>(
              future: profile,
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return const CircleAvatar(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return Avatar(
                  mxContent: snapshot.data?.avatarUrl,
                  name: snapshot.data?.displayName,
                  client: client,
                  size: 40,
                );
              },
            ),
            label: FutureBuilder(
              future: profile,
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                return SizedBox(
                  width: 180,
                  child: Text(
                    "settings.menu.logged_in_as".tr(
                      args: [snapshot.data!.displayName!],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              },
            ),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.logout),
            label: const Text("settings.menu.logout").tr(),
          ),
        ] else ...[
          NavigationDrawerDestination(
            icon: const CircleAvatar(
              child: Icon(
                Icons.public_off_outlined,
              ), //widget.hasAvatarURL ? Image.network(widget.avatarURL!) : Text(widget.username[0])
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
          label: const Text('settings.menu.ownfeeds_label').tr(),
        ),
        if (client.isLogged()) ...[
          const SizedBox(height: 8),
          NavigationDrawerDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person),
            label: const Text('settings.menu.profile_label').tr(),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.security_outlined),
            selectedIcon: const Icon(Icons.security),
            label: const Text('settings.menu.security_label').tr(),
          ),
        ],
        const SizedBox(height: 22),
        NavigationDrawerDestination(
          icon: const Icon(Icons.gavel_outlined),
          selectedIcon: const Icon(Icons.gavel),
          label: const Text('settings.legal.title').tr(),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.help_outline_rounded),
          selectedIcon: const Icon(Icons.help_rounded),
          label: const Text('help.title').tr(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SwitchListTile(
            title: const Text('Dark Mode'),
            value: context.watch<ThemeService>().isDark(context),
            onChanged: (_) {
              final themeService = context.read<ThemeService>();
              themeService.toggleTheme(isDark: themeService.isDark(context));
            },
          ),
        ),
      ],
    );
  }
}
