import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matrix/matrix.dart';
import 'package:workmanager/workmanager.dart';

/// Unique name for the periodic background sync task.
const String _bgSyncTaskName = 'substitution_bg_sync';

/// Android notification channel constants (must match [NotificationService]).
const String _androidChannelId = 'substitution_notifications';
const String _androidChannelName = 'Substitution';
const String _androidChannelDesc = 'Notifications for new messages and posts';
const String _androidGroupKey = 'substitution_dm_group';

/// Top-level callback dispatcher required by workmanager.
///
/// This runs in a **separate isolate** from the main Flutter app. It must be a
/// top-level or static function. It initialises a lightweight Matrix client,
/// performs a single sync, checks for new messages in DM rooms, and shows local
/// notifications for any unread conversations.
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('BackgroundSync: task "$taskName" started');

    try {
      // Initialise a background-only Matrix client using the same database
      // name as the foreground app so we share session credentials.
      final database = await MatrixSdkDatabase.init('Substitution');

      final client = Client('Substitution', database: database);

      await client.init(waitForFirstSync: false);

      if (!client.isLogged()) {
        debugPrint('BackgroundSync: not logged in — skipping');
        await client.dispose();
        return true;
      }

      // Perform a single sync to fetch new events.
      await client.oneShotSync();

      // Check DM rooms for unread messages and show notifications.
      final plugin = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
          macOS: iosSettings,
        ),
      );

      int notifId = 1000; // offset to avoid clashing with foreground IDs

      for (final room in client.rooms) {
        if (room.notificationCount <= 0) continue;

        final lastEvent = room.lastEvent;
        if (lastEvent == null) continue;
        if (lastEvent.senderId == client.userID) continue;

        final sender = lastEvent.senderFromMemoryOrFallback;
        final senderName = sender.displayName ?? lastEvent.senderId;

        final String title;
        final String body;

        if (room.isDirectChat) {
          title = senderName;
        } else {
          title = '$senderName in ${room.name}';
        }

        switch (lastEvent.messageType) {
          case MessageTypes.Image:
            body = '📷 Image';
          case MessageTypes.Video:
            body = '🎥 Video';
          case MessageTypes.Audio:
            body = '🎵 Audio message';
          case MessageTypes.File:
            body = '📎 File: ${lastEvent.body}';
          case MessageTypes.Location:
            body = '📍 Location';
          default:
            body =
                lastEvent.plaintextBody.isNotEmpty
                    ? lastEvent.plaintextBody
                    : lastEvent.body;
        }

        await plugin.show(
          id: notifId++,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelId,
              _androidChannelName,
              channelDescription: _androidChannelDesc,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              groupKey: _androidGroupKey,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              threadIdentifier: _androidGroupKey,
            ),
          ),
          payload: '${room.id}|${lastEvent.eventId}',
        );
      }

      await client.dispose();
      debugPrint('BackgroundSync: task completed');
    } catch (e, stack) {
      debugPrint('BackgroundSync: error: $e\n$stack');
    }

    return true;
  });
}

/// Registers (or cancels) the periodic background sync task via workmanager.
class BackgroundSyncService {
  BackgroundSyncService._();

  /// Register the periodic background sync.
  ///
  /// On Android the minimum interval is 15 minutes (WorkManager limitation).
  /// On iOS the system decides when to grant execution time (typically every
  /// 15-30 minutes, but can be longer depending on usage patterns).
  static Future<void> register() async {
    if (kIsWeb) return;

    await Workmanager().initialize(backgroundSyncCallbackDispatcher);

    await Workmanager().registerPeriodicTask(
      _bgSyncTaskName,
      _bgSyncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    debugPrint('BackgroundSyncService: periodic task registered');
  }

  /// Cancel the background sync (e.g. on logout).
  static Future<void> cancel() async {
    if (kIsWeb) return;
    await Workmanager().cancelByUniqueName(_bgSyncTaskName);
    debugPrint('BackgroundSyncService: periodic task cancelled');
  }
}
