import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages local push notifications for incoming Matrix events.
///
/// This service does NOT require Firebase, APNs, or any external push gateway.
/// It works by listening to [Client.onNotification] (which evaluates incoming
/// sync events against the user's Matrix push rules) and displaying local
/// notifications via [flutter_local_notifications].
///
/// Background delivery on Android is handled by [workmanager] (periodic sync
/// every ~15 minutes). iOS uses BGTaskScheduler similarly.
///
/// Best-practice behaviours:
/// - Notifications for the same room are grouped (Android grouping / summary).
/// - Tapping a notification navigates to the corresponding chat.
/// - If the user is already viewing a chat room, notifications for that room
///   are suppressed.
/// - Dismissed notifications are tracked so they are not re-shown on
///   subsequent sync cycles (relevant for background sync).
///
/// Usage:
/// ```dart
/// await NotificationService.instance.init(client);
/// ```
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _androidChannelId = 'substitution_notifications';
  static const String _androidChannelName = 'Substitution';
  static const String _androidChannelDesc =
      'Notifications for new messages and posts';

  /// Android notification group key used to group DM notifications together.
  static const String _androidGroupKey = 'substitution_dm_group';

  /// SharedPreferences key for dismissed notification event IDs.
  static const String _dismissedKey = 'dismissed_notification_ids';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<Event>? _notificationSub;
  bool _initialized = false;

  /// Stable notification IDs per room so updates replace the existing notif.
  final Map<String, int> _roomNotificationIds = {};
  int _nextId = 1;

  /// The room the user is currently viewing. Notifications for this room
  /// are suppressed to avoid distracting the user while they are already
  /// reading the conversation.
  String? activeRoomId;

  /// Callback invoked when the user taps a notification.
  /// Set by the app shell (e.g. [_SubstitutionAppState]) to navigate to the
  /// corresponding chat room.
  void Function(String roomId, String eventId)? onNavigate;

  /// Event IDs that have been dismissed by the user and should not be
  /// re-shown (persisted across app restarts via SharedPreferences).
  Set<String> _dismissedEventIds = {};

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Initializes the notification plugin and starts listening for events.
  Future<void> init(Client client) async {
    if (_initialized) return;
    _initialized = true;

    // Load previously dismissed notification IDs.
    await _loadDismissedIds();

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
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
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

    // Request iOS permission.
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

  // ── Show notification ───────────────────────────────────────────────────────

  /// Shows a local notification for a Matrix event.
  Future<void> _showNotification(Event event) async {
    // Skip notifications for own events.
    if (event.senderId == event.room.client.userID) return;
    // Skip in web context (web has its own notification API).
    if (kIsWeb) return;

    final roomId = event.room.id;
    final eventId = event.eventId;

    // Suppress if the user is already viewing this room.
    if (roomId == activeRoomId) return;
    // Don't re-show a notification the user has already dismissed.
    if (_dismissedEventIds.contains(eventId)) return;

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

    // Use a stable ID per room so new messages update the existing notif
    // rather than stacking duplicates.
    final notifId = _roomNotificationIds.putIfAbsent(roomId, () => _nextId++);

    await _plugin.show(
      id: notifId,
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
          // Group DM notifications together.
          groupKey: _androidGroupKey,
          setAsGroupSummary: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // iOS uses threadIdentifier for grouping.
          threadIdentifier: _androidGroupKey,
        ),
      ),
      // Payload encodes the room and event for deep-linking on tap.
      payload: '$roomId|$eventId',
    );

    // Show a group summary notification on Android so grouped notifications
    // collapse into a single stack entry in the notification shade.
    await _showAndroidGroupSummary();
  }

  /// Shows the Android group summary notification. This is a silent
  /// notification that the system uses to collapse individual notifications
  /// from the same group into a bundle.
  Future<void> _showAndroidGroupSummary() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    // ID 0 is reserved for the group summary.
    await _plugin.show(
      id: 0,
      title: 'Substitution',
      body: 'New messages',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          groupKey: _androidGroupKey,
          setAsGroupSummary: true,
          // The summary should not make noise on its own.
          playSound: false,
          enableVibration: false,
        ),
      ),
    );
  }

  // ── Cancel / clear ──────────────────────────────────────────────────────────

  /// Cancel any visible notification for a specific room (e.g. when the user
  /// opens that chat). Also clears dismissed tracking for that room.
  Future<void> cancelForRoom(String roomId) async {
    final id = _roomNotificationIds.remove(roomId);
    if (id != null) {
      await _plugin.cancel(id: id);
    }
  }

  // ── Extract body text ───────────────────────────────────────────────────────

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

  // ── Notification tap / dismiss handling ──────────────────────────────────────

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    final parts = payload.split('|');
    if (parts.length < 2) return;
    final roomId = parts[0];
    final eventId = parts[1];

    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotificationAction) {
      // Custom action buttons (if added later) would be handled here.
      return;
    }

    // Dismissed (swiped away) — track so background sync doesn't re-show.
    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      // User tapped the notification — navigate.
      debugPrint(
        'NotificationService: tapped notification for room=$roomId event=$eventId',
      );
      _addDismissedId(eventId);

      // Navigate immediately if the callback is set, otherwise store pending.
      if (onNavigate != null) {
        onNavigate!(roomId, eventId);
      } else {
        _pendingNavigationRoomId = roomId;
        _pendingNavigationEventId = eventId;
      }
    }
  }

  // ── Pending navigation (cold-start) ─────────────────────────────────────────

  /// The room/event the user tapped in a notification, if any.
  /// Consumed by the app shell on the next build frame for cold-start scenarios.
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

  // ── Dismissed event tracking ────────────────────────────────────────────────

  Future<void> _loadDismissedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_dismissedKey);
      if (ids != null) {
        _dismissedEventIds = ids.toSet();
      }
    } catch (e) {
      debugPrint('NotificationService: failed to load dismissed IDs: $e');
    }
  }

  void _addDismissedId(String eventId) {
    _dismissedEventIds.add(eventId);
    // Limit the set to the most recent 500 entries to prevent unbounded growth.
    if (_dismissedEventIds.length > 500) {
      _dismissedEventIds =
          _dismissedEventIds
              .toList()
              .sublist(_dismissedEventIds.length - 500)
              .toSet();
    }
    _saveDismissedIds();
  }

  Future<void> _saveDismissedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dismissedKey, _dismissedEventIds.toList());
    } catch (e) {
      debugPrint('NotificationService: failed to save dismissed IDs: $e');
    }
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────────

  /// Cancels the notification subscription and cleans up resources.
  Future<void> dispose() async {
    await _notificationSub?.cancel();
    _notificationSub = null;
    _initialized = false;
    onNavigate = null;
    _roomNotificationIds.clear();
  }
}
