import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Manages local push notifications.
/// Call [initialize] once in main.dart before runApp().
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize the notification plugin. Must be called in main().
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

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Show a high-priority local notification.
  static Future<void> show({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'bus_tracking_channel',
      'Bus Tracking',
      channelDescription: 'Alerts for live bus tracking updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }

  /// Notify that the bus is approaching a specific stop.
  static Future<void> busApproachingStop(String stopName, int eta) async {
    await show(
      id: 1,
      title: '🚌 Bus Approaching',
      body: 'Bus is $eta min away from $stopName',
    );
  }

  /// Notify that the bus has arrived at a stop.
  static Future<void> busArrivedAtStop(String stopName) async {
    await show(
      id: 2,
      title: '✅ Bus Arrived',
      body: 'Bus has reached $stopName',
    );
  }

  /// SOS confirmation notification.
  static Future<void> sosSent() async {
    await show(
      id: 3,
      title: '🆘 SOS Sent',
      body: 'Your emergency alert has been sent. Help is on the way.',
    );
  }

  /// Subscribe to route specific notifications
  static Future<void> subscribeToRoute(String routeId) async {
    await FirebaseMessaging.instance.subscribeToTopic('route_$routeId');
  }

  /// Unsubscribe from route specific notifications
  static Future<void> unsubscribeFromRoute(String routeId) async {
    await FirebaseMessaging.instance.unsubscribeFromTopic('route_$routeId');
  }
}
