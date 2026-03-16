import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:substitution/shared/services/theme_service.dart';

/// A full-screen settings / profile tab that replaces the old navigation drawer.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Client get client => Provider.of<Client>(context, listen: false);

  Future<Profile> get profile async => (await client.fetchOwnProfile());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Profile Header ---
              if (client.isLogged()) _buildProfileHeader(theme, colorScheme),
              if (!client.isLogged()) _buildLoginPrompt(theme, colorScheme),

              const SizedBox(height: 24),

              // --- Navigation Section ---
              _buildSectionLabel(theme, 'settings.menu.navigation_label'.tr()),
              const SizedBox(height: 8),
              _buildSettingsCard(
                context,
                children: [
                  _buildSettingsTile(
                    icon: Icons.signpost_outlined,
                    label: 'settings.menu.feeds_site_label'.tr(),
                    onTap: () => context.push('/settings/feed'),
                  ),
                  _buildDivider(colorScheme),
                  _buildSettingsTile(
                    icon: Icons.dashboard_outlined,
                    label: 'Eigene Feeds',
                    onTap: () => context.push('/settings/ownfeeds'),
                  ),
                ],
              ),

              if (client.isLogged()) ...[
                const SizedBox(height: 20),
                _buildSectionLabel(theme, 'settings.menu.account_label'.tr()),
                const SizedBox(height: 8),
                _buildSettingsCard(
                  context,
                  children: [
                    _buildSettingsTile(
                      icon: Icons.person_outlined,
                      label: 'Edit Profile',
                      onTap: () => context.push('/settings/profile'),
                    ),
                    _buildDivider(colorScheme),
                    _buildSettingsTile(
                      icon: Icons.security_outlined,
                      label: 'Security',
                      onTap: () => context.push('/settings/security'),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
              _buildSectionLabel(theme, 'settings.menu.preferences_label'.tr()),
              const SizedBox(height: 8),
              _buildSettingsCard(
                context,
                children: [
                  // Dark Mode toggle — kept as SwitchListTile for test compat
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    secondary: Icon(
                      context.watch<ThemeService>().isDark(context)
                          ? Icons.dark_mode
                          : Icons.light_mode_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    value: context.watch<ThemeService>().isDark(context),
                    onChanged: (_) {
                      final themeService = context.read<ThemeService>();
                      themeService.toggleTheme(
                        isDark: themeService.isDark(context),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),
              _buildSectionLabel(theme, 'settings.menu.about_label'.tr()),
              const SizedBox(height: 8),
              _buildSettingsCard(
                context,
                children: [
                  _buildSettingsTile(
                    icon: Icons.gavel_outlined,
                    label: 'settings.legal.title'.tr(),
                    onTap: () => context.push('/settings/legal'),
                  ),
                ],
              ),

              if (client.isLogged()) ...[
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: Text('settings.menu.logout'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      // Show confirmation dialog
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: Text('settings.menu.logout'.tr()),
                              content: Text(
                                'settings.menu.logout_confirm'.tr(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('cancel'.tr()),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('Logout'),
                                ),
                              ],
                            ),
                      );
                      if (shouldLogout == true && mounted) {
                        try {
                          await client.logout();
                          await client.database.clear();
                        } catch (e) {
                          debugPrint('Logout error (ignored): $e');
                        }
                        if (!context.mounted) return;
                        context.go('/');
                      }
                    },
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, ColorScheme colorScheme) {
    return FutureBuilder<Profile>(
      future: profile,
      builder: (context, snapshot) {
        final isLoading = !snapshot.hasData;
        final displayName = snapshot.data?.displayName ?? '...';
        final avatarUrl = snapshot.data?.avatarUrl;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 32,
                backgroundColor: colorScheme.primaryContainer,
                child:
                    isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : avatarUrl != null
                        ? ClipOval(
                          child: Image.network(
                            avatarUrl.getDownloadUri(client).toString(),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, obj, stack) {
                              return SvgPicture.network(
                                avatarUrl.getDownloadUri(client).toString(),
                                width: 64,
                                height: 64,
                              );
                            },
                          ),
                        )
                        : Text(
                          displayName[0].toUpperCase(),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.userID ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoginPrompt(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'settings.menu.not_logged_in'.tr(),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/auth/host'),
            child: Text('settings.menu.login'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
      title: Text(label),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Divider(
      height: 1,
      indent: 56,
      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}
