import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/route_model.dart';
import '../models/bus_model.dart';
import '../constants/tracking_constants.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/directions_service.dart';
import '../utils/stop_utils.dart';
import 'notification_history_screen.dart';

class StudentTrackingScreen extends StatefulWidget {
  final RouteModel routeModel;

  const StudentTrackingScreen({
    super.key,
    required this.routeModel,
  });

  @override
  State<StudentTrackingScreen> createState() => _StudentTrackingScreenState();
}

class _StudentTrackingScreenState extends State<StudentTrackingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  GoogleMapController? _mapController;

  // Dedicated ValueNotifiers for granular Map & UI updates without full-screen rebuilds
  final ValueNotifier<Set<Marker>> _markersNotifier = ValueNotifier<Set<Marker>>({});
  final ValueNotifier<Set<Polyline>> _polylinesNotifier = ValueNotifier<Set<Polyline>>({});
  final ValueNotifier<BusLocation?> _busLocationNotifier = ValueNotifier<BusLocation?>(null);
  final ValueNotifier<String> _statusNotifier = ValueNotifier<String>('WAITING');
  final ValueNotifier<int> _nextStopIndexNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<bool> _followBusNotifier = ValueNotifier<bool>(true);

  // Cached static elements
  Set<Marker> _staticStopMarkers = {};
  Marker? _currentBusMarker;
  LatLng _lastBusPosition = const LatLng(13.0694, 80.1948);
  List<LatLng> _roadPolylinePoints = [];

  StreamSubscription? _routeBusSubscription;
  StreamSubscription? _notificationSubscription;
  Timer? _freshnessTimer;
  Timer? _periodicEtaTimer;

  // Student Selected Stop & Live Road ETA
  int _selectedStopIndex = 0;
  String? _currentUserId;
  EtaResult? _liveEtaResult;
  bool _hasNotifiedProximity500m = false;
  bool _hasNotifiedArrival = false;
  bool _highContrastMap = false;
  bool _lowDataMode = false;
  String? _lastTripId;
  final List<GpsReading> _recentGpsReadings = [];

  final Set<String> _seenNotificationIds = {};

  // Custom bus vehicle marker bitmaps (cached globally for instant startup with consistent uniform size)
  static BitmapDescriptor? _cachedLiveBusIcon;
  static BitmapDescriptor? _cachedStaleBusIcon;
  static BitmapDescriptor? _cachedOfflineBusIcon;

  BitmapDescriptor? _liveBusIcon;
  BitmapDescriptor? _staleBusIcon;
  BitmapDescriptor? _offlineBusIcon;

  static const String _highContrastMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#f8f9fa"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#1a202c"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#ffffff"}, {"weight": 3}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
    {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#ffecb3"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#ffd54f"}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#ffb300"}, {"weight": 1.5}]},
    {"featureType": "transit.line", "elementType": "geometry", "stylers": [{"color": "#0d47a1"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#90caf9"}]}
  ]
  ''';

  void _applyMapStyle() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _roadPolylinePoints = widget.routeModel.polylinePoints.isNotEmpty
        ? widget.routeModel.polylinePoints
        : widget.routeModel.stopCoordinates;
    _loadCustomBusIcons();
    _loadInitialUserState();
    _rebuildStaticStopMarkers();
    _recalculateEta();
    _subscribeToLocation();
    _subscribeToNotifications();
    _startFreshnessTimer();
    _startPeriodicEtaTimer();
  }

  Future<void> _loadInitialUserState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      await NotificationService.subscribeToRoute(widget.routeModel.routeId);
      final profile = await _firestoreService.getUserProfile(user.uid);
      if (profile != null && mounted) {
        setState(() {
          _highContrastMap = profile.highContrastMap;
          _lowDataMode = profile.lowDataMode;
          if (profile.selectedStopIndex != null &&
              profile.selectedStopIndex! >= 0 &&
              profile.selectedStopIndex! < widget.routeModel.stops.length) {
            _selectedStopIndex = profile.selectedStopIndex!;
          }
        });
        _applyMapStyle();
        _rebuildStaticStopMarkers();
        _recalculateEta();
      }
    }
  }

  Future<void> _onSelectStop(int index) async {
    if (index < 0 || index >= widget.routeModel.stops.length) return;
    setState(() {
      _selectedStopIndex = index;
      _hasNotifiedProximity500m = false;
      _hasNotifiedArrival = false;
    });

    _rebuildStaticStopMarkers();

    if (_currentUserId != null) {
      await _firestoreService.saveUserSelectedStop(
        uid: _currentUserId!,
        routeId: widget.routeModel.routeId,
        stopIndex: index,
        stopName: widget.routeModel.stops[index],
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📍 Target Stop set to: ${widget.routeModel.stops[index]}',
          ),
          backgroundColor: const Color(0xFF0D47A1),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await _recalculateEta();
  }

  Future<void> _loadCustomBusIcons() async {
    if (_cachedLiveBusIcon != null &&
        _cachedStaleBusIcon != null &&
        _cachedOfflineBusIcon != null) {
      _liveBusIcon = _cachedLiveBusIcon;
      _staleBusIcon = _cachedStaleBusIcon;
      _offlineBusIcon = _cachedOfflineBusIcon;
      _updateBusMarkerOnly();
      return;
    }
    try {
      final live = await _generateBusPinMarkerBitmap(
        pinColor: const Color(0xFF0D47A1),
        busIconColor: const Color(0xFF0D47A1),
        width: 15.0,
        height: 19.0,
        scale: 4.5,
      );
      final stale = await _generateBusPinMarkerBitmap(
        pinColor: const Color(0xFFD97706),
        busIconColor: const Color(0xFFD97706),
        width: 15.0,
        height: 19.0,
        scale: 4.5,
      );
      final offline = await _generateBusPinMarkerBitmap(
        pinColor: const Color(0xFF475569),
        busIconColor: const Color(0xFF475569),
        width: 15.0,
        height: 19.0,
        scale: 4.5,
      );

      _cachedLiveBusIcon = live;
      _cachedStaleBusIcon = stale;
      _cachedOfflineBusIcon = offline;

      _liveBusIcon = live;
      _staleBusIcon = stale;
      _offlineBusIcon = offline;

      _updateBusMarkerOnly();
    } catch (e) {
      debugPrint('[StudentTrackingScreen] Error generating bus pin icon: $e');
    }
  }

  /// Compact, high-definition vector pin marker matching the exact bus location design
  /// Set to a clean, smaller, consistent size across the map
  Future<BitmapDescriptor> _generateBusPinMarkerBitmap({
    required Color pinColor,
    required Color busIconColor,
    double width = 15.0,
    double height = 19.0,
    double scale = 4.5,
  }) async {
    final int pixelWidth = (width * scale).round();
    final int pixelHeight = (height * scale).round();

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    canvas.scale(scale, scale);

    final double s = width / 30.0;
    final double cx = width / 2.0;
    final double headRadius = 11.5 * s;
    final double cy = 12.5 * s;
    final double tipX = cx;
    final double tipY = height - (2.2 * s);

    // 1. Soft elevation drop shadow beneath the pin tip
    final Path shadowPath = Path();
    shadowPath.moveTo(tipX, tipY + (1.0 * s));
    shadowPath.cubicTo(
      cx - headRadius * 0.85, cy + headRadius * 1.05,
      cx - headRadius, cy + headRadius * 0.45,
      cx - headRadius, cy,
    );
    shadowPath.arcToPoint(
      Offset(cx + headRadius, cy),
      radius: Radius.circular(headRadius),
      clockwise: true,
    );
    shadowPath.cubicTo(
      cx + headRadius, cy + headRadius * 0.45,
      cx + headRadius * 0.85, cy + headRadius * 1.05,
      tipX, tipY + (1.0 * s),
    );
    shadowPath.close();

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, (1.8 * s).clamp(0.8, 3.0));
    canvas.drawPath(shadowPath, shadowPaint);

    // 2. Outer Teardrop Pin Body
    final Path pinPath = Path();
    pinPath.moveTo(tipX, tipY);
    pinPath.cubicTo(
      cx - headRadius * 0.85, cy + headRadius * 1.05,
      cx - headRadius, cy + headRadius * 0.45,
      cx - headRadius, cy,
    );
    pinPath.arcToPoint(
      Offset(cx + headRadius, cy),
      radius: Radius.circular(headRadius),
      clockwise: true,
    );
    pinPath.cubicTo(
      cx + headRadius, cy + headRadius * 0.45,
      cx + headRadius * 0.85, cy + headRadius * 1.05,
      tipX, tipY,
    );
    pinPath.close();

    final Paint pinPaint = Paint()
      ..color = pinColor
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // 3. Crisp White Outline
    final Paint outlinePaint = Paint()
      ..color = Colors.white
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.4 * s).clamp(0.8, 2.5);
    canvas.drawPath(pinPath, outlinePaint);

    // 4. Inner White Circle
    final double innerRadius = 8.5 * s;
    final Paint innerWhitePaint = Paint()
      ..color = Colors.white
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), innerRadius, innerWhitePaint);

    // 5. Draw the exact bus silhouette from the reference design
    final double bLeft = cx - (4.8 * s);
    final double bTop = cy - (5.4 * s);
    final double bWidth = 9.6 * s;
    final double bHeight = 9.4 * s;

    final Paint busSilhouettePaint = Paint()
      ..color = pinColor
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final Paint whiteCutoutPaint = Paint()
      ..color = Colors.white
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // 5a. Side Mirrors
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bLeft - (1.1 * s), bTop + (2.5 * s), 0.95 * s, 2.4 * s),
        Radius.circular(0.4 * s),
      ),
      busSilhouettePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bLeft + bWidth + (0.15 * s), bTop + (2.5 * s), 0.95 * s, 2.4 * s),
        Radius.circular(0.4 * s),
      ),
      busSilhouettePaint,
    );

    // 5b. Wheels / Tires
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bLeft + (0.8 * s), bTop + (9.0 * s), 2.0 * s, 1.6 * s),
        Radius.circular(0.5 * s),
      ),
      busSilhouettePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bLeft + bWidth - (2.8 * s), bTop + (9.0 * s), 2.0 * s, 1.6 * s),
        Radius.circular(0.5 * s),
      ),
      busSilhouettePaint,
    );

    // 5c. Main Bus Body
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(bLeft, bTop, bWidth, bHeight),
        topLeft: Radius.circular(2.4 * s),
        topRight: Radius.circular(2.4 * s),
        bottomLeft: Radius.circular(1.0 * s),
        bottomRight: Radius.circular(1.0 * s),
      ),
      busSilhouettePaint,
    );

    // 5d. Top Destination Slot (White Cutout)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bLeft + (2.3 * s), bTop + (0.8 * s), bWidth - (4.6 * s), 0.8 * s),
        Radius.circular(0.4 * s),
      ),
      whiteCutoutPaint,
    );

    // 5e. Large Windshield (White Cutout)
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(bLeft + (1.1 * s), bTop + (2.0 * s), bWidth - (2.2 * s), 3.8 * s),
        topLeft: Radius.circular(1.2 * s),
        topRight: Radius.circular(1.2 * s),
        bottomLeft: Radius.circular(0.5 * s),
        bottomRight: Radius.circular(0.5 * s),
      ),
      whiteCutoutPaint,
    );

    // 5f. Two Round Circular Headlights (White Cutouts)
    canvas.drawCircle(
      Offset(bLeft + (2.4 * s), bTop + (7.2 * s)),
      1.0 * s,
      whiteCutoutPaint,
    );
    canvas.drawCircle(
      Offset(bLeft + bWidth - (2.4 * s), bTop + (7.2 * s)),
      1.0 * s,
      whiteCutoutPaint,
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(pixelWidth, pixelHeight);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  void _startFreshnessTimer() {
    _freshnessTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final newStatus = _computeStatus(_busLocationNotifier.value);
      if (_statusNotifier.value != newStatus) {
        _statusNotifier.value = newStatus;
        _updateBusMarkerOnly();
      }
    });
  }

  void _startPeriodicEtaTimer() {
    _periodicEtaTimer?.cancel();
    final interval = _lowDataMode
        ? const Duration(seconds: 45)
        : const Duration(seconds: 20);
    _periodicEtaTimer = Timer.periodic(interval, (_) {
      _recalculateEta();
    });
  }

  void _subscribeToNotifications() {
    _notificationSubscription?.cancel();
    bool isInitialSnapshot = true;
    _notificationSubscription =
        _firestoreService.getNotificationsForRoute(widget.routeModel.routeId).listen((notifications) {
      if (!mounted) return;

      if (isInitialSnapshot) {
        // Mark all existing historical notifications as already seen so they are NOT re-displayed as alerts on open
        for (final item in notifications) {
          final id = item['id'] as String?;
          if (id != null) {
            _seenNotificationIds.add(id);
          }
        }
        isInitialSnapshot = false;
        return;
      }

      for (final item in notifications) {
        final id = item['id'] as String?;
        final message = item['message'] as String?;
        final type = (item['type'] as String? ?? '').toLowerCase();
        final routeId = item['routeId'] as String?;

        // Strict route check: only process notifications for this active route
        if (routeId != null && routeId.isNotEmpty && routeId != widget.routeModel.routeId) {
          continue;
        }

        if (id != null && message != null && !_seenNotificationIds.contains(id)) {
          _seenNotificationIds.add(id);
          String title = '📢 Route Alert';
          if (type == 'breakdown') {
            title = '🚨 Bus Breakdown Alert!';
          } else if (type == 'delay') {
            title = '⚠️ Bus Delay Alert!';
          } else if (type == 'approaching') {
            title = '🚌 Bus Approaching Your Stop (~5 Mins)';
          } else if (type == 'arrival') {
            title = '✅ Bus Arrived at Stop';
          } else if (type == 'completed') {
            title = '🏁 Route Trip Completed';
          }

          NotificationService.show(
            id: id.hashCode,
            title: title,
            body: message,
          );
        }
      }
    });
  }

  void _subscribeToLocation() {
    _routeBusSubscription?.cancel();

    _routeBusSubscription = FirebaseFirestore.instance
        .collection('bus_location')
        .where('routeId', isEqualTo: widget.routeModel.routeId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      if (snap.docs.isNotEmpty) {
        final docs = snap.docs;
        final onlineDoc = docs
            .where((d) => (d.data()['isOnline'] as bool? ?? false))
            .firstOrNull;
        final selectedDoc = onlineDoc ?? docs.first;
        final bus = BusLocation.fromFirestore(selectedDoc);
        _handleBusUpdate(bus);
      } else {
        _busLocationNotifier.value = null;
        _statusNotifier.value = 'OFFLINE';
        _nextStopIndexNotifier.value = -1;
        _currentBusMarker = null;
        _markersNotifier.value = Set<Marker>.from(_staticStopMarkers);
      }
    });
  }

  void _handleBusUpdate(BusLocation bus) {
    if (bus.latitude == 0 && bus.longitude == 0) return;

    final newPos = LatLng(bus.latitude, bus.longitude);
    _lastBusPosition = newPos;
    _busLocationNotifier.value = bus;

    final newStatus = _computeStatus(bus);
    _statusNotifier.value = newStatus;

    // Compute Next Stop sequentially using shared helper
    final computedNextStop = StopUtils.getNextStopIndex(
      stops: widget.routeModel.stops,
      completedStops: bus.completedStops,
      fallbackCurrentIndex: bus.currentStopIndex,
      stopStatuses: bus.stopStatuses,
      isOnline: bus.isOnline,
    );

    final bool nextStopChanged = _nextStopIndexNotifier.value != computedNextStop;
    _nextStopIndexNotifier.value = computedNextStop;

    if (nextStopChanged) {
      _rebuildStaticStopMarkers();
    } else {
      _updateBusMarkerOnly();
    }

    // Collect valid GPS reading for rolling speed average (last 60-90s)
    final now = DateTime.now();
    _recentGpsReadings.removeWhere((r) => now.difference(r.timestamp).inSeconds > 90);
    if (bus.speed >= 2.0) {
      _recentGpsReadings.add(GpsReading(
        timestamp: bus.timestamp ?? now,
        speedKmH: bus.speed,
        position: newPos,
        accuracy: 10.0,
      ));
    }

    // Auto-center camera if follow mode is active
    if (_followBusNotifier.value && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(newPos),
      );
    }

    _checkProximityAndNotify(newPos);
    _recalculateEta();
  }

  void _updateBusMarkerOnly() {
    final bus = _busLocationNotifier.value;
    if (bus == null) {
      _currentBusMarker = null;
      _markersNotifier.value = Set<Marker>.from(_staticStopMarkers);
      return;
    }

    final status = _statusNotifier.value;
    final customIcon = status == 'LIVE'
        ? (_liveBusIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure))
        : status == 'STALE'
            ? (_staleBusIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange))
            : (_offlineBusIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet));

    _currentBusMarker = Marker(
      markerId: const MarkerId('bus_vehicle'),
      position: _lastBusPosition,
      rotation: 0.0, // Always keep vertical pin upright
      flat: false,
      anchor: const Offset(0.5, 0.95),
      icon: customIcon,
      infoWindow: InfoWindow(
        title: '🚌 ${widget.routeModel.routeName}',
        snippet: status == 'LIVE'
            ? '${bus.speed.toStringAsFixed(1)} km/h • LIVE GPS'
            : status == 'STALE'
                ? '⚠️ GPS Signal Stale'
                : 'Bus Offline',
      ),
      zIndexInt: 10,
    );

    final combined = <Marker>{};
    if (_currentBusMarker != null) {
      combined.add(_currentBusMarker!);
    }
    _markersNotifier.value = combined;
  }

  void _rebuildStaticStopMarkers() {
    // Only moving bus marker is displayed on the map per requirements
    _staticStopMarkers = {};
    final combined = <Marker>{};
    if (_currentBusMarker != null) {
      combined.add(_currentBusMarker!);
    }
    _markersNotifier.value = combined;
  }


  void _checkProximityAndNotify(LatLng busPos) {
    if (widget.routeModel.stopCoordinates.isEmpty ||
        _selectedStopIndex >= widget.routeModel.stopCoordinates.length) {
      return;
    }

    final currentTripId = _busLocationNotifier.value?.busId ?? _busLocationNotifier.value?.driverId;
    if (_lastTripId != null && currentTripId != null && _lastTripId != currentTripId) {
      _hasNotifiedProximity500m = false;
      _hasNotifiedArrival = false;
    }
    _lastTripId = currentTripId;

    final targetCoord = widget.routeModel.stopCoordinates[_selectedStopIndex];
    final targetName = widget.routeModel.stops[_selectedStopIndex];

    final distanceMeters = DirectionsService.calculateHaversineDistanceMeters(
      busPos.latitude,
      busPos.longitude,
      targetCoord.latitude,
      targetCoord.longitude,
    );

    final completedStops = _busLocationNotifier.value?.completedStops ?? [];
    final isDone = completedStops.contains(targetName);

    // 1. Proximity alert (~500m)
    if (distanceMeters <= 500.0 && !isDone && !_hasNotifiedProximity500m) {
      _hasNotifiedProximity500m = true;
      final etaMin = _liveEtaResult?.minutes ?? ((distanceMeters / 1000.0) / 25.0 * 60).ceil();
      NotificationService.busApproachingStop(targetName, etaMin);
    }

    // 2. Arrival alert (<= 50m or marked completed in Firestore)
    if ((distanceMeters <= 50.0 || isDone) && !_hasNotifiedArrival) {
      _hasNotifiedArrival = true;
      NotificationService.busArrivedAtStop(targetName);
    }
  }

  Future<void> _recalculateEta() async {
    if (widget.routeModel.stopCoordinates.isEmpty ||
        _selectedStopIndex >= widget.routeModel.stopCoordinates.length) {
      return;
    }
    final stopCoord = widget.routeModel.stopCoordinates[_selectedStopIndex];
    final stopName = widget.routeModel.stops[_selectedStopIndex];
    final bus = _busLocationNotifier.value;

    final completedStops = bus?.completedStops ?? [];
    final isAlreadyCompleted = completedStops.contains(stopName);
    final nextIdx = _nextStopIndexNotifier.value;
    final int intermediateStops = (nextIdx >= 0 && _selectedStopIndex > nextIdx)
        ? _selectedStopIndex - nextIdx
        : 0;

    final polyline = _roadPolylinePoints.isNotEmpty
        ? _roadPolylinePoints
        : (widget.routeModel.polylinePoints.isNotEmpty
            ? widget.routeModel.polylinePoints
            : widget.routeModel.stopCoordinates);

    final result = await DirectionsService.instance.calculateLiveEta(
      busPosition: _lastBusPosition,
      targetStopCoord: stopCoord,
      stopName: stopName,
      roadPolyline: polyline,
      isTripActive: (bus != null && bus.isOnline && bus.isTracking),
      isBusOnline: bus?.isOnline ?? false,
      lastTelemetryTimestamp: bus?.timestamp,
      isStopCompleted: isAlreadyCompleted,
      currentStopIndex: bus?.currentStopIndex,
      targetStopIndex: _selectedStopIndex,
      intermediateStopsCount: intermediateStops,
      recentGpsReadings: _recentGpsReadings,
      previousEtaMinutes: _liveEtaResult?.minutes,
    );

    if (mounted) {
      setState(() {
        _liveEtaResult = result;
      });
    }
  }

  void _fitMapToRoute() {
    if (_mapController == null) return;
    final List<LatLng> allPoints = [];
    allPoints.addAll(widget.routeModel.stopCoordinates);
    if (_busLocationNotifier.value != null) {
      allPoints.add(_lastBusPosition);
    }
    if (allPoints.isEmpty) return;

    if (allPoints.length == 1) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(allPoints.first, 14.0));
      return;
    }

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.005, minLng - 0.005),
          northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
        ),
        50.0,
      ),
    );
  }

  @override
  void dispose() {
    _routeBusSubscription?.cancel();
    _notificationSubscription?.cancel();
    _freshnessTimer?.cancel();
    _periodicEtaTimer?.cancel();
    _markersNotifier.dispose();
    _polylinesNotifier.dispose();
    _busLocationNotifier.dispose();
    _statusNotifier.dispose();
    _nextStopIndexNotifier.dispose();
    _followBusNotifier.dispose();
    super.dispose();
  }

  // ─── Status & Delay Computation ────────────────────────────────────────────

  String _computeStatus(BusLocation? bus) {
    if (bus == null) return 'WAITING';
    if (!bus.isOnline) return 'OFFLINE';

    if (bus.timestamp == null) return 'STALE';
    final ageSeconds = DateTime.now().difference(bus.timestamp!).inSeconds;

    if (ageSeconds <= TrackingConstants.staleTimeoutSeconds) {
      return 'LIVE';
    } else if (ageSeconds <= TrackingConstants.offlineTimeoutSeconds) {
      return 'STALE';
    } else {
      return 'OFFLINE';
    }
  }

  String _calculateDelayIndicator() {
    if (widget.routeModel.scheduledTimes.isEmpty ||
        _selectedStopIndex >= widget.routeModel.scheduledTimes.length) {
      return '';
    }
    final scheduledStr = widget.routeModel.scheduledTimes[_selectedStopIndex].trim();
    if (scheduledStr.isEmpty) return '';

    // Only compute delay when the bus is actively broadcasting a live trip
    final busLoc = _busLocationNotifier.value;
    if (busLoc == null || !busLoc.isOnline || !busLoc.isTracking) {
      return '';
    }

    try {
      DateTime schedTime;
      if (scheduledStr.contains('AM') ||
          scheduledStr.contains('PM') ||
          scheduledStr.contains('am') ||
          scheduledStr.contains('pm')) {
        schedTime = DateFormat('h:mm a').parse(scheduledStr);
      } else {
        schedTime = DateFormat('HH:mm').parse(scheduledStr);
      }

      final now = DateTime.now();
      final schedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        schedTime.hour,
        schedTime.minute,
      );

      final etaMin = _liveEtaResult?.minutes ?? 0;
      final expectedArrival = now.add(Duration(minutes: etaMin));
      final delayMinutes = expectedArrival.difference(schedDateTime).inMinutes;

      if (delayMinutes >= 2) {
        return '⚠️ Delayed by $delayMinutes min';
      } else if (delayMinutes <= -2) {
        return '🟢 On time (${(-delayMinutes)}m early)';
      } else {
        return '🟢 On time';
      }
    } catch (_) {
      return '';
    }
  }



  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  void _showStopPickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Your Boarding Stop',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'We will provide road-accurate ETA and proximity alerts for your chosen stop.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.routeModel.stops.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final isSelected = i == _selectedStopIndex;
                    final stopName = widget.routeModel.stops[i];
                    final coord = (widget.routeModel.stopCoordinates.length > i)
                        ? widget.routeModel.stopCoordinates[i]
                        : null;
                    final sched = (widget.routeModel.scheduledTimes.length > i)
                        ? widget.routeModel.scheduledTimes[i]
                        : '';

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: isSelected
                            ? const Color(0xFF0D47A1)
                            : Colors.grey.shade200,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      title: Text(
                        stopName,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF0D47A1)
                              : Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (coord != null)
                            Text(
                              '📍 ${coord.latitude.toStringAsFixed(4)}, ${coord.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          if (sched.isNotEmpty)
                            Text(
                              '🕐 Scheduled: $sched',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF0D47A1)),
                            ),
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF0D47A1))
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _onSelectStop(i);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFeedbackDialog() {
    String category = 'Bus Delay';
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.rate_review, color: Color(0xFF0D47A1)),
              SizedBox(width: 8),
              Text('Report Issue / Feedback'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Issue Category',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Bus Delay', child: Text('Bus Delay / Late')),
                    DropdownMenuItem(
                        value: 'Overcrowding',
                        child: Text('Bus Overcrowded / No Seats')),
                    DropdownMenuItem(
                        value: 'Lost Item', child: Text('Lost Item on Bus')),
                    DropdownMenuItem(
                        value: 'Driver Feedback',
                        child: Text('Driver Behavior / Driving')),
                    DropdownMenuItem(
                        value: 'Route Suggestion',
                        child: Text('Route / Schedule Suggestion')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Details & Comments',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue or feedback...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (textCtrl.text.trim().isEmpty) return;
                await _firestoreService.submitStudentFeedback(
                  uid: _currentUserId ?? 'student_${DateTime.now().millisecondsSinceEpoch}',
                  studentName: 'Student',
                  routeId: widget.routeModel.routeId,
                  category: category,
                  details: textCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Feedback submitted to Transit Operations!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = widget.routeModel.stopCoordinates.isNotEmpty
        ? widget.routeModel.stopCoordinates.first
        : const LatLng(13.0694, 80.1948);

    final targetStopName = (widget.routeModel.stops.length > _selectedStopIndex)
        ? widget.routeModel.stops[_selectedStopIndex]
        : 'Stop';

    final delayText = _calculateDelayIndicator();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Tracking',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Route Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationHistoryScreen(
                    routeId: widget.routeModel.routeId,
                    routeName: widget.routeModel.routeName,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.rate_review_outlined),
            tooltip: 'Report Issue',
            onPressed: _openFeedbackDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status Banner (Listens to status notifier) ─────────────────────
          ValueListenableBuilder<String>(
            valueListenable: _statusNotifier,
            builder: (context, status, _) {
              Color bannerBg;
              IconData statusIcon;
              String statusTitle;

              if (status == 'LIVE') {
                bannerBg = const Color(0xFF1B5E20);
                statusIcon = Icons.sensors;
                statusTitle = 'Live Route • ${widget.routeModel.routeName}';
              } else if (status == 'STALE') {
                bannerBg = const Color(0xFFD97706);
                statusIcon = Icons.warning_amber_rounded;
                statusTitle = 'GPS Signal Weak • ${widget.routeModel.routeName}';
              } else if (status == 'OFFLINE') {
                bannerBg = const Color(0xFF475569);
                statusIcon = Icons.cloud_off;
                statusTitle = 'Bus Offline • ${widget.routeModel.routeName}';
              } else {
                bannerBg = const Color(0xFF0D47A1);
                statusIcon = Icons.hourglass_top;
                statusTitle = 'Connecting to bus telemetry…';
              }

              return Container(
                color: bannerBg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    if (status == 'LIVE')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'LIVE GPS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ValueListenableBuilder<BusLocation?>(
                        valueListenable: _busLocationNotifier,
                        builder: (_, bus, __) {
                          if (bus?.timestamp == null) return const SizedBox.shrink();
                          return Text(
                            _formatTimestamp(bus!.timestamp),
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),

          // ── Student Boarding Stop Selector Bar ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF093374),
            child: Row(
              children: [
                const Icon(Icons.star, size: 16, color: Color(0xFFFFD54F)),
                const SizedBox(width: 6),
                const Text(
                  'My Stop: ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _showStopPickerModal,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: Text(
                        '${_selectedStopIndex + 1}. ${widget.routeModel.stops[_selectedStopIndex]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showStopPickerModal,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white54, width: 1.0),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Change',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Google Map with Isolated Marker & Polyline Notifiers ────────────
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                ValueListenableBuilder<Set<Polyline>>(
                  valueListenable: _polylinesNotifier,
                  builder: (context, polylines, _) {
                    return ValueListenableBuilder<Set<Marker>>(
                      valueListenable: _markersNotifier,
                      builder: (context, markers, _) {
                        return GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: initialTarget,
                            zoom: 13.0,
                          ),
                          style: _highContrastMap ? _highContrastMapStyle : null,
                          onMapCreated: (c) {
                            _mapController = c;
                            _fitMapToRoute();
                          },
                          markers: markers,
                          polylines: polylines,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: true,
                          onCameraMoveStarted: () {
                            // User is manually panning map -> stop auto-centering
                            _followBusNotifier.value = false;
                          },
                        );
                      },
                    );
                  },
                ),

                // Map Control Actions (Top Right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _followBusNotifier,
                    builder: (context, followBus, _) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _followBusNotifier.value = true;
                            if (_mapController != null) {
                              _mapController!.animateCamera(
                                CameraUpdate.newLatLngZoom(_lastBusPosition, 14.5),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: followBus
                                  ? const Color(0xFF0D47A1)
                                  : Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.my_location,
                                  size: 14,
                                  color: followBus
                                      ? Colors.white
                                      : const Color(0xFF0D47A1),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  followBus ? 'Centering Bus' : 'Center Bus',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: followBus
                                        ? Colors.white
                                        : const Color(0xFF0D47A1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),


          // ── Next Stop Highlight & Info Cards ────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Next Stop Prominent Indicator Banner
                  ValueListenableBuilder<BusLocation?>(
                    valueListenable: _busLocationNotifier,
                    builder: (context, busLoc, _) {
                      final isOnline = busLoc != null && busLoc.isOnline && busLoc.isTracking;
                      final nextIdx = _nextStopIndexNotifier.value;
                      final hasNextStop = isOnline && nextIdx >= 0 && nextIdx < widget.routeModel.stops.length;
                      final nextStopName = hasNextStop ? widget.routeModel.stops[nextIdx] : '';
                      final isTripComplete = isOnline && StopUtils.isTripCompleted(
                        stops: widget.routeModel.stops,
                        completedStops: busLoc.completedStops,
                        stopStatuses: busLoc.stopStatuses,
                        isOnline: isOnline,
                      );

                      String bannerTitle;
                      String bannerText;
                      IconData bannerIcon;
                      Color bannerIconBg;
                      List<Color> gradientColors;
                      Color borderColor;
                      Color titleColor;

                      if (!isOnline) {
                        bannerTitle = 'STATUS: ';
                        bannerText = 'Trip not started';
                        bannerIcon = Icons.pause_circle_outline;
                        bannerIconBg = const Color(0xFF64748B);
                        gradientColors = [const Color(0xFFF1F5F9), const Color(0xFFF8FAFC)];
                        borderColor = const Color(0xFFCBD5E1);
                        titleColor = const Color(0xFF475569);
                      } else if (hasNextStop) {
                        bannerTitle = 'NEXT STOP: ';
                        bannerText = '${nextIdx + 1}. $nextStopName';
                        bannerIcon = Icons.alt_route;
                        bannerIconBg = const Color(0xFF0284C7);
                        gradientColors = [const Color(0xFFE0F2FE), const Color(0xFFF0FDF4)];
                        borderColor = const Color(0xFF38BDF8);
                        titleColor = const Color(0xFF0369A1);
                      } else if (isTripComplete) {
                        bannerTitle = 'STATUS: ';
                        bannerText = '🏁 Trip Completed (Destination Arrived)';
                        bannerIcon = Icons.flag;
                        bannerIconBg = const Color(0xFF059669);
                        gradientColors = [const Color(0xFFDCFCE7), const Color(0xFFF0FDF4)];
                        borderColor = const Color(0xFF4ADE80);
                        titleColor = const Color(0xFF15803D);
                      } else {
                        bannerTitle = 'STATUS: ';
                        bannerText = 'Waiting for bus location';
                        bannerIcon = Icons.access_time;
                        bannerIconBg = const Color(0xFFD97706);
                        gradientColors = [const Color(0xFFFEF3C7), const Color(0xFFFFFBEB)];
                        borderColor = const Color(0xFFFCD34D);
                        titleColor = const Color(0xFFB45309);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradientColors),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: bannerIconBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(bannerIcon, size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: bannerTitle,
                                      style: TextStyle(
                                        color: titleColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(
                                      text: bannerText,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (hasNextStop)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Next',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  // ETA / Speed / Progress Chips
                  ValueListenableBuilder<BusLocation?>(
                    valueListenable: _busLocationNotifier,
                    builder: (context, busLoc, _) {
                      final completedStops = busLoc?.completedStops ?? [];
                      final etaText = _liveEtaResult?.displayText ?? 'Trip not started';

                      return Row(
                        children: [
                          _InfoChip(
                            flex: 5,
                            icon: Icons.timer_outlined,
                            label: 'ETA to My Stop',
                            value: etaText,
                            color: const Color(0xFF0D47A1),
                          ),
                          const SizedBox(width: 6),
                          _InfoChip(
                            flex: 3,
                            icon: Icons.speed,
                            label: 'Speed',
                            value: '${busLoc?.speed.toStringAsFixed(0) ?? '0'} km/h',
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 6),
                          _InfoChip(
                            flex: 3,
                            icon: Icons.check_circle_outline,
                            label: 'Progress',
                            value: '${completedStops.length}/${widget.routeModel.stops.length}',
                            color: Colors.orange.shade800,
                          ),
                        ],
                      );
                    },
                  ),

                  if (delayText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: delayText.contains('Delayed')
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: delayText.contains('Delayed')
                              ? Colors.red.shade300
                              : Colors.green.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            delayText.contains('Delayed')
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle,
                            size: 14,
                            color: delayText.contains('Delayed')
                                ? Colors.red.shade800
                                : Colors.green.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$delayText for stop: $targetStopName',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: delayText.contains('Delayed')
                                  ? Colors.red.shade900
                                  : Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Route Stops (Tap to change target)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        'Auto-ticked via GPS',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Horizontal Route Stops List
                  SizedBox(
                    height: 36,
                    child: ValueListenableBuilder<BusLocation?>(
                      valueListenable: _busLocationNotifier,
                      builder: (context, busLoc, _) {
                        final completedStops = busLoc?.completedStops ?? [];
                        final nextStopIdx = _nextStopIndexNotifier.value;

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.routeModel.stops.length,
                          itemBuilder: (ctx, i) {
                            final stopName = widget.routeModel.stops[i];
                            final isDone = completedStops.contains(stopName);
                            final isNext = (i == nextStopIdx) && !isDone;
                            final isMyStop = i == _selectedStopIndex;
                            final schedTime =
                                (widget.routeModel.scheduledTimes.length > i)
                                    ? widget.routeModel.scheduledTimes[i]
                                    : '';

                            return GestureDetector(
                              onTap: () => _onSelectStop(i),
                              child: _StopChip(
                                label: stopName,
                                index: i + 1,
                                isCompleted: isDone,
                                isCurrent: isNext,
                                isMyStop: isMyStop,
                                scheduledTime: schedTime,
                                isLast: i == widget.routeModel.stops.length - 1,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 14, color: Color(0xFF0D47A1)),
                      const SizedBox(width: 5),
                      Text(
                        'Trip starts by ${_formatTripStartTime(widget.routeModel.morningSchedule)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTripStartTime(String timeStr) {
    if (timeStr.isEmpty) return '6:45 AM';
    final clean = timeStr.trim().toUpperCase().replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = clean.contains(':') ? clean.split(':') : clean.split('.');
    if (parts.isEmpty) return timeStr;
    final hour = int.tryParse(parts[0].trim()) ?? 6;
    final min = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    final minStr = min.toString().padLeft(2, '0');
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:$minStr $period';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int flex;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final double valueFontSize = value.length > 22
        ? 10.0
        : (value.length > 15 ? 11.0 : (value.length > 10 ? 12.0 : 13.5));

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.0,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.15,
              ),
              maxLines: 2,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _StopChip extends StatelessWidget {
  final String label;
  final int index;
  final bool isCompleted;
  final bool isCurrent;
  final bool isMyStop;
  final String scheduledTime;
  final bool isLast;

  const _StopChip({
    required this.label,
    required this.index,
    required this.isCompleted,
    required this.isCurrent,
    required this.isMyStop,
    required this.scheduledTime,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;

    if (isMyStop) {
      bg = const Color(0xFFFFF8E1);
      border = Colors.amber.shade700;
      text = Colors.amber.shade900;
    } else if (isCompleted) {
      bg = Colors.green.shade50;
      border = Colors.green.shade400;
      text = Colors.green.shade800;
    } else if (isCurrent) {
      bg = const Color(0xFFE0F2FE);
      border = const Color(0xFF0284C7);
      text = const Color(0xFF0369A1);
    } else {
      bg = Colors.grey.shade100;
      border = Colors.grey.shade300;
      text = Colors.grey.shade700;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: border,
              width: (isCurrent || isMyStop) ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMyStop)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.star, size: 14, color: Colors.amber),
                )
              else if (isCompleted)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle, size: 14, color: Colors.green),
                )
              else if (isCurrent)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.alt_route, size: 14, color: Color(0xFF0284C7)),
                ),
              Text(
                '$index. $label',
                style: TextStyle(
                  fontSize: 11.5,
                  color: text,
                  fontWeight: (isCompleted || isCurrent || isMyStop)
                      ? FontWeight.bold
                      : FontWeight.normal,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              if (scheduledTime.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '($scheduledTime)',
                  style: TextStyle(
                    fontSize: 10,
                    color: text.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.chevron_right, size: 14, color: Colors.grey),
          ),
      ],
    );
  }
}

