import 'package:cloud_firestore/cloud_firestore.dart';

class BusLocation {
  final double latitude;
  final double longitude;
  final bool isOnline;
  final String routeName;
  final String routeId;
  final double speed; // km/h
  final DateTime? timestamp;

  BusLocation({
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    required this.routeName,
    required this.routeId,
    required this.speed,
    this.timestamp,
  });

  factory BusLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['timestamp'];
    return BusLocation(
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      isOnline: data['isOnline'] as bool? ?? false,
      routeName: data['routeName'] as String? ?? '',
      routeId: data['routeId'] as String? ?? '',
      speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'isOnline': isOnline,
      'routeName': routeName,
      'routeId': routeId,
      'speed': speed,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
