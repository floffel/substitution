import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:easy_localization/easy_localization.dart';

// Define a custom Form widget.
class HostPage extends StatefulWidget {
  const HostPage({super.key, required this.onComplete});

  final Function onComplete;

  @override
  _HostPageState createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  final adressContrainer = TextEditingController(
    text: 'matrix.org',
  );

  @override
  void dispose() {
    adressContrainer.dispose();
    super.dispose();
  }

  Future<bool> _setHost() async {
    final client = Provider.of<Client>(context, listen: false);

    try {
      // TODO: make it a mixin, its almost the same as in login.dart
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("loading".tr()),
            content: const AspectRatio(
                aspectRatio: .7,
                child: FittedBox(
                    child: Column(children: [
                  CircularProgressIndicator(),
                  Text("Checking host capibilities") // todo intl
                ]))),
          );
        },
      );

      await client.checkHomeserver(Uri.https(adressContrainer.text.trim(), ''));
      if (!mounted) return false;
      context.pop();
      return true;
    } catch (e) {
      //await Get.defaultDialog(
      //    title: 'errorTitle'.tr, content: Text('$e'));
      if (!mounted) return false;
      context.pop(); // pop the loading dialog
      // TODO: make it a mixin, its the same as in login.dart
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("loading").tr(),
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
      //debugPrint("error $e");
      //if (!mounted) return false;
      //context.pop();
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "auth.host.header", // AppLocalizations.of(context)!.authHostHeader,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ).tr(),
        const Text("auth.host.body").tr(),
        const SizedBox(height: 30),
        TextFormField(
          controller: adressContrainer,
          decoration: InputDecoration(
              prefixText: 'https://',
              icon: const Icon(Icons.dns),
              labelText: "auth.host.inputs.homeserver_label"
                  .tr() // AppLocalizations.of(context)!.authHostHomeserverInputLabel,
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
                if (await _setHost() && mounted) {
                  widget.onComplete();
                }
              },
              child: Text('auth.host.buttons.login_label'
                  .tr()), // AppLocalizations.of(context)!.authHostLoginButtonLabel),
            ),
            /*OutlinedButton( // TODO: we cannot do anything without login, mby think about this in the future
              style: OutlinedButton.styleFrom(
                textStyle: const TextStyle(fontSize: 18),
                padding: const EdgeInsets.all(14),
              ),
              onPressed: () async {
                if (await _setHost() && mounted) {
                  widget.onComplete();
                }
              },
              child: Text(AppLocalizations.of(context)!
                  .authHostWithoutLoginButtonLabel),
            ),*/
          ],
        )
      ],
    );
  }
}
