import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Handles GPS location permission checks and streaming
class LocationService {
  /// Check and request location permission.
  /// Returns true if granted.
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled on the device
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Get the current position once
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// A continuous stream of GPS position updates.
  /// Updates every 10 metres of movement.
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // only emit when moved at least 10m
      ),
    );
  }

  /// Check if two GPS coordinates are within [radiusMeters] of each other.
  /// Used for detecting when the bus is near a stop.
  static bool isWithinRadius(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    double radiusMeters,
  ) {
    final distance = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    return distance <= radiusMeters;
  }

  /// Returns the index of the nearest stop from the given position,
  /// or -1 if no stop is within [thresholdMeters].
  static int nearestStopIndex(
    LatLng position,
    List<LatLng> stopCoordinates, {
    double thresholdMeters = 150,
  }) {
    for (int i = 0; i < stopCoordinates.length; i++) {
      final stop = stopCoordinates[i];
      if (isWithinRadius(
        position.latitude,
        position.longitude,
        stop.latitude,
        stop.longitude,
        thresholdMeters,
      )) {
        return i;
      }
    }
    return -1;
  }
}
