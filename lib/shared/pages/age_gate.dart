import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AgeGatePage extends StatelessWidget {
  const AgeGatePage({super.key});

  static const _prefKey = 'age_confirmed';

  /// In-memory flag so the synchronous router redirect can check it without
  /// an async call. Updated by [_initConfirmed] and [_confirm].
  static bool confirmed = false;

  /// Loads the persisted preference and updates [confirmed].
  /// Call this once at app start before building the router.
  static Future<void> initConfirmed() async {
    final prefs = await SharedPreferences.getInstance();
    confirmed = prefs.getBool(_prefKey) == true;
  }

  Future<void> _confirm(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    AgeGatePage.confirmed =
        true; // update in-memory flag so router redirect works
    if (!context.mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  96,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Image.asset(
                    'assets/icon/logo.png',
                    width: 80,
                    height: 80,
                    errorBuilder:
                        (ctx, err, stack) =>
                            const Icon(Icons.image_not_supported, size: 80),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'age_gate.title'.tr(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'age_gate.description'.tr(),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bullet(context, 'age_gate.point_client'),
                        const SizedBox(height: 8),
                        _bullet(context, 'age_gate.point_servers'),
                        const SizedBox(height: 8),
                        _bullet(context, 'age_gate.point_age'),
                        const SizedBox(height: 8),
                        _bullet(context, 'age_gate.point_content'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('ageGateConfirmButton'),
                    onPressed: () => _confirm(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('age_gate.confirm').tr(),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        () => launchUrl(
                          Uri.parse(
                            'https://github.com/floffel/substitution/blob/main/PRIVACY.md',
                          ),
                        ),
                    child: const Text('age_gate.privacy_link').tr(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String key) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const Text('• '), Expanded(child: Text(key).tr())],
    );
  }
}
