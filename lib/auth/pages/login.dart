import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:provider/provider.dart';

import 'package:go_router/go_router.dart';

import 'package:easy_localization/easy_localization.dart';

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

  @override
  void dispose() {
    usernameContrainer.dispose();
    passwordContrainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "auth.login.header",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ).tr(),
        const Text("auth.login.body").tr(),
        const SizedBox(height: 30),
        TextFormField(
          controller: usernameContrainer,
          decoration: InputDecoration(
            icon: const Icon(Icons.perm_identity),
            labelText: "auth.login.inputs.username_label".tr(),
          ),
        ),
        TextFormField(
          obscureText: true,
          controller: passwordContrainer,
          decoration: InputDecoration(
            icon: const Icon(Icons.password),
            labelText: "auth.login.inputs.password_label".tr(),
          ),
        ),
        const SizedBox(height: 30),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
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
          ],
        )
      ],
    );
  }
}
