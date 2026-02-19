// Native (io) implementations for platforms that support dart:io.

export 'dart:io' show File;
import 'dart:io' show File, Platform;
import 'package:flutter/material.dart';

/// Check if the current platform is Linux.
bool get isLinuxPlatform => Platform.isLinux;

/// Check if the current platform is Windows.
bool get isWindowsPlatform => Platform.isWindows;

/// Check if the current platform is macOS.
bool get isMacOSPlatform => Platform.isMacOS;

/// Create an Image widget from a File. Native version uses Image.file.
Widget imageFromFile(File file, {BoxFit? fit}) {
  return Image.file(file, fit: fit);
}
