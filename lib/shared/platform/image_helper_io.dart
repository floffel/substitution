// Image helper - native (io) implementation
import 'dart:io';
import 'package:flutter/material.dart';

/// Creates an Image widget from a file path. Native version uses Image.file.
Widget imageFromPath(String path, {BoxFit? fit}) {
  return Image.file(File(path), fit: fit);
}
