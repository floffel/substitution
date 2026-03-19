import '/feed/pages/home.dart';
import '/settings/pages/followfeeds.dart';
import '/settings/pages/settings_tab.dart';
import '/settings/widgets/menu.dart';
import '/shared/widgets/top_loading_bar.dart';
import '/chat/pages/chat_list_page.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class Feed extends StatefulWidget {
  const Feed({super.key, this.roomId});

  final String? roomId;

  static FeedState of(BuildContext context) {
    return context.findAncestorStateOfType<FeedState>()!;
  }

  @override
  FeedState createState() => FeedState();
}

class FeedState extends State<Feed> {
  int _currentIndex = 0;

  /// True once the user has navigated to the Discover tab (index 1).
  /// Used to lazily build FollowFeedSettings so it doesn't start background
  /// network fetches while the user is on a different tab.
  bool _hasVisitedDiscover = false;

  void switchToDiscover() {
    setState(() {
      _currentIndex = 1;
      _hasVisitedDiscover = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If viewing a specific room, show the old single-feed layout with back nav
    if (widget.roomId != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('app_name').tr(),
          centerTitle: true,
          // Keep menu icon for backward compat with integration tests
          actions: <Widget>[
            Builder(
              builder: (context) {
                return IconButton(
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                  icon: const Icon(Icons.menu),
                );
              },
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(TopLoadingBar.barHeight),
            child: TopLoadingBar(),
          ),
        ),
        body: HomePage(roomId: widget.roomId),
        endDrawer: const Menu(),
      );
    }

    // Main feed with bottom navigation
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Image.asset(
              'assets/icon/logo.png',
              width: 32,
              height: 32,
              errorBuilder:
                  (ctx, err, stack) =>
                      const Icon(Icons.image_not_supported, size: 28),
            ),
          ),
        ),
        title: Text(
          'Substitution',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        // Keep menu icon for backward compat with integration tests
        actions: <Widget>[
          Builder(
            builder: (context) {
              return IconButton(
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.menu),
              );
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(TopLoadingBar.barHeight),
          child: TopLoadingBar(),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Feed
          HomePage(onDiscoverTap: switchToDiscover),
          // Tab 1: Discover (feeds browser).
          // Only build FollowFeedSettings once the user first navigates here.
          // This prevents the paging fetch loop from running in the background
          // while the user is on other tabs (IndexedStack keeps all children
          // mounted, so without this guard it starts fetching immediately on
          // app launch and loops during integration-test pumpAndSettle calls).
          if (_hasVisitedDiscover)
            const FollowFeedSettings()
          else
            const SizedBox.shrink(),
          // Tab 2: Messages (DMs)
          const ChatListPage(),
          // Tab 3: Settings
          const SettingsTab(),
        ],
      ),
      // Keep endDrawer for backward compat with integration tests that open it
      endDrawer: const Menu(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 1) _hasVisitedDiscover = true;
          });
        },
        destinations: [
          NavigationDestination(
            key: const Key('navHome'),
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: 'feed.nav.home'.tr(),
          ),
          NavigationDestination(
            key: const Key('navDiscover'),
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: 'feed.nav.discover'.tr(),
          ),
          NavigationDestination(
            key: const Key('navMessages'),
            icon: const Icon(Icons.message_outlined),
            selectedIcon: const Icon(Icons.message_rounded),
            label: 'feed.nav.messages'.tr(),
          ),
          NavigationDestination(
            key: const Key('navSettings'),
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: 'feed.nav.settings'.tr(),
          ),
        ],
      ),
      floatingActionButton:
          _currentIndex == 0
              ? FloatingActionButton(
                key: const Key('fabNewPost'),
                onPressed: () => context.push('/write/select/room'),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add_rounded, size: 28),
              )
              : null,
    );
  }
}
