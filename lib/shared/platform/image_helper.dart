// Conditional export: uses native Image.file on io, Image.network on web.
export 'image_helper_web.dart' if (dart.library.io) 'image_helper_io.dart';
