import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '/shared/widgets/mxc_image.dart';

/// A reusable avatar widget that loads an image from an `mxc://` URI
/// with proper authenticated media support.
///
/// Falls back to showing the first letter of [name] in a colored circle
/// when no [mxContent] is provided or when the image fails to load.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    this.mxContent,
    this.name,
    required this.client,
    this.size = 44,
    this.fontSize,
  });

  /// The `mxc://` URI for the avatar image. May be null.
  final Uri? mxContent;

  /// Display name used for the fallback letter avatar.
  final String? name;

  /// The Matrix client (needed for URI resolution and auth).
  final Client client;

  /// Diameter of the avatar circle.
  final double size;

  /// Font size for the fallback letter. Defaults to size * 0.4.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = size / 2;
    final fallbackFontSize = fontSize ?? size * 0.4;

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        _initial,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: fallbackFontSize,
        ),
      ),
    );

    if (mxContent == null) return fallback;

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: MxcImage(
          uri: mxContent!,
          client: client,
          width: size,
          height: size,
          fit: BoxFit.cover,
          isThumbnail: true,
          placeholder: (_) => fallback,
          errorBuilder: (_, __) => fallback,
        ),
      ),
    );
  }

  String get _initial {
    final n = name ?? '';
    if (n.isEmpty) return '?';
    return n[0].toUpperCase();
  }
}
