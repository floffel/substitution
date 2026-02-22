import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:provider/provider.dart';

import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:easy_localization/easy_localization.dart';

import '/auth/auth_state.dart';

// Define a custom Form widget.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onComplete});

  final Function onComplete;

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameContrainer = TextEditingController();
  final passwordContrainer = TextEditingController();

  Future<bool> login() async {
    final client = Provider.of<Client>(context, listen: false);

    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("loading").tr(),
            content: AspectRatio(
                aspectRatio: .7,
                child: FittedBox(
                    child: Column(children: [
                  const CircularProgressIndicator(),
                  const Text('auth.login.loading').tr()
                ]))),
          );
        },
      );

      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: usernameContrainer.text),
        password: passwordContrainer.text,
      );

      // TODO: get the ids etc.

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
            title: const Text('loading').tr(),
            content: AspectRatio(
                aspectRatio: 1,
                child: FittedBox(
                  child: const Text("error").tr(args: ["$e"]),
                )),
            actions: <Widget>[
              TextButton(
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
  ///
  /// Uses the provider-specific path when an [SsoProvider.id] is available:
  ///   `/_matrix/client/v3/login/sso/redirect/{idpId}?redirectUrl=...`
  /// Falls back to the generic path when the id is empty:
  ///   `/_matrix/client/v3/login/sso/redirect?redirectUrl=...`
  Uri _buildSsoUrl(SsoProvider provider) {
    final client = Provider.of<Client>(context, listen: false);
    final homeserver = client.homeserver ?? Uri.parse('https://matrix.org');

    String redirectUrl;
    if (kIsWeb) {
      redirectUrl = '${html.window.location.origin}/login-callback';
    } else {
      redirectUrl = 'substitution://login-callback';
    }
    redirectUrl += '?homeserver=${Uri.encodeComponent(homeserver.toString())}';

    final ssoPath = provider.id.isNotEmpty
        ? '_matrix/client/v3/login/sso/redirect/${Uri.encodeComponent(provider.id)}'
        : '_matrix/client/v3/login/sso/redirect';

    return homeserver.resolve(ssoPath).replace(queryParameters: {
      'redirectUrl': redirectUrl,
    });
  }

  Future<void> loginSSO(SsoProvider provider) async {
    try {
      final ssoUrl = _buildSsoUrl(provider);

      if (kIsWeb) {
        html.window.location.assign(ssoUrl.toString());
      } else {
        await launchUrl(ssoUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting SSO: $e')),
      );
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
    final authState = context.watch<AuthState>();
    final hasPassword = authState.hasPasswordFlow;
    final ssoProviders = authState.ssoProviders;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),

          // Password fields — only shown when the server supports password login.
          if (hasPassword) ...[
            TextFormField(
              key: const Key('loginUsernameInput'),
              controller: usernameContrainer,
              decoration: InputDecoration(
                icon: const Icon(Icons.perm_identity),
                labelText: "auth.login.inputs.username_label".tr(),
              ),
            ),
            TextFormField(
              key: const Key('loginPasswordInput'),
              obscureText: true,
              controller: passwordContrainer,
              decoration: InputDecoration(
                icon: const Icon(Icons.password),
                labelText: "auth.login.inputs.password_label".tr(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              key: const Key('loginSubmitButton'),
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(fontSize: 18),
                padding: const EdgeInsets.all(14),
              ),
              onPressed: () async {
                if (await login() && mounted) {
                  widget.onComplete();
                }
              },
              child: const Text("auth.login.buttons.login_label").tr(),
            ),
            const SizedBox(height: 10),
            TextButton(
              key: const Key('registerWebButton'),
              onPressed: () async {
                final client = Provider.of<Client>(context, listen: false);
                final url = client.homeserver ?? Uri.parse('https://matrix.org');
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not launch \$url')),
                  );
                }
              },
              child: const Text("auth.login.buttons.register_web_label").tr(),
            ),
          ],

          // SSO buttons — one per identity provider advertised by the server.
          if (ssoProviders.isNotEmpty) ...[
            if (hasPassword) const SizedBox(height: 20),
            ...ssoProviders.map(
              (provider) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  key: Key('ssoButton_${provider.id}'),
                  icon: const Icon(Icons.login),
                  label: Text(
                      'auth.login.buttons.sso_label'.tr(args: [provider.name])),
                  onPressed: () => loginSSO(provider),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    minimumSize: const Size.fromHeight(52),
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
