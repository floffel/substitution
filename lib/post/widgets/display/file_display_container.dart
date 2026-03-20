import 'file_display.dart';

import '/shared/platform/platform.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dismissible_page/dismissible_page.dart';
import '/shared/platform/video_helper.dart' show videoControllerFromFile;

// TODO rename to FileDisplay or smthg.
class FileDisplayContainer extends StatefulWidget {
  const FileDisplayContainer({
    super.key,
    required this.event,
    required this.displayEvent,
  });

  final Event event;
  final Event displayEvent;

  @override
  FileDisplayContainerState createState() => FileDisplayContainerState();
}

class FileDisplayContainerState extends State<FileDisplayContainer> {
  // CarouselController carouselController = CarouselController();
  CarouselSliderController carouselController = CarouselSliderController();

  // TODO: downloadAndDecryptAttachment for encrypted files

  late List<
    ({
      Event origEvent,
      Event displayEvent,
      VideoPlayerController? videoController,
    })
  >
  files = [
    (
      origEvent: widget.event,
      displayEvent: widget.displayEvent,
      videoController: null, // will be added by relatedFiles getter
    ),
  ];

  // adapted from comments
  Future<
    List<
      ({
        Event origEvent,
        Event displayEvent,
        VideoPlayerController? videoController,
      })
    >
  >
  get relatedFiles async {
    List<
      ({
        Event origEvent,
        Event displayEvent,
        VideoPlayerController? videoController,
      })
    >
    ret = [
      (
        origEvent: widget.event,
        displayEvent: widget.displayEvent,
        videoController: await getVideoPlayerControllerForEvent(
          widget.displayEvent,
        ),
      ),
    ];

    Timeline timeline = await widget.event.room.getTimeline(
      eventContextId: widget.event.eventId,
    );

    for (Event e in widget.event.aggregatedEvents(
      timeline,
      RelationshipTypes.reference,
    )) {
      //var t = e.relationshipEventId;

      // todo: check if this is really a file and the owner of the reply

      if (e.relationshipEventId ==
              widget.event.eventId && // relationship event id has to match
          e.senderId ==
              widget
                  .event
                  .senderId // sender has to be the same
      // todo: filetype? oder wollen wir auch text zulassen?
      ) {
        ret.add((
          origEvent: e,
          displayEvent: e.getDisplayEvent(timeline),
          videoController: await getVideoPlayerControllerForEvent(e),
        ));
      }
    }

    // sort from new to old
    ret.sort(
      (a, b) => b.displayEvent.originServerTs.compareTo(
        a.displayEvent.originServerTs,
      ),
    );

    return ret;
  }

  Future<VideoPlayerController?> getVideoPlayerControllerForEvent(
    Event e,
  ) async {
    if (kIsWeb && const bool.fromEnvironment('INTEGRATION_TEST')) {
      // Skip media initialization on Web CI to avoid MEDIA_ERR_SRC_NOT_SUPPORTED
      return null;
    }
    if ((widget.event.messageType != MessageTypes.Video &&
            widget.event.messageType != MessageTypes.Audio) ||
        isLinuxPlatform ||
        isWindowsPlatform ||
        isMacOSPlatform) {
      // we can't display videos on desktop, see videoplayer
      return null;
    }

    if (e.room.encrypted) {
      if (kIsWeb) {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(await getDecryptedFileObjectUrlForEvent(e)),
        );
        controller.initialize().catchError((_) {
          /* ignore media format errors */
        });
        return controller;
      }

      // download and decrypt the file if the room is encrypted
      final controller = videoControllerFromFile(
        await getDecryptedFileForEvent(e),
      );
      controller.initialize().catchError((_) {
        /* ignore media format errors */
      });
      return controller;
    }

    final controller = VideoPlayerController.networkUrl(
      (await e.getAttachmentUri())!,
    ); // todo... null check
    controller.initialize().catchError((_) {
      /* ignore media format errors */
    });
    return controller;
  }

  @override
  void initState() {
    super.initState();

    relatedFiles
        .then((f) {
          files = f;
          if (mounted) {
            setState(() {});
          }
        })
        .catchError((e) {
          // Ignore errors from relatedFiles (e.g. M_NOT_FOUND when the event
          // context is no longer available on the server). The widget will
          // gracefully show only the primary file that was already set.
          debugPrint('FileDisplayContainer: relatedFiles error (ignored): $e');
        });
  }

  Future<String> getDecryptedFileObjectUrlForEvent(Event e) async {
    final file = await widget.event.downloadAndDecryptAttachment();
    final blob = web.Blob([file.bytes.toJS].toJS);
    return web.URL.createObjectURL(blob);
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
    return Row(
      children: [
        if (files.length > 1) ...[
          IconButton(
            onPressed:
                () => carouselController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.linear,
                ),
            icon: const Icon(Icons.arrow_back_ios),
          ),
        ],
        Expanded(
          child: CarouselSlider.builder(
            carouselController: carouselController,
            itemCount: files.length,
            options: CarouselOptions(enableInfiniteScroll: false),
            itemBuilder: (
              BuildContext context,
              int itemIndex,
              int pageViewIndex,
            ) {
              return Column(
                children: [
                  Text(
                    files[itemIndex].displayEvent.calcUnlocalizedBody(
                      hideReply: true,
                      hideEdit: true,
                      plaintextBody: true,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      child: FileDisplay(file: files[itemIndex]),
                      onTap: () {
                        showDialog<String>(
                          context: context,
                          builder:
                              (BuildContext context) => Dialog(
                                child: DismissiblePage(
                                  onDismissed: () {
                                    Navigator.of(context).pop();
                                  },
                                  // Note that scrollable widget inside DismissiblePage might limit the functionality
                                  // If scroll direction matches DismissiblePage direction
                                  direction:
                                      DismissiblePageDismissDirection.multi,
                                  isFullScreen: true,
                                  child: Hero(
                                    tag: itemIndex,
                                    child: FileDisplay(file: files[itemIndex]),
                                  ),
                                ),
                              ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (files.length > 1) ...[
          IconButton(
            onPressed:
                () => carouselController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.linear,
                ),
            icon: const Icon(Icons.arrow_forward_ios),
          ),
        ],
      ],
    );
  }
}
