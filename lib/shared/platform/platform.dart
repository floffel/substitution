// Conditional export: uses dart:io on native, stubs on web.
export 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';
