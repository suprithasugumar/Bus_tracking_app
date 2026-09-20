/// Central configuration constants for GPS tracking, geofencing, and staleness detection.
class TrackingConstants {
  /// Geofence radius in meters for automatically detecting and marking a bus stop as completed.
  /// Default configured to 80.0 meters.
  static const double stopRadiusMeters = 80.0;

  /// Minimum distance filter in meters before GPS emits a new location.
  /// Set to 0 so stationary buses (at stops/traffic/screen off) continuously broadcast updates.
  static const int locationDistanceFilterMeters = 0;

  /// Minimum movement distance in meters to trigger an immediate Firestore location write.
  static const double minMovementDistanceMeters = 15.0;

  /// Interval duration between continuous location updates (1 second for ultra-fast, smooth live tracking).
  static const Duration locationInterval = Duration(milliseconds: 1000);

  /// Heartbeat interval to refresh Firestore timestamp if device is stationary (10s to conserve Firestore writes).
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// Seconds of inactivity after which an active bus is marked as STALE (yellow/amber warning).
  static const int staleTimeoutSeconds = 25;

  /// Seconds of inactivity after which an active bus is considered OFFLINE (gray/inactive).
  static const int offlineTimeoutSeconds = 60;

  /// Title for Android persistent foreground service notification.
  static const String notificationTitle = 'VIT Bus Tracking Active';

  /// Channel ID for Android foreground location tracking service.
  static const String notificationChannelId = 'bus_location_tracking_channel';

  /// Channel Name for Android foreground location tracking service.
  static const String notificationChannelName = 'Live Bus Location Service';
}
