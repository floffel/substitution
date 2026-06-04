import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '/shared/widgets/mxc_image.dart';

/// Circular avatar with a small camera button overlay, used at the top of
/// the room form.
///
/// Renders one of three sources in priority order:
/// 1. [pickedAvatarFile] — a file the user just selected (preview only).
/// 2. [existingAvatarUrl] — the current room avatar (mxc:// URI).
/// 3. The first letter of [nameFallback] (or a groups icon if empty).
class RoomAvatarPicker extends StatelessWidget {
  const RoomAvatarPicker({
    super.key,
    required this.pickedAvatarFile,
    required this.existingAvatarUrl,
    required this.nameFallback,
    required this.client,
    required this.onPickAvatar,
  });

  /// A file just chosen by the user (e.g. via the file picker). Takes
  /// priority over [existingAvatarUrl] for the preview.
  final XFile? pickedAvatarFile;

  /// The mxc:// URI of the room's current avatar (edit mode).
  final Uri? existingAvatarUrl;

  /// The room name — used to render the first-letter fallback avatar.
  final String nameFallback;

  /// Matrix client used to resolve mxc:// avatar URIs.
  final Client client;

  /// Invoked when the user taps the camera button.
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget avatarContent;
    if (pickedAvatarFile != null) {
      avatarContent = FutureBuilder<Uint8List>(
        future: pickedAvatarFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return CircleAvatar(
              radius: 52,
              backgroundImage: MemoryImage(snapshot.data!),
            );
          }
          return _defaultAvatarCircle(colorScheme, nameFallback);
        },
      );
    } else if (existingAvatarUrl != null) {
      avatarContent = SizedBox(
        width: 104,
        height: 104,
        child: ClipOval(
          child: MxcImage(
            uri: existingAvatarUrl!,
            client: client,
            width: 104,
            height: 104,
            fit: BoxFit.cover,
            placeholder: (_) => _defaultAvatarCircle(colorScheme, nameFallback),
            errorBuilder: (_, _) =>
                _defaultAvatarCircle(colorScheme, nameFallback),
          ),
        ),
      );
    } else {
      avatarContent = _defaultAvatarCircle(colorScheme, nameFallback);
    }

    return Stack(
      children: [
        avatarContent,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.camera_alt_rounded,
                color: colorScheme.onPrimary,
                size: 18,
              ),
              onPressed: onPickAvatar,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _defaultAvatarCircle(
    ColorScheme colorScheme,
    String name,
  ) {
    return CircleAvatar(
      radius: 52,
      backgroundColor: colorScheme.primaryContainer,
      child:
          name.isNotEmpty
              ? Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              )
              : Icon(
                Icons.groups_rounded,
                size: 40,
                color: colorScheme.onPrimaryContainer,
              ),
    );
  }
}
