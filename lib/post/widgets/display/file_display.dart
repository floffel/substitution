import 'video_player_controls_overlay.dart';

import '/shared/platform/platform.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:path_provider/path_provider.dart';
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

  Future<String> getDecryptedFileObjectUrlForEvent(Event e) async {
    final file = await e.downloadAndDecryptAttachment();
    final blob = web.Blob([file.bytes.toJS].toJS);
    return web.URL.createObjectURL(blob);
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
              future: getDecryptedFileObjectUrlForEvent(
                widget.file.displayEvent,
              ),
              builder: (ctx, snapshot) {
                if (snapshot.hasData) {
                  return Image.network(snapshot.data!, fit: BoxFit.contain);
                }
                return const Text("post.widgets.filedisplay.decrypting").tr();
              },
            )
            : FutureBuilder(
              // download decrypted file
              future: getDecryptedFileForEvent(widget.file.displayEvent),
              builder: (ctx, snapshot) {
                if (snapshot.hasData) {
                  return imageFromFile(snapshot.data!, fit: BoxFit.contain);
                }
                return const Text("post.widgets.filedisplay.decrypting").tr();
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
                          : Container(),
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
      String() => Container(), // handled elsewhere
    };
  }
}
