import 'dart:async';

import 'file_display.dart';

import '/shared/platform/platform.dart';
import '/shared/utils/file_decryption_helper.dart';
import '/shared/utils/share_helper.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:carousel_slider/carousel_slider.dart';
import '/shared/platform/web_helpers.dart';
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
  final List<String> _blobUrls = [];

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
          Uri.parse(await _getDecryptedBlobUrlAndTrack(e)),
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

    final uri = await e.getAttachmentUri();
    if (uri == null) return null;
    final controller = VideoPlayerController.networkUrl(uri);
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

  Future<String> _getDecryptedBlobUrlAndTrack(Event e) async {
    final url = await getDecryptedFileObjectUrlForEvent(e);
    _blobUrls.add(url);
    return url;
  }

  @override
  void dispose() {
    for (final file in files) {
      file.videoController?.dispose();
    }
    if (kIsWeb) {
      for (final url in _blobUrls) {
        revokeBlobUrl(url);
      }
    }
    super.dispose();
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
                  Builder(
                    builder: (context) {
                      final event = files[itemIndex].displayEvent;
                      final body = event.body;
                      final filename = event.content.tryGet<String>('filename');
                      final hasCaption = filename != null && body != filename;
                      if (!hasCaption) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: Text(body),
                      );
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      child: FileDisplay(file: files[itemIndex]),
                      onTap: () {
                        showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'Dismiss',
                          barrierColor: Colors.black,
                          transitionDuration: const Duration(milliseconds: 200),
                          pageBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                          ) {
                            return _FullscreenImageViewer(
                              file: files[itemIndex],
                              parentEvent: widget.event,
                            );
                          },
                          transitionBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                            child,
                          ) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
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

/// Reddit-style fullscreen image viewer with auto-hiding controls.
///
/// Controls (close + share) appear on tap and auto-hide after 3 seconds of
/// inactivity. Supports pinch-to-zoom/pan via [InteractiveViewer] and
/// swipe-to-dismiss via [DismissiblePage].
class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({required this.file, required this.parentEvent});

  final ({
    Event origEvent,
    Event displayEvent,
    VideoPlayerController? videoController,
  })
  file;

  /// The root post event — used to generate a shareable link.
  final Event parentEvent;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _startHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DismissiblePage(
        onDismissed: () => Navigator.of(context).pop(),
        direction: DismissiblePageDismissDirection.vertical,
        isFullScreen: true,
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // --- Image with pinch-to-zoom ---
              InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                child: Center(child: FileDisplay(file: widget.file)),
              ),

              // --- Auto-hiding controls overlay ---
              AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: Stack(
                    children: [
                      // Close button — top right
                      Positioned(
                        top: 16,
                        right: 16,
                        child: SafeArea(
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                      // Share button — top right, below close
                      Positioned(
                        top: 68,
                        right: 16,
                        child: SafeArea(
                          child: IconButton(
                            onPressed: () {
                              ShareHelper.sharePost(
                                context,
                                widget.parentEvent.eventId,
                                widget.parentEvent.roomId ?? '',
                              );
                              // Reset the auto-hide timer after interaction
                              _startHideTimer();
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.share_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
