import '/post/widgets/videoplayercontrolsoverlay.dart';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:octo_image/octo_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

// TODO this one shows one file and is used in filecomponent.
// filecomponent shows a list of this component
// make the naming somehow better
class FileDisplay extends StatefulWidget {
  const FileDisplay({super.key, required this.file});

  final ({
    Event origEvent,
    Event displayEvent,
    VideoPlayerController? videoController
  }) file;

  @override
  FileDisplayState createState() => FileDisplayState();
}

class FileDisplayState extends State<FileDisplay> {
  VideoPlayerController?
      _controller; // can't use late as it might never get initialized at all (see showVideo)

  CarouselController carouselController = CarouselController();

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
    final blob = html.Blob([file.bytes]);
    return html.Url.createObjectUrlFromBlob(blob);
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.file.displayEvent.messageType) {
      // TODO: m.emote ? :)

      // TODO: make each type a widget so we can use if else etc., would make things much more clean
      MessageTypes.Image => widget.file.displayEvent.room.encrypted
          ? // download and decrypt the file if the room is encrypted
          kIsWeb
              ? FutureBuilder(
                  // download decrypted file and make it an url
                  future: getDecryptedFileObjectUrlForEvent(
                      widget.file.displayEvent),
                  builder: (ctx, snapshot) {
                    if (snapshot.hasData) {
                      return Image.network(snapshot.data!, fit: BoxFit.contain);
                    }
                    return const Text("post.widgets.filedisplay.decrypting")
                        .tr();
                  })
              : FutureBuilder(
                  // download decrypted file
                  future: getDecryptedFileForEvent(widget.file.displayEvent),
                  builder: (ctx, snapshot) {
                    if (snapshot.hasData) {
                      return Image.file(snapshot.data!, fit: BoxFit.contain);
                    }
                    return const Text("post.widgets.filedisplay.decrypting")
                        .tr();
                  })
          : /*Image.network(
                            files[itemIndex]
                                .displayEvent
                                .getAttachmentUrl()
                                .toString(),
                            fit: BoxFit.contain),*/
          OctoImage(
              image: CachedNetworkImageProvider(
                  widget.file.displayEvent.getAttachmentUrl().toString()),
              errorBuilder: OctoError.icon(color: Colors.red),
              fit: BoxFit.cover,
            ),
      MessageTypes.Video => // Todo: Styling... mby use a card?
        _controller == null
            ? const Text("post.widgets.filedisplay.video_desktop_error").tr()
            : Column(children: [
                Center(
                  child: _controller!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: Stack(
                            children: [
                              VideoPlayer(_controller!),
                              VideoProgressIndicator(_controller!,
                                  allowScrubbing: true),
                              VidePlayerControlsOverlay(
                                  controller: _controller!),
                            ],
                          ))
                      : Container(),
                ),
              ]),
      MessageTypes.Audio => Container(), // TODO display audio messages
      String() => Container() // handled elsewhere
    };
  }
}
