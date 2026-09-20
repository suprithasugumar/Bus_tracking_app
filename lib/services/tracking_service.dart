import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_model.dart';
import '../constants/tracking_constants.dart';
import '../utils/stop_utils.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

/// Central singleton service for managing driver background GPS tracking,
/// Android Foreground Service lifecycle, automated stop geofence detection,
/// and real-time Firestore synchronization.
class TrackingService {
  static final TrackingService instance = TrackingService._internal();
  factory TrackingService() => instance;
  TrackingService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;
  DateTime? _lastGpsUpdateTime;

  // ─── Reactive State Notifiers ─────────────────────────────────────────────
  final ValueNotifier<bool> isTrackingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> currentStopIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<String>> completedStopsNotifier =
      ValueNotifier<List<String>>([]);
  final ValueNotifier<Position?> lastPositionNotifier =
      ValueNotifier<Position?>(null);
  final ValueNotifier<String?> activeRouteNameNotifier =
      ValueNotifier<String?>(null);

  bool get isTracking => isTrackingNotifier.value;
  int get currentStopIndex => currentStopIndexNotifier.value;
  List<String> get completedStops => completedStopsNotifier.value;
  Position? get lastPosition => lastPositionNotifier.value;

  String? _activeDriverId;
  RouteModel? _activeRoute;
  DateTime? _tripStartTime;
  Position? _previousPosition;
  String? _currentTripId;

  // Stop state tracking for idempotency & geofence configuration
  final Set<int> _reachedStopIndices = {};
  final Set<int> _approachingStopIndices = {};
  final Map<String, dynamic> _stopStatuses = {};
  double _stopRadiusMeters = TrackingConstants.stopRadiusMeters;
  double _proximityRadiusMeters = 1200.0;
  double _jitterThresholdMeters = 50.0;
  DateTime? _lastStopTickTime;
  Position? _lastWrittenPosition;
  DateTime? _lastWrittenTime;

  String? get activeDriverId => _activeDriverId;
  RouteModel? get activeRoute => _activeRoute;
  DateTime? get tripStartTime => _tripStartTime;
  Map<String, dynamic> get stopStatuses => Map.unmodifiable(_stopStatuses);

  // ─── Permission Verification ──────────────────────────────────────────────

  /// Verifies and requests all required foreground & background permissions.
  Future<bool> checkAndRequestPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // ─── Trip Control ──────────────────────────────────────────────────────────

  /// Starts continuous background location tracking with Android Foreground Service.
  Future<bool> startTrip({
    required String driverId,
    required RouteModel route,
  }) async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return false;

    // Load dynamic geofencing configuration from Firestore
    try {
      final config = await _firestoreService.getTrackingConfig();
      _stopRadiusMeters = (config['stopRadiusMeters'] as num?)?.toDouble() ?? TrackingConstants.stopRadiusMeters;
      _proximityRadiusMeters = (config['proximityAlertRadiusMeters'] as num?)?.toDouble() ?? 1200.0;
      _jitterThresholdMeters = (config['jitterAccuracyThresholdMeters'] as num?)?.toDouble() ?? 50.0;
    } catch (_) {}

    // Stop any currently running tracking session cleanly first
    await _stopActiveStreamOnly();

    _activeDriverId = driverId;
    _activeRoute = route;
    _tripStartTime = DateTime.now();
    _currentTripId = 'trip_${DateTime.now().millisecondsSinceEpoch}';
    _lastWrittenPosition = null;
    _lastWrittenTime = null;

    // Reset stop progress and idempotency guards for the new trip
    _reachedStopIndices.clear();
    _approachingStopIndices.clear();
    _stopStatuses.clear();
    currentStopIndexNotifier.value = 0;
    completedStopsNotifier.value = [];
    activeRouteNameNotifier.value = route.routeName;
    isTrackingNotifier.value = true;

    // Obtain immediate first GPS fix
    try {
      final initialPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _handleNewPosition(initialPos);
    } catch (e) {
      debugPrint('[TrackingService] Could not obtain initial position: $e');
    }

    // Configure platform-specific location settings with Foreground Service
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: TrackingConstants.locationDistanceFilterMeters,
        intervalDuration: TrackingConstants.locationInterval,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: TrackingConstants.notificationTitle,
          notificationText: 'Live GPS broadcasting for ${route.routeName}',
          enableWakeLock: true,
          setOngoing: true,
          notificationIcon: const AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: TrackingConstants.locationDistanceFilterMeters,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: TrackingConstants.locationDistanceFilterMeters,
      );
    }

    // Subscribe to continuous location stream
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) => _handleNewPosition(position),
      onError: (error) {
        debugPrint('[TrackingService] Position stream error: $error');
      },
      cancelOnError: false,
    );

    // Start background heartbeat (every 10s) to keep Firestore live even if stationary / screen locked
    _startHeartbeatTimer();

    return true;
  }

  /// Handles each new GPS location update, evaluates stop proximity,
  /// and updates Firestore. Filters out jitter readings and throttles writes (every 10s or >15m).
  void _handleNewPosition(Position position) {
    // GPS Jitter handling: ignore readings with poor accuracy (> 50 meters)
    if (position.accuracy > _jitterThresholdMeters) {
      debugPrint('[TrackingService] Discarding GPS jitter (accuracy ${position.accuracy.toStringAsFixed(1)}m > ${_jitterThresholdMeters}m)');
      return;
    }

    _lastGpsUpdateTime = DateTime.now();
    _previousPosition = lastPositionNotifier.value;
    lastPositionNotifier.value = position;

    // Calculate heading / bearing angle in degrees
    double heading = position.heading;
    if (heading <= 0 && _previousPosition != null) {
      heading = _calculateBearing(
        _previousPosition!.latitude,
        _previousPosition!.longitude,
        position.latitude,
        position.longitude,
      );
    }

    // Evaluate automatic sequential stop detection (with N+1 auto-complete)
    final bool statusChanged = _evaluateStopProgress(position);

    // Throttled Firestore writes: write if status changed, OR moved > 15m, OR >= 10s elapsed
    final now = DateTime.now();
    double movedDistance = 999.0;
    if (_lastWrittenPosition != null) {
      movedDistance = Geolocator.distanceBetween(
        _lastWrittenPosition!.latitude,
        _lastWrittenPosition!.longitude,
        position.latitude,
        position.longitude,
      );
    }
    final elapsedSec = _lastWrittenTime != null
        ? now.difference(_lastWrittenTime!).inSeconds
        : 999;

    final shouldWrite = statusChanged ||
        movedDistance >= TrackingConstants.minMovementDistanceMeters ||
        elapsedSec >= 10;

    if (shouldWrite && _activeDriverId != null && _activeRoute != null) {
      _lastWrittenPosition = position;
      _lastWrittenTime = now;
      final speedKmH = (position.speed * 3.6).clamp(0.0, 150.0);

      _firestoreService.updateBusLocation(
        driverId: _activeDriverId!,
        latitude: position.latitude,
        longitude: position.longitude,
        routeName: _activeRoute!.routeName,
        routeId: _activeRoute!.routeId,
        busId: _activeRoute!.routeId,
        speed: speedKmH,
        heading: heading,
        isOnline: true,
        isTracking: true,
        currentStopIndex: currentStopIndexNotifier.value,
        completedStops: List<String>.from(completedStopsNotifier.value),
        stopStatuses: Map<String, dynamic>.from(_stopStatuses),
        tripId: _currentTripId,
      ).catchError((e) {
        debugPrint('[TrackingService] Firestore update error: $e');
      });
    }
  }

  /// Evaluates whether the bus is within the geofence radius of the NEXT uncompleted stop (N)
  /// or if stop N+1 is reached while N was unticked (in which case N is auto-completed).
  /// Returns true if a stop was ticked / status changed.
  bool _evaluateStopProgress(Position position) {
    if (_activeRoute == null) return false;
    final stops = _activeRoute!.stops;
    final coords = _activeRoute!.stopCoordinates;
    if (stops.isEmpty || coords.isEmpty) return false;

    final currentIndex = StopUtils.getNextStopIndex(
      stops: stops,
      completedStops: completedStopsNotifier.value,
      fallbackCurrentIndex: currentStopIndexNotifier.value,
      stopStatuses: _stopStatuses,
      isOnline: isTracking,
    );

    if (currentIndex == -1 || currentIndex >= stops.length || currentIndex >= coords.length) {
      return false; // All stops already reached
    }

    currentStopIndexNotifier.value = currentIndex;

    // Debounce: prevent duplicate triggers within 2 seconds
    final now = DateTime.now();
    if (_lastStopTickTime != null && now.difference(_lastStopTickTime!).inMilliseconds < 2000) {
      return false;
    }

    // 1. Check distance to next stop N
    final targetStopCoord = coords[currentIndex];
    final distanceToCurrent = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetStopCoord.latitude,
      targetStopCoord.longitude,
    );

    // 2. Check distance to stop N+1 (if available) for auto-complete logic
    double distanceToNext = 99999.0;
    if (currentIndex + 1 < stops.length && currentIndex + 1 < coords.length) {
      final nextStopCoord = coords[currentIndex + 1];
      distanceToNext = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        nextStopCoord.latitude,
        nextStopCoord.longitude,
      );
    }

    // Approaching Stop Alert: when within ~1200m (~3-5 mins ETA) of the upcoming stop
    if (distanceToCurrent <= _proximityRadiusMeters &&
        !_approachingStopIndices.contains(currentIndex) &&
        !_reachedStopIndices.contains(currentIndex)) {
      _approachingStopIndices.add(currentIndex);
      final approachingStopName = stops[currentIndex];
      _firestoreService.sendRouteNotification(
        routeId: _activeRoute!.routeId,
        message: '🚌 Bus is approaching $approachingStopName (Arriving in ~5 mins). Please be ready at your stop!',
        type: 'approaching',
        stopName: approachingStopName,
        stopIndex: currentIndex,
      ).catchError((e) {
        debugPrint('[TrackingService] Error sending approaching notification: $e');
      });
      NotificationService.busApproachingStop(approachingStopName, 5);
    }

    // Case A: Bus reached stop N+1 while stop N was unticked -> Auto-complete N, mark N+1 reached
    if (distanceToNext <= _stopRadiusMeters) {
      _lastStopTickTime = now;
      final stopN = stops[currentIndex];
      final stopNext = stops[currentIndex + 1];

      _reachedStopIndices.add(currentIndex);
      _reachedStopIndices.add(currentIndex + 1);

      _stopStatuses[currentIndex.toString()] = {
        'status': 'reached',
        'reachedAt': now.toIso8601String(),
        'stopName': stopN,
        'autoCompleted': true,
      };

      _stopStatuses[(currentIndex + 1).toString()] = {
        'status': 'reached',
        'reachedAt': now.toIso8601String(),
        'stopName': stopNext,
      };

      final currentCompleted = List<String>.from(completedStopsNotifier.value);
      if (!currentCompleted.contains(stopN)) currentCompleted.add(stopN);
      if (!currentCompleted.contains(stopNext)) currentCompleted.add(stopNext);
      completedStopsNotifier.value = currentCompleted;

      NotificationService.busArrivedAtStop(stopNext);
      _firestoreService.sendRouteNotification(
        routeId: _activeRoute!.routeId,
        message: '✅ Bus has arrived at $stopNext. Board safely!',
        type: 'arrival',
        stopName: stopNext,
        stopIndex: currentIndex + 1,
      ).catchError((e) {
        debugPrint('[TrackingService] Error sending arrival notification: $e');
      });

      if (currentIndex + 1 >= stops.length - 1) {
        _handleDestinationArrival(stopNext);
      } else {
        currentStopIndexNotifier.value = currentIndex + 2;
      }
      return true;
    }

    // Case B: Bus reached stop N within geofence radius
    if (distanceToCurrent <= _stopRadiusMeters && !_reachedStopIndices.contains(currentIndex)) {
      _lastStopTickTime = now;
      final reachedStopName = stops[currentIndex];
      _reachedStopIndices.add(currentIndex);

      _stopStatuses[currentIndex.toString()] = {
        'status': 'reached',
        'reachedAt': now.toIso8601String(),
        'stopName': reachedStopName,
      };

      final currentCompleted = List<String>.from(completedStopsNotifier.value);
      if (!currentCompleted.contains(reachedStopName)) {
        currentCompleted.add(reachedStopName);
        completedStopsNotifier.value = currentCompleted;
        NotificationService.busArrivedAtStop(reachedStopName);
        _firestoreService.sendRouteNotification(
          routeId: _activeRoute!.routeId,
          message: '✅ Bus has arrived at $reachedStopName. Board safely!',
          type: 'arrival',
          stopName: reachedStopName,
          stopIndex: currentIndex,
        ).catchError((e) {
          debugPrint('[TrackingService] Error sending arrival notification: $e');
        });
      }

      if (currentIndex >= stops.length - 1) {
        _handleDestinationArrival(reachedStopName);
      } else {
        currentStopIndexNotifier.value = currentIndex + 1;
      }
      return true;
    }

    return false;
  }


  /// Automatically concludes the trip when the bus reaches the final destination (VIT Chennai College).
  Future<void> _handleDestinationArrival(String finalStopName) async {
    if (_activeRoute == null || _activeDriverId == null) return;
    debugPrint('[TrackingService] Final destination reached: $finalStopName. Concluding trip.');

    try {
      await _firestoreService.sendRouteNotification(
        routeId: _activeRoute!.routeId,
        message: '🏁 Bus has safely arrived at final destination: $finalStopName (VIT Chennai). Trip completed!',
        type: 'completed',
      );
    } catch (_) {}

    // Allow 2 seconds for final GPS coordinate sync before archiving
    await Future.delayed(const Duration(seconds: 2));
    await endTrip();
  }

  /// Manual fallback to advance the current stop if GPS experiences an anomaly.
  Future<void> markCurrentStopManually() async {
    if (_activeRoute == null) return;
    final stops = _activeRoute!.stops;
    final currentIndex = StopUtils.getNextStopIndex(
      stops: stops,
      completedStops: completedStopsNotifier.value,
      fallbackCurrentIndex: currentStopIndexNotifier.value,
      stopStatuses: _stopStatuses,
      isOnline: isTracking,
    );

    if (currentIndex != -1 && currentIndex < stops.length) {
      await toggleStopAtIndex(currentIndex);
    }
  }

  /// Manually toggles a stop reached / unreached state by stop index.
  Future<void> toggleStopAtIndex(int index) async {
    if (_activeRoute == null || index < 0 || index >= _activeRoute!.stops.length) return;
    final stops = _activeRoute!.stops;
    final stopName = stops[index];
    final isDone = completedStopsNotifier.value.contains(stopName);

    if (isDone) {
      _reachedStopIndices.remove(index);
      _stopStatuses.remove(index.toString());
      final currentCompleted = List<String>.from(completedStopsNotifier.value)..remove(stopName);
      completedStopsNotifier.value = currentCompleted;
      currentStopIndexNotifier.value = StopUtils.getNextStopIndex(
        stops: stops,
        completedStops: currentCompleted,
        fallbackCurrentIndex: index,
        stopStatuses: _stopStatuses,
        isOnline: isTracking,
      );
    } else {
      _reachedStopIndices.add(index);
      _stopStatuses[index.toString()] = {
        'status': 'reached',
        'reachedAt': DateTime.now().toIso8601String(),
        'stopName': stopName,
        'manual': true,
      };
      final currentCompleted = List<String>.from(completedStopsNotifier.value);
      if (!currentCompleted.contains(stopName)) {
        currentCompleted.add(stopName);
      }
      completedStopsNotifier.value = currentCompleted;

      if (index >= stops.length - 1) {
        await _handleDestinationArrival(stopName);
      } else {
        currentStopIndexNotifier.value = index + 1;
      }
    }

    // Sync to Firestore if trip is active
    if (_activeDriverId != null && _activeRoute != null) {
      final pos = lastPositionNotifier.value;
      final lat = pos?.latitude ?? (_activeRoute!.stopCoordinates.isNotEmpty ? _activeRoute!.stopCoordinates[0].latitude : 13.0827);
      final lng = pos?.longitude ?? (_activeRoute!.stopCoordinates.isNotEmpty ? _activeRoute!.stopCoordinates[0].longitude : 80.2707);
      await _firestoreService.updateBusLocation(
        driverId: _activeDriverId!,
        latitude: lat,
        longitude: lng,
        routeName: _activeRoute!.routeName,
        routeId: _activeRoute!.routeId,
        speed: pos != null ? (pos.speed * 3.6).clamp(0.0, 150.0) : 0.0,
        isOnline: true,
        isTracking: true,
        currentStopIndex: currentStopIndexNotifier.value,
        completedStops: List<String>.from(completedStopsNotifier.value),
        stopStatuses: Map<String, dynamic>.from(_stopStatuses),
        tripId: _currentTripId,
      ).catchError((e) {
        debugPrint('[TrackingService] Error syncing manual stop toggle: $e');
      });
    }
  }

  /// Ends the active trip, cancels the foreground service, and archives the trip record.
  Future<void> endTrip() async {
    await _stopActiveStreamOnly();

    if (_activeDriverId != null && _activeRoute != null) {
      final endTime = DateTime.now();
      final startTime = _tripStartTime ?? endTime.subtract(const Duration(minutes: 15));
      final completedCount = completedStopsNotifier.value.length;
      final totalStops = _activeRoute!.stops.length;

      // 1. Mark driver as offline in Firestore while keeping last known location & stats
      await _firestoreService.endDriverTrip(
        _activeDriverId!,
        latitude: lastPositionNotifier.value?.latitude,
        longitude: lastPositionNotifier.value?.longitude,
        currentStopIndex: currentStopIndexNotifier.value,
        completedStops: List<String>.from(completedStopsNotifier.value),
        stopStatuses: Map<String, dynamic>.from(_stopStatuses),
      );


      // 2. Persist to /trips collection
      try {
        await _firestoreService.recordCompletedTrip(
          routeId: _activeRoute!.routeId,
          routeName: _activeRoute!.routeName,
          driverId: _activeDriverId!,
          driverName: 'Driver',
          startTime: startTime,
          endTime: endTime,
          stopsCompleted: completedCount,
          totalStops: totalStops,
        );
      } catch (e) {
        debugPrint('[TrackingService] Error saving trip record: $e');
      }
    }

    _activeDriverId = null;
    _activeRoute = null;
    _tripStartTime = null;
    isTrackingNotifier.value = false;
    activeRouteNameNotifier.value = null;
  }

  /// Starts a periodic heartbeat to ensure Firestore has up-to-date timestamp
  /// even when the bus is stopped at a signal/depot or screen is locked.
  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(TrackingConstants.heartbeatInterval, (_) async {
      if (!isTracking || _activeDriverId == null || _activeRoute == null) {
        _heartbeatTimer?.cancel();
        return;
      }

      final now = DateTime.now();
      // If no GPS callback happened in the last 5 seconds (stationary or screen off)
      if (_lastGpsUpdateTime == null ||
          now.difference(_lastGpsUpdateTime!).inSeconds >= 5) {
        Position? pos = lastPositionNotifier.value;
        if (pos == null) {
          try {
            pos = await Geolocator.getLastKnownPosition();
          } catch (_) {}
        }

        if (pos != null && _activeDriverId != null && _activeRoute != null) {
          _firestoreService.updateBusLocation(
            driverId: _activeDriverId!,
            latitude: pos.latitude,
            longitude: pos.longitude,
            routeName: _activeRoute!.routeName,
            routeId: _activeRoute!.routeId,
            busId: _activeRoute!.routeId,
            speed: (pos.speed * 3.6).clamp(0.0, 150.0),
            heading: pos.heading,
            isOnline: true,
            isTracking: true,
            currentStopIndex: currentStopIndexNotifier.value,
            completedStops: List<String>.from(completedStopsNotifier.value),
          ).catchError((e) {
            debugPrint('[TrackingService] Heartbeat update error: $e');
          });
        }
      }
    });
  }

  /// Cancels the GPS subscription, heartbeat timer, and dismisses the foreground notification.
  Future<void> _stopActiveStreamOnly() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_positionSubscription != null) {
      await _positionSubscription!.cancel();
      _positionSubscription = null;
    }
  }

  /// Restores trip state if driver reopens app while trip is active in Firestore.
  Future<void> restoreIfActive({
    required String driverId,
    required RouteModel route,
  }) async {
    if (isTracking && _activeDriverId == driverId && _activeRoute?.routeId == route.routeId) {
      return; // Already actively streaming
    }

    try {
      final busLoc = await _firestoreService.getBusLocationOnce(driverId);
      if (busLoc != null && busLoc.isOnline && busLoc.routeId == route.routeId) {
        _activeDriverId = driverId;
        _activeRoute = route;
        _tripStartTime = busLoc.timestamp ?? DateTime.now();
        currentStopIndexNotifier.value = busLoc.currentStopIndex;
        completedStopsNotifier.value = List<String>.from(busLoc.completedStops);
        activeRouteNameNotifier.value = route.routeName;
        isTrackingNotifier.value = true;

        if (busLoc.latitude != 0 && busLoc.longitude != 0) {
          lastPositionNotifier.value = Position(
            latitude: busLoc.latitude,
            longitude: busLoc.longitude,
            timestamp: busLoc.timestamp ?? DateTime.now(),
            accuracy: 4.0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: busLoc.heading,
            headingAccuracy: 0,
            speed: busLoc.speed / 3.6,
            speedAccuracy: 0,
          );
        }

        // Restart foreground service stream to maintain background tracking
        await startTrip(driverId: driverId, route: route);
      }
    } catch (e) {
      debugPrint('[TrackingService] Error restoring trip state: $e');
    }
  }

  /// Computes compass bearing angle in degrees between two GPS coordinates.
  double _calculateBearing(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final phi1 = startLat * math.pi / 180;
    final phi2 = endLat * math.pi / 180;
    final deltaLambda = (endLng - startLng) * math.pi / 180;

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final theta = math.atan2(y, x);
    return (theta * 180 / math.pi + 360) % 360;
  }
}
