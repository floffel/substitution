import 'video_player_controls_overlay.dart';

import '/shared/platform/platform.dart';
import '/shared/utils/file_decryption_helper.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '/shared/platform/web_helpers.dart';
import 'package:easy_localization/easy_localization.dart';

// TODO this one shows one file and is used in filecomponent.
// filecomponent shows a list of this component
// make the naming somehow better
class FileDisplay extends StatefulWidget {
  const FileDisplay({super.key, required this.file});

  final ({
    Event origEvent,
    Event displayEvent,
    VideoPlayerController? videoController,
  })
  file;

  @override
  FileDisplayState createState() => FileDisplayState();
}

class FileDisplayState extends State<FileDisplay> {
  VideoPlayerController? _controller;
  CarouselController carouselController = CarouselController();
  final List<String> _blobUrls = [];

  @override
  void initState() {
    super.initState();
    _controller = widget.file.videoController;
  }

  @override
  void didUpdateWidget(FileDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file.videoController != oldWidget.file.videoController) {
      _controller = widget.file.videoController;
    }
  }

  Future<String> _getDecryptedBlobUrlAndTrack(Event e) async {
    final url = await getDecryptedFileObjectUrlForEvent(e);
    _blobUrls.add(url);
    return url;
  }

  @override
  void dispose() {
    if (kIsWeb) {
      for (final url in _blobUrls) {
        revokeBlobUrl(url);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.file.displayEvent.messageType) {
      // TODO: m.emote ? :)

      // TODO: make each type a widget so we can use if else etc., would make things much more clean
      MessageTypes.Image =>
        kIsWeb
            ? FutureBuilder(
              // download decrypted file and make it an url
              future: _getDecryptedBlobUrlAndTrack(widget.file.displayEvent),
              builder: (ctx, snapshot) {
                if (snapshot.hasData) {
                  return Image.network(snapshot.data!, fit: BoxFit.contain);
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "post.widgets.filedisplay.decrypt_error",
                        ).tr(),
                      ],
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 8),
                      const Text("post.widgets.filedisplay.decrypting").tr(),
                    ],
                  ),
                );
              },
            )
            : FutureBuilder(
              // download decrypted file
              future: getDecryptedFileForEvent(widget.file.displayEvent),
              builder: (ctx, snapshot) {
                if (snapshot.hasData) {
                  return imageFromFile(snapshot.data!, fit: BoxFit.contain);
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "post.widgets.filedisplay.decrypt_error",
                        ).tr(),
                      ],
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 8),
                      const Text("post.widgets.filedisplay.decrypting").tr(),
                    ],
                  ),
                );
              },
            ),
      MessageTypes.Video => // Todo: Styling... mby use a card?
        _controller == null
            ? const Text("post.widgets.filedisplay.video_desktop_error").tr()
            : Column(
              children: [
                Center(
                  child:
                      _controller!.value.isInitialized
                          ? AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                VideoPlayer(_controller!),
                                VideoPlayerControlsOverlay(
                                  controller: _controller!,
                                ),
                                VideoProgressIndicator(
                                  _controller!,
                                  allowScrubbing: true,
                                ),
                              ],
                            ),
                          )
                          : const Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
      MessageTypes.Audio =>
        _controller == null
            ? const Text("post.widgets.filedisplay.audio_desktop_error").tr()
            : Column(
              children: [
                Center(
                  child:
                      _controller!.value.isInitialized
                          ? Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.audiotrack, size: 48),
                              AspectRatio(
                                aspectRatio:
                                    16 / 9, // Force aspect ratio for controls
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    VideoPlayerControlsOverlay(
                                      controller: _controller!,
                                    ),
                                    VideoProgressIndicator(
                                      _controller!,
                                      allowScrubbing: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                          : const CircularProgressIndicator(),
                ),
              ],
            ),
      String() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            const Text("post.widgets.filedisplay.unsupported_file").tr(),
          ],
        ),
      ),
    };
  }
}
