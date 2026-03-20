import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:provider/provider.dart';

import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'package:easy_localization/easy_localization.dart';

import '/auth/auth_state.dart';

// Define a custom Form widget.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onComplete});

  final Function onComplete;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameContrainer = TextEditingController();
  final passwordContrainer = TextEditingController();
  bool _obscurePassword = true;

  Future<bool> login() async {
    final client = Provider.of<Client>(context, listen: false);

    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("loading").tr(),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'auth.login.loading'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: usernameContrainer.text),
        password: passwordContrainer.text,
      );

      if (!mounted) return false;
      context.pop();

      return true;
    } catch (e) {
      if (!mounted) return false;
      context.pop();

      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            icon: Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 32,
            ),
            title: const Text('loading').tr(),
            content: Text(
              "error".tr(args: ["$e"]),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            actions: <Widget>[
              FilledButton(
                child: const Text("approve").tr(),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    return false;
  }

  /// Builds the SSO redirect URL for the given [provider].
  Uri _buildSsoUrl(SsoProvider provider) {
    final client = Provider.of<Client>(context, listen: false);
    final homeserver = client.homeserver ?? Uri.parse('https://matrix.org');

    String redirectUrl;
    if (kIsWeb) {
      redirectUrl = '${web.window.location.origin}/login-callback';
    } else {
      redirectUrl = 'substitution://login-callback';
    }
    redirectUrl += '?homeserver=${Uri.encodeComponent(homeserver.toString())}';

    final ssoPath =
        provider.id.isNotEmpty
            ? '_matrix/client/v3/login/sso/redirect/${Uri.encodeComponent(provider.id)}'
            : '_matrix/client/v3/login/sso/redirect';

    return homeserver
        .resolve(ssoPath)
        .replace(queryParameters: {'redirectUrl': redirectUrl});
  }

  Future<void> loginSSO(SsoProvider provider) async {
    try {
      final ssoUrl = _buildSsoUrl(provider);

      if (kIsWeb) {
        web.window.location.assign(ssoUrl.toString());
      } else {
        await launchUrl(ssoUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting SSO: $e')));
    }
  }

  @override
  void dispose() {
    usernameContrainer.dispose();
    passwordContrainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = context.watch<AuthState>();
    final hasPassword = authState.hasPasswordFlow;
    final ssoProviders = authState.ssoProviders;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),

          // Password fields
          if (hasPassword) ...[
            TextFormField(
              key: const Key('loginUsernameInput'),
              controller: usernameContrainer,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline_rounded),
                labelText: "auth.login.inputs.username_label".tr(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('loginPasswordInput'),
              obscureText: _obscurePassword,
              controller: passwordContrainer,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                labelText: "auth.login.inputs.password_label".tr(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) async {
                if (await login() && mounted) {
                  widget.onComplete();
                }
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('loginSubmitButton'),
                onPressed: () async {
                  if (await login() && mounted) {
                    widget.onComplete();
                  }
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text("auth.login.buttons.login_label").tr(),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('registerWebButton'),
              onPressed: () async {
                final client = Provider.of<Client>(context, listen: false);
                final url =
                    client.homeserver ?? Uri.parse('https://matrix.org');
                if (!await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                )) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not launch \$url')),
                  );
                }
              },
              child: const Text("auth.login.buttons.register_web_label").tr(),
            ),
          ],

          // SSO buttons
          if (ssoProviders.isNotEmpty) ...[
            if (hasPassword) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: colorScheme.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: colorScheme.outlineVariant)),
                ],
              ),
              const SizedBox(height: 16),
            ],
            ...ssoProviders.map(
              (provider) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: Key('ssoButton_${provider.id}'),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      'auth.login.buttons.sso_label'.tr(args: [provider.name]),
                    ),
                    onPressed: () => loginSSO(provider),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
