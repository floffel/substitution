// Stub implementations for web platform where dart:io is not available.

import 'dart:typed_data';
import 'package:flutter/material.dart';

/// A stub File class for web. This should never actually be instantiated on web.
class File {
  final String path;
  File(this.path);

  Future<bool> exists() async => false;
  Future<File> writeAsBytes(Uint8List bytes) async => this;
}

/// Check if the current platform is Linux. Always false on web.
bool get isLinuxPlatform => false;

/// Check if the current platform is Windows. Always false on web.
bool get isWindowsPlatform => false;

/// Check if the current platform is macOS. Always false on web.
bool get isMacOSPlatform => false;

/// Create an Image widget from a File. On web, this is a no-op (should not be called).
Widget imageFromFile(File file, {BoxFit? fit}) {
  throw UnsupportedError('imageFromFile is not supported on web');
}
