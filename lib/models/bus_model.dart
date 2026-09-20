import 'package:cloud_firestore/cloud_firestore.dart';

class BusLocation {
  final String driverId;
  final String busId;
  final double latitude;
  final double longitude;
  final bool isOnline;
  final bool isTracking;
  final String routeName;
  final String routeId;
  final double speed; // km/h
  final double heading; // degrees (0-360)
  final int passengerCount;
  final int currentStopIndex;
  final List<String> completedStops;
  final Map<String, dynamic> stopStatuses;
  final DateTime? timestamp;

  BusLocation({
    this.driverId = '',
    this.busId = '',
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    this.isTracking = false,
    required this.routeName,
    required this.routeId,
    required this.speed,
    this.heading = 0.0,
    this.passengerCount = 0,
    this.currentStopIndex = 0,
    this.completedStops = const [],
    this.stopStatuses = const {},
    this.timestamp,
  });

  factory BusLocation.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final ts = data['timestamp'];
    final rawStops = data['completedStops'] as List<dynamic>? ?? [];
    final rawStatuses = data['stopStatuses'] as Map<String, dynamic>? ?? {};
    return BusLocation(
      driverId: (data['driverId'] as String?) ?? doc.id,
      busId: (data['busId'] as String?) ?? (data['routeId'] as String?) ?? doc.id,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      isOnline: data['isOnline'] as bool? ?? false,
      isTracking: data['isTracking'] as bool? ?? data['isOnline'] as bool? ?? false,
      routeName: data['routeName'] as String? ?? '',
      routeId: data['routeId'] as String? ?? '',
      speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
      passengerCount: (data['passengerCount'] as num?)?.toInt() ?? 0,
      currentStopIndex: (data['currentStopIndex'] as num?)?.toInt() ?? 0,
      completedStops: rawStops.map((s) => s.toString()).toList(),
      stopStatuses: rawStatuses,
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'busId': busId.isNotEmpty ? busId : routeId,
      'latitude': latitude,
      'longitude': longitude,
      'isOnline': isOnline,
      'isTracking': isTracking,
      'routeName': routeName,
      'routeId': routeId,
      'speed': speed,
      'heading': heading,
      'passengerCount': passengerCount,
      'currentStopIndex': currentStopIndex,
      'completedStops': completedStops,
      'stopStatuses': stopStatuses,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}


