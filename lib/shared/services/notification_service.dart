import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matrix/matrix.dart';

/// Manages local push notifications for incoming Matrix events.
///
/// This service does NOT require Firebase, APNs, or any external push gateway.
/// It works by listening to [Client.onNotification] (which evaluates incoming
/// sync events against the user's Matrix push rules) and displaying local
/// notifications via [flutter_local_notifications].
///
/// Background delivery on Android is handled by [workmanager] (periodic sync
/// every ~15 minutes). iOS uses [background_fetch] similarly.
///
/// Usage:
/// ```dart
/// final notificationService = NotificationService();
/// await notificationService.init(client);
/// ```
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _androidChannelId = 'substitution_notifications';
  static const String _androidChannelName = 'Substitution';
  static const String _androidChannelDesc =
      'Notifications for new messages and posts';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<Event>? _notificationSub;
  bool _initialized = false;
  int _notificationId = 0;

  /// Initializes the notification plugin and starts listening for events.
  Future<void> init(Client client) async {
    if (_initialized) return;
    _initialized = true;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create the Android notification channel.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Request iOS permission
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Listen for notification-worthy events from the Matrix client.
    // [Client.onNotification] already filters events against the user's push
    // rules, so every event emitted here should be shown as a notification.
    _notificationSub = client.onNotification.stream.listen(
      (event) => _showNotification(event),
    );

    debugPrint('NotificationService: initialized');
  }

  /// Shows a local notification for a Matrix event.
  Future<void> _showNotification(Event event) async {
    // Skip notifications for own events
    if (event.senderId == event.room.client.userID) return;
    // Skip in web context (web has its own notification API)
    if (kIsWeb) return;

    final sender = event.senderFromMemoryOrFallback;
    final senderName = sender.displayName ?? event.senderId;
    final roomName = event.room.name;

    String title;
    String body;

    if (event.room.isDirectChat) {
      title = senderName;
      body = _extractBodyText(event);
    } else {
      title = '$senderName in $roomName';
      body = _extractBodyText(event);
    }

    await _plugin.show(
      _notificationId++,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // Payload encodes the room and event for deep-linking on tap.
      payload: '${event.roomId}|${event.eventId}',
    );
  }

  String _extractBodyText(Event event) {
    switch (event.messageType) {
      case MessageTypes.Image:
        return '📷 Image';
      case MessageTypes.Video:
        return '🎥 Video';
      case MessageTypes.Audio:
        return '🎵 Audio message';
      case MessageTypes.File:
        return '📎 File: ${event.body}';
      case MessageTypes.Location:
        return '📍 Location';
      case MessageTypes.Sticker:
        return '🏷 Sticker';
      case MessageTypes.Emote:
        final senderName =
            event.senderFromMemoryOrFallback.displayName ?? event.senderId;
        return '* $senderName ${event.body}';
      default:
        return event.plaintextBody.isNotEmpty
            ? event.plaintextBody
            : event.body;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Deep-link navigation on notification tap.
    // The payload is `roomId|eventId`.
    final payload = response.payload;
    if (payload == null) return;
    final parts = payload.split('|');
    if (parts.length < 2) return;
    final roomId = parts[0];
    final eventId = parts[1];
    debugPrint(
      'NotificationService: tapped notification for room=$roomId event=$eventId',
    );
    // Navigation is handled externally — store the intent so the app can
    // consume it on the next frame.
    _pendingNavigationRoomId = roomId;
    _pendingNavigationEventId = eventId;
  }

  /// The room/event the user tapped in a notification, if any.
  /// Consumed by the app shell on the next build frame.
  static String? _pendingNavigationRoomId;
  static String? _pendingNavigationEventId;

  static ({String roomId, String eventId})? consumePendingNavigation() {
    final roomId = _pendingNavigationRoomId;
    final eventId = _pendingNavigationEventId;
    if (roomId == null || eventId == null) return null;
    _pendingNavigationRoomId = null;
    _pendingNavigationEventId = null;
    return (roomId: roomId, eventId: eventId);
  }

  /// Cancels the notification subscription and cleans up resources.
  Future<void> dispose() async {
    await _notificationSub?.cancel();
    _notificationSub = null;
    _initialized = false;
  }
}
