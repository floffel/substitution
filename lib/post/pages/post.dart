import '/post/interfaces/ievent.dart';
import '/post/widgets/post.dart';
import '/post/widgets/comment.dart';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PostPage extends IEventWidget {
  const PostPage(
      {super.key, required super.event, required super.displayEvent});

  @override
  PostPageState createState() => PostPageState();
}

class PostPageState extends State<PostPage> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: () async {
              // TODO: test if this realy reloads the comments and if not, implement it
              setState(() {});
              return Future<void>.delayed(
                  const Duration(seconds: 1)); // cosmetic reasons
            },
            child: FutureBuilder(
                future: widget.comments,
                builder: (ctx, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text("loading").tr();
                  }

                  return SingleChildScrollView(
                      child: Column(
                          children:
                              ListTile.divideTiles(context: context, tiles: [
                    PostWidget(
                        event: widget.event, displayEvent: widget.displayEvent),
                    ...snapshot.data?.map((var e) {
                          return CommentWidget(
                              event: e.origEvent,
                              displayEvent: e.displayEvent,
                              postEvent: widget.event);
                        }).toList() ??
                        [const Text("post.pages.post.no_comments").tr()]
                  ]).toList()));
                })));
  }
}
