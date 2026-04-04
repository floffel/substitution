import '/feed/pages/home.dart';
import '/settings/pages/followfeeds.dart';
import '/settings/widgets/menu.dart';
import '/shared/widgets/top_loading_bar.dart';
import '/chat/pages/chat_list_page.dart';
import '/chat/widgets/new_chat_sheet.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '/shared/utils/share_helper.dart';

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

  Widget? _buildFab(BuildContext context) {
    if (_currentIndex == 0) {
      return FloatingActionButton(
        key: const Key('fabNewPost'),
        heroTag: 'fabNewPost',
        onPressed: () => context.push('/write/select/room'),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      );
    }
    if (_currentIndex == 2) {
      return FloatingActionButton(
        key: const Key('fabNewChat'),
        heroTag: 'fabNewChat',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => const NewChatSheet(),
          );
        },
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'chat.new_chat'.tr(),
        child: const Icon(Icons.edit_rounded, size: 24),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If viewing a specific room, show the old single-feed layout with back nav
    if (widget.roomId != null) {
      final client = Provider.of<Client>(context, listen: false);
      final room = client.getRoomById(widget.roomId!);
      final memberCount = room?.summary.mJoinedMemberCount;
      final roomName = room?.name ?? '';

      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                roomName.isNotEmpty ? roomName : 'app_name'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (memberCount != null)
                Text(
                  'members.count'.tr(args: [memberCount.toString()]),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          // Keep menu icon for backward compat with integration tests
          actions: <Widget>[
            if (room != null)
              IconButton(
                onPressed:
                    () => context.push(
                      '/room/${Uri.encodeComponent(widget.roomId!)}/members',
                    ),
                icon: const Icon(Icons.people_outline_rounded),
                tooltip: 'members.title'.tr(),
              ),
            IconButton(
              onPressed: () => ShareHelper.shareRoom(context, widget.roomId!),
              icon: const Icon(Icons.share_outlined),
              tooltip: 'share.share_room'.tr(),
            ),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (_) => context.go('/'),
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
          ],
        ),
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
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }
}
