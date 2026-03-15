// Video controller helper - native (io) implementation
import 'dart:io' as io;
import 'package:video_player/video_player.dart';

/// Create a VideoPlayerController from a File. Native version.
VideoPlayerController videoControllerFromFile(io.File file) {
  return VideoPlayerController.file(file);
}
