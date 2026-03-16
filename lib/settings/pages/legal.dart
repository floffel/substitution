import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

const _repoBase = 'https://github.com/floffel/substitution/blob/main';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.gavel_rounded,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'settings.legal.title'.tr(),
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),

        // Legal links card
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.description_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: const Text('settings.legal.tos').tr(),
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () => _launchUrl('$_repoBase/TERMS.md'),
              ),
              Divider(
                height: 1,
                indent: 56,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              ListTile(
                leading: Icon(
                  Icons.privacy_tip_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: const Text('settings.legal.privacy').tr(),
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () => _launchUrl('$_repoBase/PRIVACY.md'),
              ),
              Divider(
                height: 1,
                indent: 56,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              ListTile(
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: const Text('settings.legal.imprint').tr(),
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () => _launchUrl('$_repoBase/IMPRINT.md'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Licenses card
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            leading: Icon(
              Icons.code_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            title: const Text('settings.legal.licenses').tr(),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Substitution',
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    'assets/icon/logo.png',
                    width: 64,
                    height: 64,
                    errorBuilder:
                        (ctx, err, stack) =>
                            const Icon(Icons.image_not_supported, size: 64),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
