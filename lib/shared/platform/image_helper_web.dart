// Image helper - web implementation
import 'package:flutter/material.dart';

/// Creates an Image widget from a file path. Web version uses Image.network.
Widget imageFromPath(String path, {BoxFit? fit}) {
  return Image.network(path, fit: fit);
}
