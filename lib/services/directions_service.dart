import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Service for calculating road-following route polylines and live ETAs.
/// Supports Google Directions API with automatic fallback to free OSRM Routing.
class DirectionsService {
  static final DirectionsService instance = DirectionsService._internal();
  factory DirectionsService() => instance;
  DirectionsService._internal();

  /// Configurable Google Maps Directions API key.
  /// Pass via `--dart-define=GOOGLE_MAPS_API_KEY=your_key` during build,
  /// or set at runtime if needed.
  static String apiKey = const String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // ─── Throttle & Cache for Live ETA ──────────────────────────────────────────
  DateTime? _lastEtaQueryTime;
  LatLng? _lastEtaBusPosition;
  String? _lastEtaTargetStopKey;
  int _cachedEtaMinutes = 0;
  String _cachedSource = 'cache';

  /// Decodes an encoded Google Polyline string into a list of LatLng coordinates.
  static List<LatLng> decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];
    final List<LatLng> poly = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  /// Encodes a list of LatLng coordinates into an encoded Google Polyline string.
  static String encodePolyline(List<LatLng> coordinates) {
    if (coordinates.isEmpty) return '';
    final StringBuffer str = StringBuffer();
    int lastLat = 0;
    int lastLng = 0;

    for (final point in coordinates) {
      final int lat = (point.latitude * 1e5).round();
      final int lng = (point.longitude * 1e5).round();

      _encodePoint(lat - lastLat, str);
      _encodePoint(lng - lastLng, str);

      lastLat = lat;
      lastLng = lng;
    }
    return str.toString();
  }

  static void _encodePoint(int val, StringBuffer str) {
    int v = val < 0 ? ~(val << 1) : (val << 1);
    while (v >= 0x20) {
      str.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    str.writeCharCode(v + 63);
  }

  /// Fetches the road-following encoded polyline string from OSRM or encodes waypoints as fallback.
  Future<String> fetchRoadEncodedPolyline(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return '';
    try {
      final rawCoords = waypoints
          .map((w) => '${w.longitude.toStringAsFixed(6)},${w.latitude.toStringAsFixed(6)}')
          .join(';');
      final url =
          'https://router.project-osrm.org/route/v1/driving/$rawCoords?overview=full&geometries=polyline';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          return data['routes'][0]['geometry'] as String;
        }
      }
    } catch (e) {
      debugPrint('[DirectionsService] OSRM encoded polyline fetch error: $e');
    }
    return encodePolyline(waypoints);
  }

  /// Fetches a complete road-following polyline connecting all provided waypoints.
  /// Handles chunking for routes with > 25 points and falls back to OSRM if Google API fails.
  Future<List<LatLng>> fetchRoadPolyline(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return waypoints;

    // 1. Try Google Directions API if key is present
    if (apiKey.isNotEmpty) {
      try {
        final points = await _fetchGoogleDirectionsPolyline(waypoints);
        if (points.isNotEmpty && points.length > waypoints.length) return points;
      } catch (e) {
        debugPrint('[DirectionsService] Google Directions error: $e. Falling back to OSRM.');
      }
    }

    // 2. Free Fallback: OSRM full route
    try {
      final points = await _fetchOsrmPolyline(waypoints);
      if (points.isNotEmpty && points.length > waypoints.length) return points;
    } catch (e) {
      debugPrint('[DirectionsService] OSRM multi-point error: $e');
    }

    // 3. Fallback: Pairwise OSRM segments between consecutive stops
    try {
      final List<LatLng> stitched = [];
      for (int i = 0; i < waypoints.length - 1; i++) {
        final segment = await _fetchOsrmPair(waypoints[i], waypoints[i + 1]);
        if (segment.isNotEmpty) {
          if (stitched.isNotEmpty) {
            stitched.addAll(segment.skip(1));
          } else {
            stitched.addAll(segment);
          }
        } else {
          if (stitched.isEmpty) stitched.add(waypoints[i]);
          stitched.add(waypoints[i + 1]);
        }
      }
      if (stitched.length > waypoints.length) {
        return stitched;
      }
    } catch (e) {
      debugPrint('[DirectionsService] Pairwise OSRM error: $e');
    }

    // 4. Last fallback: return the original stop coordinates
    return waypoints;
  }

  /// Fetches the driving road path between two specific GPS coordinates via OSRM.
  Future<List<LatLng>> _fetchOsrmPair(LatLng origin, LatLng dest) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/${origin.longitude.toStringAsFixed(6)},${origin.latitude.toStringAsFixed(6)};${dest.longitude.toStringAsFixed(6)},${dest.latitude.toStringAsFixed(6)}?overview=full&geometries=polyline';
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final geometry = data['routes'][0]['geometry'] as String;
          return decodePolyline(geometry);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Calls Google Directions API with automatic waypoint chunking (max 25 per request).
  Future<List<LatLng>> _fetchGoogleDirectionsPolyline(List<LatLng> waypoints) async {
    final List<LatLng> fullPolyline = [];
    const int maxChunkSize = 23; // Origin + Dest + 23 waypoints = 25 max

    for (int i = 0; i < waypoints.length - 1; i += maxChunkSize) {
      final int end = math.min(i + maxChunkSize + 1, waypoints.length);
      final subList = waypoints.sublist(i, end);
      if (subList.length < 2) continue;

      final origin = subList.first;
      final dest = subList.last;
      final intermediates = subList.sublist(1, subList.length - 1);

      String url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&mode=driving&key=$apiKey';

      if (intermediates.isNotEmpty) {
        final waypointsParam = intermediates
            .map((w) => '${w.latitude},${w.longitude}')
            .join('|');
        url += '&waypoints=optimize:false|$waypointsParam';
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final pointsString = data['routes'][0]['overview_polyline']['points'];
          final decoded = decodePolyline(pointsString);
          if (fullPolyline.isNotEmpty && decoded.isNotEmpty) {
            // Avoid duplicate connecting point
            fullPolyline.addAll(decoded.skip(1));
          } else {
            fullPolyline.addAll(decoded);
          }
        }
      }
    }
    return fullPolyline;
  }

  /// Free road-following polyline via Open Source Routing Machine (OSRM).
  Future<List<LatLng>> _fetchOsrmPolyline(List<LatLng> waypoints) async {
    // OSRM format: lng,lat;lng,lat;...
    final coords = waypoints
        .map((w) => '${w.longitude.toStringAsFixed(6)},${w.latitude.toStringAsFixed(6)}')
        .join(';');

    final url =
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=polyline';

    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
        final geometry = data['routes'][0]['geometry'] as String;
        return decodePolyline(geometry);
      }
    }
    return [];
  }

  // ─── Polyline Road Distance Calculation ─────────────────────────────────────

  /// Measures distance in meters ALONG the road polyline from the bus's projected
  /// position to the target stop coordinate.
  static PolylineDistanceResult measureDistanceAlongPolyline({
    required List<LatLng> polylinePoints,
    required LatLng busPosition,
    required LatLng targetStopCoord,
    int? currentStopIndex,
    int? targetStopIndex,
  }) {
    if (polylinePoints.length < 2) {
      final direct = calculateHaversineDistanceMeters(
        busPosition.latitude,
        busPosition.longitude,
        targetStopCoord.latitude,
        targetStopCoord.longitude,
      );
      final hasPassed = (targetStopIndex != null && currentStopIndex != null && targetStopIndex < currentStopIndex);
      return PolylineDistanceResult(
        distanceMeters: direct * 1.25,
        hasPassed: hasPassed,
        busProjection: busPosition,
      );
    }

    // 1. Find the closest polyline segment & projection for the bus
    int busSegIndex = 0;
    double minBusDist = double.infinity;
    LatLng busProj = polylinePoints.first;
    double busSegFraction = 0.0;

    for (int i = 0; i < polylinePoints.length - 1; i++) {
      final p1 = polylinePoints[i];
      final p2 = polylinePoints[i + 1];
      final proj = _projectPointOnSegment(busPosition, p1, p2);
      final dist = calculateHaversineDistanceMeters(
        busPosition.latitude,
        busPosition.longitude,
        proj.point.latitude,
        proj.point.longitude,
      );
      if (dist < minBusDist) {
        minBusDist = dist;
        busSegIndex = i;
        busProj = proj.point;
        busSegFraction = proj.fraction;
      }
    }

    // 2. Find the closest polyline segment & projection for the target stop
    int stopSegIndex = 0;
    double minStopDist = double.infinity;
    LatLng stopProj = polylinePoints.last;
    double stopSegFraction = 0.0;

    for (int i = 0; i < polylinePoints.length - 1; i++) {
      final p1 = polylinePoints[i];
      final p2 = polylinePoints[i + 1];
      final proj = _projectPointOnSegment(targetStopCoord, p1, p2);
      final dist = calculateHaversineDistanceMeters(
        targetStopCoord.latitude,
        targetStopCoord.longitude,
        proj.point.latitude,
        proj.point.longitude,
      );
      if (dist < minStopDist) {
        minStopDist = dist;
        stopSegIndex = i;
        stopProj = proj.point;
        stopSegFraction = proj.fraction;
      }
    }

    // 3. Check if the bus has already passed the target stop
    bool hasPassed = false;
    if (targetStopIndex != null && currentStopIndex != null && targetStopIndex < currentStopIndex) {
      hasPassed = true;
    } else if (busSegIndex > stopSegIndex) {
      hasPassed = true;
    } else if (busSegIndex == stopSegIndex && busSegFraction > stopSegFraction + 0.08) {
      hasPassed = true;
    }

    if (hasPassed) {
      return PolylineDistanceResult(
        distanceMeters: 0.0,
        hasPassed: true,
        busProjection: busProj,
      );
    }

    // 4. Measure distance along road segments between bus projection and stop projection
    double roadDistance = minBusDist; // distance from off-route bus to route line

    if (busSegIndex == stopSegIndex) {
      roadDistance += calculateHaversineDistanceMeters(
        busProj.latitude,
        busProj.longitude,
        stopProj.latitude,
        stopProj.longitude,
      );
    } else {
      // (a) From bus projection to end of bus segment
      roadDistance += calculateHaversineDistanceMeters(
        busProj.latitude,
        busProj.longitude,
        polylinePoints[busSegIndex + 1].latitude,
        polylinePoints[busSegIndex + 1].longitude,
      );

      // (b) Full intermediate road segments
      for (int i = busSegIndex + 1; i < stopSegIndex; i++) {
        roadDistance += calculateHaversineDistanceMeters(
          polylinePoints[i].latitude,
          polylinePoints[i].longitude,
          polylinePoints[i + 1].latitude,
          polylinePoints[i + 1].longitude,
        );
      }

      // (c) From start of stop segment to stop projection
      roadDistance += calculateHaversineDistanceMeters(
        polylinePoints[stopSegIndex].latitude,
        polylinePoints[stopSegIndex].longitude,
        stopProj.latitude,
        stopProj.longitude,
      );
    }

    // (d) Add offset from stop projection to actual stop coordinate
    roadDistance += minStopDist;

    return PolylineDistanceResult(
      distanceMeters: roadDistance,
      hasPassed: false,
      busProjection: busProj,
    );
  }

  static _ProjectionResult _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final double dx = b.longitude - a.longitude;
    final double dy = b.latitude - a.latitude;
    final double lenSq = dx * dx + dy * dy;

    if (lenSq == 0) {
      return _ProjectionResult(point: a, fraction: 0.0);
    }

    final double t = (((p.longitude - a.longitude) * dx) + ((p.latitude - a.latitude) * dy)) / lenSq;
    final double clampedT = t.clamp(0.0, 1.0);

    return _ProjectionResult(
      point: LatLng(a.latitude + clampedT * dy, a.longitude + clampedT * dx),
      fraction: clampedT,
    );
  }

  // ─── Real Live ETA Calculation ─────────────────────────────────────────────

  /// Calculates real live road ETA (in minutes and formatted text) from the live bus position
  /// to the student's selected stop along the road polyline.
  ///
  /// Incorporates:
  /// - Distance measured strictly ALONG the road polyline.
  /// - Rolling speed average (last 60-90s, speed > 2 km/h, accuracy < 50m, clamped 15-60 km/h).
  /// - 30s dwell time per unreached intermediate stop.
  /// - Throttled Directions API / OSRM routing.
  /// - Honest states ("Trip not started", "Waiting for bus location", "Bus has passed your stop", "Arrived").
  Future<EtaResult> calculateLiveEta({
    required LatLng busPosition,
    required LatLng targetStopCoord,
    required String stopName,
    required List<LatLng> roadPolyline,
    required bool isTripActive,
    required bool isBusOnline,
    required DateTime? lastTelemetryTimestamp,
    required bool isStopCompleted,
    int? currentStopIndex,
    int? targetStopIndex,
    int intermediateStopsCount = 0,
    List<GpsReading> recentGpsReadings = const [],
    int? previousEtaMinutes,
  }) async {
    final now = DateTime.now();

    // ── 1. Honest State: Trip Not Started ────────────────────────────────────
    if (!isTripActive || !isBusOnline) {
      return const EtaResult(
        minutes: 0,
        distanceMeters: 0,
        displayText: 'Trip not started',
        source: 'honest_state',
        state: EtaState.tripNotStarted,
      );
    }

    // ── 2. Honest State: Telemetry Stale or Missing ──────────────────────────
    if (lastTelemetryTimestamp == null ||
        now.difference(lastTelemetryTimestamp).inSeconds > 30) {
      return const EtaResult(
        minutes: 0,
        distanceMeters: 0,
        displayText: 'Waiting for bus location',
        source: 'honest_state',
        state: EtaState.waitingForLocation,
      );
    }

    // ── 3. Honest State: Stop Already Reached ────────────────────────────────
    final directDistanceMeters = calculateHaversineDistanceMeters(
      busPosition.latitude,
      busPosition.longitude,
      targetStopCoord.latitude,
      targetStopCoord.longitude,
    );

    if (isStopCompleted || directDistanceMeters <= 40) {
      return EtaResult(
        minutes: 0,
        distanceMeters: directDistanceMeters.round(),
        isArrived: true,
        displayText: 'Arrived',
        source: 'proximity',
        state: EtaState.arrived,
      );
    }

    // ── 4. Distance Along Road Polyline & Passed Check ────────────────────────
    final polyDistResult = measureDistanceAlongPolyline(
      polylinePoints: roadPolyline,
      busPosition: busPosition,
      targetStopCoord: targetStopCoord,
      currentStopIndex: currentStopIndex,
      targetStopIndex: targetStopIndex,
    );

    if (polyDistResult.hasPassed) {
      return const EtaResult(
        minutes: 0,
        distanceMeters: 0,
        displayText: 'Bus has passed your stop',
        source: 'honest_state',
        state: EtaState.passed,
      );
    }

    final double remainingDistanceMeters = polyDistResult.distanceMeters > 0
        ? polyDistResult.distanceMeters
        : directDistanceMeters * 1.25;

    // ── 5. Rolling Average Speed Calculation (60-90s, > 2km/h, accuracy < 50m) ─
    double? rollingAvgSpeedKmH;
    final validGpsReadings = recentGpsReadings.where((r) {
      final ageSec = now.difference(r.timestamp).inSeconds;
      return ageSec <= 90 && r.speedKmH >= 2.0 && r.accuracy <= 50.0;
    }).toList();

    if (validGpsReadings.isNotEmpty) {
      final sum = validGpsReadings.fold<double>(0.0, (acc, r) => acc + r.speedKmH);
      final rawAvg = sum / validGpsReadings.length;
      rollingAvgSpeedKmH = rawAvg.clamp(15.0, 60.0); // City bus clamp 15-60 km/h
    }

    // Intermediate stops dwell time (30s per unreached stop)
    final dwellTimeSeconds = math.max(0, intermediateStopsCount) * 30;

    // ── 6. Throttled API / OSRM / Rolling Speed Routing ───────────────────────
    final targetKey = '${targetStopCoord.latitude.toStringAsFixed(4)}_${targetStopCoord.longitude.toStringAsFixed(4)}';
    int computedMinutes = 1;
    String computationMethod = 'fallback_speed';

    // Throttle check (cache valid for 30s unless bus moved > 200m)
    bool canUseCache = false;
    if (_lastEtaQueryTime != null && _lastEtaBusPosition != null && _lastEtaTargetStopKey == targetKey) {
      final elapsedSeconds = now.difference(_lastEtaQueryTime!).inSeconds;
      final movedDistance = calculateHaversineDistanceMeters(
        busPosition.latitude,
        busPosition.longitude,
        _lastEtaBusPosition!.latitude,
        _lastEtaBusPosition!.longitude,
      );

      if (elapsedSeconds < 35 && movedDistance < 200 && _cachedEtaMinutes > 0) {
        canUseCache = true;
        computedMinutes = math.max(1, _cachedEtaMinutes - (elapsedSeconds ~/ 60));
        computationMethod = _cachedSource;
      }
    }

    if (!canUseCache) {
      bool apiSucceeded = false;

      // (A) Try Google Directions API if key configured
      if (apiKey.isNotEmpty) {
        try {
          final url =
              'https://maps.googleapis.com/maps/api/directions/json?origin=${busPosition.latitude},${busPosition.longitude}&destination=${targetStopCoord.latitude},${targetStopCoord.longitude}&departure_time=now&mode=driving&key=$apiKey';

          final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
              final leg = data['routes'][0]['legs'][0];
              final durationSec = (leg['duration_in_traffic']?['value'] ?? leg['duration']?['value'] ?? 60) as num;
              final totalSec = durationSec.toDouble() + dwellTimeSeconds;
              computedMinutes = math.max(1, (totalSec / 60.0).ceil());
              computationMethod = 'google_traffic';
              apiSucceeded = true;
            }
          }
        } catch (e) {
          debugPrint('[DirectionsService] Google ETA query failed: $e');
        }
      }

      // (B) Fallback: OSRM Driving Table
      if (!apiSucceeded) {
        try {
          final url =
              'https://router.project-osrm.org/route/v1/driving/${busPosition.longitude.toStringAsFixed(6)},${busPosition.latitude.toStringAsFixed(6)};${targetStopCoord.longitude.toStringAsFixed(6)},${targetStopCoord.latitude.toStringAsFixed(6)}?overview=false';

          final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
              final route = data['routes'][0];
              final durationSec = (route['duration'] as num?)?.toDouble() ?? 60.0;
              final totalSec = durationSec + dwellTimeSeconds;
              computedMinutes = math.max(1, (totalSec / 60.0).ceil());
              computationMethod = 'osrm';
              apiSucceeded = true;
            }
          }
        } catch (e) {
          debugPrint('[DirectionsService] OSRM ETA query failed: $e');
        }
      }

      // (C) Fallback: Distance along polyline / Rolling Average Speed
      if (!apiSucceeded) {
        final double speedKmH = rollingAvgSpeedKmH ?? 25.0; // fallback to 25 km/h if no valid GPS speed
        final double driveTimeSeconds = (remainingDistanceMeters / 1000.0) / speedKmH * 3600.0;
        final double totalSeconds = driveTimeSeconds + dwellTimeSeconds;
        computedMinutes = math.max(1, (totalSeconds / 60.0).ceil());
        computationMethod = rollingAvgSpeedKmH != null ? 'rolling_speed_avg' : 'polyline_fallback_25kmh';
      }

      // Update cache
      _lastEtaQueryTime = now;
      _lastEtaBusPosition = busPosition;
      _lastEtaTargetStopKey = targetKey;
      _cachedEtaMinutes = computedMinutes;
      _cachedSource = computationMethod;
    }

    // ── 7. Value Smoothing (prevent jumps > 2 min unless change is real) ───────
    int smoothedMinutes = computedMinutes;
    if (previousEtaMinutes != null && previousEtaMinutes > 0) {
      final diff = computedMinutes - previousEtaMinutes;
      if (diff.abs() > 2) {
        smoothedMinutes = previousEtaMinutes + (diff > 0 ? 1 : -1);
      }
    }

    // ── 8. Formatted Display: "Arriving in 7 min (~6:42 AM)" ───────────────────
    final arrivalTime = now.add(Duration(minutes: smoothedMinutes));
    final clockFormat = _formatClockTime(arrivalTime);
    final String displayText = smoothedMinutes <= 1
        ? 'Arriving now'
        : 'Arriving in $smoothedMinutes min ($clockFormat)';

    // ── 9. Temporary Debug Log (Remaining Dist, Avg Speed, Method, Result) ─────
    debugPrint(
      '[ETA Debug] Stop: "$stopName" | Dist: ${remainingDistanceMeters.toStringAsFixed(0)}m | '
      'Speed: ${rollingAvgSpeedKmH?.toStringAsFixed(1) ?? "N/A"} km/h | '
      'Dwell: $intermediateStopsCount stops (${dwellTimeSeconds}s) | '
      'Method: $computationMethod | Result: "$displayText"',
    );

    return EtaResult(
      minutes: smoothedMinutes,
      distanceMeters: remainingDistanceMeters.round(),
      isArrived: false,
      displayText: displayText,
      source: computationMethod,
      state: EtaState.active,
    );
  }

  static String _formatClockTime(DateTime time) {
    final int hour = time.hour;
    final int minute = time.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final String formattedMinute = minute.toString().padLeft(2, '0');
    return '~$formattedHour:$formattedMinute $period';
  }

  /// Calculates Haversine distance in meters between two lat/lng coordinates.
  static double calculateHaversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371000.0; // Earth radius in meters
    final double phi1 = lat1 * math.pi / 180;
    final double phi2 = lat2 * math.pi / 180;
    final double deltaPhi = (lat2 - lat1) * math.pi / 180;
    final double deltaLambda = (lon2 - lon1) * math.pi / 180;

    final double a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return r * c;
  }
}

/// Helper result for polyline projection
class _ProjectionResult {
  final LatLng point;
  final double fraction;
  const _ProjectionResult({required this.point, required this.fraction});
}

/// Result of road polyline distance measurement
class PolylineDistanceResult {
  final double distanceMeters;
  final bool hasPassed;
  final LatLng busProjection;

  const PolylineDistanceResult({
    required this.distanceMeters,
    required this.hasPassed,
    required this.busProjection,
  });
}

/// Real-time GPS reading snapshot for rolling average calculation
class GpsReading {
  final DateTime timestamp;
  final double speedKmH;
  final LatLng position;
  final double accuracy;

  const GpsReading({
    required this.timestamp,
    required this.speedKmH,
    required this.position,
    this.accuracy = 10.0,
  });
}

/// Explicit lifecycle states for bus arrival
enum EtaState {
  tripNotStarted,
  waitingForLocation,
  passed,
  arrived,
  active,
}

/// Structured ETA computation result.
class EtaResult {
  final int minutes;
  final int distanceMeters;
  final bool isArrived;
  final String displayText;
  final String source; // 'google_traffic' | 'osrm' | 'rolling_speed_avg' | 'polyline_fallback_25kmh' | 'cache' | 'proximity' | 'honest_state'
  final EtaState state;

  const EtaResult({
    required this.minutes,
    required this.distanceMeters,
    this.isArrived = false,
    required this.displayText,
    required this.source,
    this.state = EtaState.active,
  });
}
