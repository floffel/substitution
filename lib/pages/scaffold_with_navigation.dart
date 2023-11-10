import '/settings/widgets/menu.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class ScaffoldWithNavigation extends StatelessWidget {
  ScaffoldWithNavigation({super.key, required this.child});

  final Widget child;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => {context.pop(true)},
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text("app_name").tr(),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            onPressed: () => {
              _scaffoldKey.currentState?.openEndDrawer(),
            },
            icon: const Icon(Icons.menu),
          )
        ],
      ),
      body: SafeArea(
          child: Padding(padding: const EdgeInsets.all(16.0), child: child)),
      endDrawer: const Menu(),
    );
  }
}
