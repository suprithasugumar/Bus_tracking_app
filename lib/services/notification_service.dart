import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firestore_service.dart';

/// Top-level background message handler required by FirebaseMessaging.
/// Must be a top-level function with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotificationService] Background message received: ${message.messageId}');
}

/// Manages local push notifications and Firebase Cloud Messaging (FCM).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final FirestoreService _firestoreService = FirestoreService();

  static const String channelId = 'bus_tracking_channel';
  static const String channelName = 'Bus Tracking Notifications';
  static const String channelDesc =
      'Alerts for live bus tracking, delays, breakdowns, emergency SOS, and stop proximity';

  /// Initialize the notification plugin and FCM listeners. Call in main().
  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(initSettings);

    // Explicitly create high-importance Android Notification Channel
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(channel);
    }

    // Request FCM push notification permission
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[NotificationService] FCM Authorization status: ${settings.authorizationStatus}');

    // Heads-up banners even when app is in foreground
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground FCM listener with strict per-route isolation
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Foreground FCM received: ${message.notification?.title}');
      
      final msgRouteId = message.data['routeId'] as String?;
      final activeTarget = _currentViewingRouteId ?? _defaultRouteId;
      
      // Strict cross-route prevention: drop notifications for routes other than currently active/default
      if (msgRouteId != null && msgRouteId.isNotEmpty && activeTarget != null && activeTarget.isNotEmpty) {
        if (msgRouteId.toLowerCase() != activeTarget.toLowerCase()) {
          debugPrint('[NotificationService] Filtered out cross-route notification: msg is for $msgRouteId, but active is $activeTarget');
          return;
        }
      }

      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] ?? '📢 Route Update';
      final body = notification?.body ?? message.data['message'] ?? message.data['body'] ?? '';

      if (title.isNotEmpty || body.isNotEmpty) {
        show(
          id: message.messageId.hashCode,
          title: title,
          body: body,
        );
      }
    });
  }

  /// Synchronize FCM device token with the user's Firestore document
  static Future<void> syncUserToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestoreService.saveFcmToken(uid, token);
        debugPrint('[NotificationService] Synced FCM token for user $uid');
      }

      // Listen for token rotations
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _firestoreService.saveFcmToken(uid, newToken);
      });
    } catch (e) {
      debugPrint('[NotificationService] Error syncing FCM token: $e');
    }
  }

  /// Show a high-priority heads-up local notification.
  static Future<void> show({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id == 0 ? DateTime.now().millisecondsSinceEpoch ~/ 1000 : id,
      title,
      body,
      details,
    );
  }

  /// Notify that the bus is approaching a specific stop (~500 m).
  static Future<void> busApproachingStop(String stopName, int etaMinutes) async {
    await show(
      id: 101,
      title: '🚌 Bus Approaching Your Stop!',
      body: 'The bus is ~500m away from $stopName (${etaMinutes > 0 ? '$etaMinutes min ETA' : 'Arriving now'}).',
    );
  }

  /// Notify that the bus has arrived at a student's stop.
  static Future<void> busArrivedAtStop(String stopName) async {
    await show(
      id: 102,
      title: '✅ Bus Arrived at Stop',
      body: 'The bus has reached $stopName. Board safely!',
    );
  }

  /// SOS confirmation notification.
  static Future<void> sosSent() async {
    await show(
      id: 103,
      title: '🆘 Emergency Alert Broadcasted',
      body: 'Your emergency alert has been sent to transit operations and campus security.',
    );
  }

  static String? _currentViewingRouteId;
  static String? _defaultRouteId;
  static String? _activeSubscribedTopic;

  static String? get currentViewingRouteId => _currentViewingRouteId;
  static String? get defaultRouteId => _defaultRouteId;

  /// Sets the student's persistent default route (used for background notifications even when logged out).
  static Future<void> setDefaultRoute(String? defaultRouteId) async {
    _defaultRouteId = defaultRouteId;
    if (_currentViewingRouteId == null && defaultRouteId != null && defaultRouteId.isNotEmpty) {
      await _syncSubscribedTopic('route_$defaultRouteId');
    }
  }

  /// Sets the route the user is currently viewing on screen.
  /// If set to null, reverts background subscription to the student's default route.
  static Future<void> setCurrentViewingRoute(String? routeId) async {
    _currentViewingRouteId = routeId;
    if (routeId != null && routeId.isNotEmpty) {
      await _syncSubscribedTopic('route_$routeId');
    } else if (_defaultRouteId != null && _defaultRouteId!.isNotEmpty) {
      await _syncSubscribedTopic('route_$_defaultRouteId');
    } else if (_activeSubscribedTopic != null) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_activeSubscribedTopic!);
        _activeSubscribedTopic = null;
      } catch (_) {}
    }
  }

  static Future<void> _syncSubscribedTopic(String targetTopic) async {
    try {
      if (_activeSubscribedTopic != null && _activeSubscribedTopic != targetTopic) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_activeSubscribedTopic!);
        debugPrint('[NotificationService] Unsubscribed from old topic $_activeSubscribedTopic');
      }
      await FirebaseMessaging.instance.subscribeToTopic(targetTopic);
      _activeSubscribedTopic = targetTopic;
      debugPrint('[NotificationService] Subscribed to topic $targetTopic');
    } catch (e) {
      debugPrint('[NotificationService] Error syncing topic subscription: $e');
    }
  }

  /// Subscribe to route specific notifications topic (legacy wrapper)
  static Future<void> subscribeToRoute(String routeId) async {
    await setCurrentViewingRoute(routeId);
  }

  /// Unsubscribe from route specific notifications topic (legacy wrapper)
  static Future<void> unsubscribeFromRoute(String routeId) async {
    if (_currentViewingRouteId == routeId) {
      await setCurrentViewingRoute(null);
    }
  }
}

