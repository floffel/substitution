import 'package:flutter/material.dart';

import 'package:substitution/post/interfaces/ievent.dart';
import 'package:substitution/post/widgets/post.dart';
import 'package:substitution/post/widgets/comment.dart';

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
              // Replace this delay with the code to be executed during refresh
              // and return asynchronous code

              return Future<void>.delayed(const Duration(seconds: 3));
            },
            child: FutureBuilder(
                future: widget.comments,
                builder: (ctx, snapshot) {
                  debugPrint("Comments: ${snapshot.data}");

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
                        [
                          const Text("Keine Kommentare vorhanden")
                        ] // todo internationalisation
                  ]).toList()));
                })));
  }
}
