import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Data model for a single help article.
class _HelpArticle {
  final String titleKey;
  final String bodyKey;
  final IconData icon;

  const _HelpArticle({
    required this.titleKey,
    required this.bodyKey,
    required this.icon,
  });
}

/// The list of help articles, displayed in order.
const _articles = <_HelpArticle>[
  _HelpArticle(
    titleKey: 'help.articles.what_is_substitution.title',
    bodyKey: 'help.articles.what_is_substitution.body',
    icon: Icons.info_outline_rounded,
  ),
  _HelpArticle(
    titleKey: 'help.articles.what_is_matrix.title',
    bodyKey: 'help.articles.what_is_matrix.body',
    icon: Icons.hub_outlined,
  ),
  _HelpArticle(
    titleKey: 'help.articles.getting_started.title',
    bodyKey: 'help.articles.getting_started.body',
    icon: Icons.rocket_launch_outlined,
  ),
  _HelpArticle(
    titleKey: 'help.articles.what_are_rooms.title',
    bodyKey: 'help.articles.what_are_rooms.body',
    icon: Icons.forum_outlined,
  ),
  _HelpArticle(
    titleKey: 'help.articles.follow_rooms.title',
    bodyKey: 'help.articles.follow_rooms.body',
    icon: Icons.explore_outlined,
  ),
  _HelpArticle(
    titleKey: 'help.articles.create_room.title',
    bodyKey: 'help.articles.create_room.body',
    icon: Icons.add_circle_outline_rounded,
  ),
  _HelpArticle(
    titleKey: 'help.articles.manage_room.title',
    bodyKey: 'help.articles.manage_room.body',
    icon: Icons.settings_outlined,
  ),
  _HelpArticle(
    titleKey: 'help.articles.write_post.title',
    bodyKey: 'help.articles.write_post.body',
    icon: Icons.edit_outlined,
  ),
  _HelpArticle(
    titleKey: 'help.articles.share_rooms.title',
    bodyKey: 'help.articles.share_rooms.body',
    icon: Icons.share_outlined,
  ),
  _HelpArticle(
    titleKey: 'help.articles.direct_messages.title',
    bodyKey: 'help.articles.direct_messages.body',
    icon: Icons.message_outlined,
  ),
  _HelpArticle(
    titleKey: 'help.articles.opening_links.title',
    bodyKey: 'help.articles.opening_links.body',
    icon: Icons.link_rounded,
  ),
];

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text('help.title'.tr(), style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'help.subtitle'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Articles ────────────────────────────────────────────────────
        ..._articles.map((article) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Theme(
                // Remove the default divider that ExpansionTile adds
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(
                    article.icon,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  title: Text(
                    article.titleKey.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      article.bodyKey.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 16),
      ],
    );
  }
}
