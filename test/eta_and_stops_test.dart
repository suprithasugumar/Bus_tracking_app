import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bus_tracking_app/services/directions_service.dart';
import 'package:bus_tracking_app/utils/stop_utils.dart';

void main() {
  group('Phase 1 - A1: Real Road-Polyline ETA and Honest States', () {
    final routePolyline = [
      const LatLng(13.0850, 80.2101), // Stop 1: Anna Nagar Tower
      const LatLng(13.0780, 80.2020), // road waypoint
      const LatLng(13.0694, 80.1948), // Stop 2: Koyambedu
      const LatLng(13.0600, 80.2030), // road waypoint
      const LatLng(13.0524, 80.2120), // Stop 3: Vadapalani
    ];

    test('Honest State: Trip Not Started when bus is offline / not tracking', () async {
      final result = await DirectionsService.instance.calculateLiveEta(
        busPosition: const LatLng(13.0850, 80.2101),
        targetStopCoord: const LatLng(13.0524, 80.2120),
        stopName: 'Vadapalani',
        roadPolyline: routePolyline,
        isTripActive: false,
        isBusOnline: false,
        lastTelemetryTimestamp: DateTime.now(),
        isStopCompleted: false,
      );

      expect(result.state, EtaState.tripNotStarted);
      expect(result.displayText, 'Trip not started');
    });

    test('Honest State: Waiting for bus location when telemetry is stale (>30s)', () async {
      final result = await DirectionsService.instance.calculateLiveEta(
        busPosition: const LatLng(13.0850, 80.2101),
        targetStopCoord: const LatLng(13.0524, 80.2120),
        stopName: 'Vadapalani',
        roadPolyline: routePolyline,
        isTripActive: true,
        isBusOnline: true,
        lastTelemetryTimestamp: DateTime.now().subtract(const Duration(seconds: 45)),
        isStopCompleted: false,
      );

      expect(result.state, EtaState.waitingForLocation);
      expect(result.displayText, 'Waiting for bus location');
    });

    test('Honest State: Arrived when stop is completed or bus is within 40m', () async {
      final result = await DirectionsService.instance.calculateLiveEta(
        busPosition: const LatLng(13.0524, 80.2120),
        targetStopCoord: const LatLng(13.0524, 80.2120),
        stopName: 'Vadapalani',
        roadPolyline: routePolyline,
        isTripActive: true,
        isBusOnline: true,
        lastTelemetryTimestamp: DateTime.now(),
        isStopCompleted: true,
      );

      expect(result.state, EtaState.arrived);
      expect(result.displayText, 'Arrived');
      expect(result.isArrived, true);
    });

    test('Honest State: Bus has passed your stop when bus is ahead on polyline', () async {
      final result = await DirectionsService.instance.calculateLiveEta(
        busPosition: const LatLng(13.0524, 80.2120), // At Stop 3
        targetStopCoord: const LatLng(13.0850, 80.2101), // Stop 1 (already passed)
        stopName: 'Anna Nagar Tower',
        roadPolyline: routePolyline,
        isTripActive: true,
        isBusOnline: true,
        lastTelemetryTimestamp: DateTime.now(),
        isStopCompleted: false,
        currentStopIndex: 2,
        targetStopIndex: 0,
      );

      expect(result.state, EtaState.passed);
      expect(result.displayText, 'Bus has passed your stop');
    });

    test('Polyline Distance along road is measured correctly', () {
      final distResult = DirectionsService.measureDistanceAlongPolyline(
        polylinePoints: routePolyline,
        busPosition: const LatLng(13.0850, 80.2101),
        targetStopCoord: const LatLng(13.0524, 80.2120),
      );

      expect(distResult.hasPassed, false);
      expect(distResult.distanceMeters, greaterThan(3000)); // ~4-5 km along path
    });

    test('Simulated bus moving toward stop: ETA decreases steadily with distance and speed', () async {
      final now = DateTime.now();

      // Step 1: Bus near Stop 1 (Anna Nagar) moving at 30 km/h
      final step1Gps = [
        GpsReading(timestamp: now.subtract(const Duration(seconds: 10)), speedKmH: 30.0, position: const LatLng(13.0850, 80.2101), accuracy: 5.0),
        GpsReading(timestamp: now, speedKmH: 32.0, position: const LatLng(13.0850, 80.2101), accuracy: 5.0),
      ];

      final eta1 = await DirectionsService.instance.calculateLiveEta(
        busPosition: const LatLng(13.0850, 80.2101),
        targetStopCoord: const LatLng(13.0524, 80.2120), // Target: Stop 3
        stopName: 'Vadapalani',
        roadPolyline: routePolyline,
        isTripActive: true,
        isBusOnline: true,
        lastTelemetryTimestamp: now,
        isStopCompleted: false,
        currentStopIndex: 0,
        targetStopIndex: 2,
        intermediateStopsCount: 1, // 1 intermediate stop (Koyambedu)
        recentGpsReadings: step1Gps,
      );

      // Step 2: Bus moves closer, at Stop 2 (Koyambedu)
      final step2Gps = [
        GpsReading(timestamp: now.subtract(const Duration(seconds: 10)), speedKmH: 30.0, position: const LatLng(13.0694, 80.1948), accuracy: 5.0),
        GpsReading(timestamp: now, speedKmH: 34.0, position: const LatLng(13.0694, 80.1948), accuracy: 5.0),
      ];

      final eta2 = await DirectionsService.instance.calculateLiveEta(
        busPosition: const LatLng(13.0694, 80.1948),
        targetStopCoord: const LatLng(13.0524, 80.2120),
        stopName: 'Vadapalani',
        roadPolyline: routePolyline,
        isTripActive: true,
        isBusOnline: true,
        lastTelemetryTimestamp: now,
        isStopCompleted: false,
        currentStopIndex: 1,
        targetStopIndex: 2,
        intermediateStopsCount: 0, // 0 intermediate stops remaining
        recentGpsReadings: step2Gps,
        previousEtaMinutes: eta1.minutes,
      );

      // Verify distance decreased
      expect(eta2.distanceMeters, lessThan(eta1.distanceMeters));
      // Verify ETA minutes decreased
      expect(eta2.minutes, lessThanOrEqualTo(eta1.minutes));
      // Verify dual display format: "Arriving in X min (~H:MM AM)"
      expect(eta1.displayText, matches(r'Arriving in \d+ min \(~\d+:\d+ (AM|PM)\)'));
    });
  });

  group('Phase 1 - A2: Next-Stop and Destination Arrived Resolution', () {
    final stops = ['Anna Nagar', 'Koyambedu', 'Vadapalani', 'Guindy', 'VIT Chennai'];

    test('When trip is offline, getNextStopIndex returns -1 and isTripCompleted returns false', () {
      final nextIdx = StopUtils.getNextStopIndex(
        stops: stops,
        completedStops: [],
        isOnline: false,
      );
      expect(nextIdx, -1);

      final isComplete = StopUtils.isTripCompleted(
        stops: stops,
        completedStops: [],
        isOnline: false,
      );
      expect(isComplete, false);
    });

    test('When trip is active and 0 stops reached, Stop 1 (index 0) is next', () {
      final nextIdx = StopUtils.getNextStopIndex(
        stops: stops,
        completedStops: [],
        isOnline: true,
      );
      expect(nextIdx, 0);
    });

    test('When Stop 1 is reached, Stop 2 (index 1) is next', () {
      final nextIdx = StopUtils.getNextStopIndex(
        stops: stops,
        completedStops: ['Anna Nagar'],
        isOnline: true,
      );
      expect(nextIdx, 1);
    });

    test('Destination Arrived is true ONLY when all stops are completed', () {
      final partialComplete = StopUtils.isTripCompleted(
        stops: stops,
        completedStops: ['Anna Nagar', 'Koyambedu', 'Vadapalani'],
        isOnline: true,
      );
      expect(partialComplete, false);

      final allComplete = StopUtils.isTripCompleted(
        stops: stops,
        completedStops: stops,
        isOnline: true,
      );
      expect(allComplete, true);
    });
  });
}
