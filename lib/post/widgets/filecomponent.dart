import 'package:substitution/post/widgets/filedisplay.dart';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:easy_localization/easy_localization.dart';

// TODO rename to FileDisplay or smthg.
class FileComponent extends StatefulWidget {
  const FileComponent(
      {super.key, required this.event, required this.displayEvent});

  final Event event;
  final Event displayEvent;

  @override
  FileComponentState createState() => FileComponentState();
}

class FileComponentState extends State<FileComponent> {
 // CarouselController carouselController = CarouselController();
  CarouselSliderController carouselController = CarouselSliderController();


  // TODO: downloadAndDecryptAttachment for encrypted files

  late List<
      ({
        Event origEvent,
        Event displayEvent,
        VideoPlayerController? videoController
      })> files = [
    (
      origEvent: widget.event,
      displayEvent: widget.displayEvent,
      videoController: null // will be added by relatedFiles getter
    )
  ];

  // adapted from comments
  Future<
      List<
          ({
            Event origEvent,
            Event displayEvent,
            VideoPlayerController? videoController
          })>> get relatedFiles async {
    List<
        ({
          Event origEvent,
          Event displayEvent,
          VideoPlayerController? videoController
        })> ret = [
      (
        origEvent: widget.event,
        displayEvent: widget.displayEvent,
        videoController:
            await getVideoPlayerControllerForEvent(widget.displayEvent)
      )
    ];

    Timeline timeline = await widget.event.room
        .getTimeline(eventContextId: widget.event.eventId);

    for (Event e
        in widget.event.aggregatedEvents(timeline, RelationshipTypes.reply)) {
      //var t = e.relationshipEventId;

      // todo: check if this is really a file and the owner of the reply

      if (e.relationshipEventId ==
                  widget.event.eventId && // relationship event id has to match
              e.senderId == widget.event.senderId // sender has to be the same
          // todo: filetype? oder wollen wir auch text zulassen?
          ) {
        ret.add((
          origEvent: e,
          displayEvent: e.getDisplayEvent(timeline),
          videoController: await getVideoPlayerControllerForEvent(e)
        ));
      }
    }

    // sort from new to old
    ret.sort((a, b) =>
        b.displayEvent.originServerTs.compareTo(a.displayEvent.originServerTs));

    return ret;
  }

  Future<VideoPlayerController?> getVideoPlayerControllerForEvent(
      Event e) async {
    if (widget.event.messageType != MessageTypes.Video ||
        Platform.isLinux ||
        Platform.isWindows ||
        Platform.isMacOS) {
      // we can't display videos on desktop, see videoplayer
      return null;
    }

    if (e.room.encrypted) {
      if (kIsWeb) {
        return VideoPlayerController.networkUrl(
            Uri.parse(await getDecryptedFileObjectUrlForEvent(e)))
          ..initialize();
      }

      // download and decrypt the file if the room is encrypted
      return VideoPlayerController.file(await getDecryptedFileForEvent(e))
        ..initialize();
    }

    return VideoPlayerController.networkUrl(
        e.getAttachmentUrl()!) // todo... null check
      ..initialize();
  }

  @override
  void initState() {
    super.initState();

    relatedFiles.then((f) {
      files = f;
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<String> getDecryptedFileObjectUrlForEvent(Event e) async {
    final file = await widget.event.downloadAndDecryptAttachment();
    final blob = html.Blob([file.bytes]);
    return html.Url.createObjectUrlFromBlob(blob);
  }

  Future<File> getDecryptedFileForEvent(Event e) async {
    MatrixFile f = await e.downloadAndDecryptAttachment();

    final dir = await getTemporaryDirectory();
    final fileName = Uri.encodeComponent(
      e
          .attachmentOrThumbnailMxcUrl()!
          .pathSegments
          .last, // or event.content.tryGet<String>('filename') ?? 'somefile..';
    );
    final file = File('${dir.path}/${fileName}_${f.name}');
    if (await file.exists() == false) {
      await file.writeAsBytes(f.bytes);
    }
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (files.length > 1) ...[
        IconButton(
            onPressed: () => carouselController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.linear),
            icon: const Icon(Icons.arrow_back_ios))
      ],
      Expanded(
          child: CarouselSlider.builder(
              carouselController: carouselController,
              itemCount: files.length,
              options: CarouselOptions(enableInfiniteScroll: false),
              itemBuilder:
                  (BuildContext context, int itemIndex, int pageViewIndex) {
                return Column(children: [
                  Text(files[itemIndex].displayEvent.calcUnlocalizedBody(
                      hideReply: true, hideEdit: true, plaintextBody: true)),
                  Expanded(
                      child: GestureDetector(
                    child: FileDisplay(file: files[itemIndex]),
                    onTap: () {
                      showDialog<String>(
                          // TODO: make this an extra widget
                          context: context,
                          builder: (BuildContext context) => Dialog(
                                  child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    AspectRatio(
                                        aspectRatio: 1,
                                        child: FittedBox(
                                            child: FileDisplay(
                                                file: files[itemIndex]))),
                                    const SizedBox(height: 15),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                              "post.widgets.filecomponent.button.close")
                                          .tr(),
                                    ),
                                  ],
                                ),
                              )));
                    },
                  )),
                ]);
              })),
      if (files.length > 1) ...[
        IconButton(
            onPressed: () => carouselController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.linear),
            icon: const Icon(Icons.arrow_forward_ios))
      ]
    ]);
  }
}
