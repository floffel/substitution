import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('settings.legal.title').tr(),
        leading: BackButton(
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('settings.legal.tos').tr(),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => _launchUrl('$_repoBase/TERMS.md'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('settings.legal.privacy').tr(),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => _launchUrl('$_repoBase/PRIVACY.md'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('settings.legal.imprint').tr(),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => _launchUrl('$_repoBase/IMPRINT.md'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('settings.legal.licenses').tr(),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Substitution',
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset('assets/icon/logo.png', width: 64, height: 64),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
