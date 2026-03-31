import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '/shared/constants.dart';

/// Helper class for generating shareable URLs and invoking the share sheet.
class ShareHelper {
  ShareHelper._();

  /// Generates a web URL for a room feed.
  ///
  /// [roomIdOrAlias] should be the Matrix room ID (`!abc:server`) or
  /// alias (`#name:server`). The leading `#` is stripped for the URL path.
  static String roomUrl(String roomIdOrAlias) {
    final path =
        roomIdOrAlias.startsWith('#')
            ? roomIdOrAlias.substring(1)
            : roomIdOrAlias;
    return '${AppConstants.webBaseUrl}/feed/$path';
  }

  /// Generates a web URL for a user profile.
  static String profileUrl(String userId) {
    return '${AppConstants.webBaseUrl}/profile/${Uri.encodeComponent(userId)}';
  }

  /// Generates a web URL for a specific post.
  static String postUrl(String eventId, String roomId) {
    return '${AppConstants.webBaseUrl}/room/${Uri.encodeComponent(roomId)}/$eventId';
  }

  /// Shares a room link via the native share sheet (mobile) or copies to
  /// clipboard (web/desktop).
  static Future<void> shareRoom(
    BuildContext context,
    String roomIdOrAlias,
  ) async {
    final url = roomUrl(roomIdOrAlias);
    await _share(context, url, 'share.share_room'.tr());
  }

  /// Shares a user profile link.
  static Future<void> shareProfile(BuildContext context, String userId) async {
    final url = profileUrl(userId);
    await _share(context, url, 'share.share_profile'.tr());
  }

  /// Shares a post link.
  static Future<void> sharePost(
    BuildContext context,
    String eventId,
    String roomId,
  ) async {
    final url = postUrl(eventId, roomId);
    await _share(context, url, 'share.share_post'.tr());
  }

  static Future<void> _share(
    BuildContext context,
    String url,
    String subject,
  ) async {
    if (kIsWeb) {
      // On web, just copy to clipboard
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('share.link_copied'.tr()),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // On native platforms, use the share sheet
      final result = await Share.share(url, subject: subject);

      // If the share was dismissed, fall back to clipboard copy
      if (result.status == ShareResultStatus.dismissed && context.mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('share.link_copied'.tr()),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }
}
