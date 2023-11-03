import '/feed/pages/home.dart';
import '/settings/widgets/menu.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// todo: rewrite, so we don't need this extra feed state
@immutable
class Feed extends StatefulWidget {
  const Feed({super.key, this.roomId});

  final String? roomId;

  static FeedState of(BuildContext context) {
    return context.findAncestorStateOfType<FeedState>()!;
  }

  @override
  FeedState createState() => FeedState();
}

class FeedState extends State<Feed> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => {context.push("/write/select/room")},
          icon: const Icon(Icons.send_outlined),
        ),
        title: const Text("Substitution"),
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
      body: HomePage(roomId: widget.roomId),
      endDrawer: const Menu(),
    );
  }
}
