// Video controller helper - web implementation
import 'package:video_player/video_player.dart';
import '/shared/platform/platform.dart';

/// Create a VideoPlayerController from a File. Not supported on web.
VideoPlayerController videoControllerFromFile(File file) {
  throw UnsupportedError('VideoPlayerController.file is not supported on web');
}
