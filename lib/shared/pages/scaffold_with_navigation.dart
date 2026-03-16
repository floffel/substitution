import '/settings/widgets/menu.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class ScaffoldWithNavigation extends StatefulWidget {
  final Widget child;
  final bool showNavigation;

  const ScaffoldWithNavigation({
    super.key,
    required this.child,
    this.showNavigation = true,
  });

  @override
  State<ScaffoldWithNavigation> createState() => _ScaffoldWithNavigationState();
}

class _ScaffoldWithNavigationState extends State<ScaffoldWithNavigation> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading:
            widget.showNavigation
                ? IconButton(
                  onPressed: () => context.pop(true),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
                : null,
        title: const Text("app_name").tr(),
        centerTitle: true,
        actions:
            widget.showNavigation
                ? <Widget>[
                  Builder(
                    builder: (context) {
                      return IconButton(
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                        icon: const Icon(Icons.menu),
                      );
                    },
                  ),
                ]
                : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: widget.child,
        ),
      ),
      endDrawer: widget.showNavigation ? const Menu() : null,
    );
  }
}
