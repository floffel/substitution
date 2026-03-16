import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:easy_localization/easy_localization.dart';

import '/auth/auth_state.dart';

// Define a custom Form widget.
class HostPage extends StatefulWidget {
  const HostPage({super.key, required this.onComplete});

  final Function onComplete;

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  final adressContrainer = TextEditingController(text: 'matrix.org');

  @override
  void dispose() {
    adressContrainer.dispose();
    super.dispose();
  }

  Future<bool> _setHost() async {
    final client = Provider.of<Client>(context, listen: false);

    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("loading".tr()),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    "Checking host capabilities",
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

      final input = adressContrainer.text.trim();
      final uri =
          input.startsWith('http://') || input.startsWith('https://')
              ? Uri.parse(input)
              : Uri.https(input, '');
      final (_, _, loginFlows, _) = await client.checkHomeserver(uri);
      if (!mounted) return false;
      context.read<AuthState>().setLoginFlows(loginFlows);
      context.pop();
      return true;
    } catch (e) {
      if (!mounted) return false;
      context.pop(); // pop the loading dialog
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            icon: Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 32,
            ),
            title: Text("error".tr(args: [""])),
            content: Text(
              "$e",
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Icon(
          Icons.dns_rounded,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('hostServerInput'),
          controller: adressContrainer,
          decoration: InputDecoration(
            prefixText: 'https://',
            prefixIcon: const Icon(Icons.language_rounded),
            labelText: "auth.host.inputs.homeserver_label".tr(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('hostSubmitButton'),
            onPressed: () async {
              if (await _setHost() && mounted) {
                widget.onComplete();
              }
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text('auth.host.buttons.login_label'.tr()),
          ),
        ),
      ],
    );
  }
}
