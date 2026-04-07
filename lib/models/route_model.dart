import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteModel {
  final String routeId;
  final String routeName;
  final List<String> stops;
  final List<LatLng> stopCoordinates;
  final String assignedDriverId;
  final String morningSchedule;
  final String eveningSchedule;

  RouteModel({
    required this.routeId,
    required this.routeName,
    required this.stops,
    required this.stopCoordinates,
    required this.assignedDriverId,
    required this.morningSchedule,
    required this.eveningSchedule,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawCoords = data['stopCoordinates'] as List<dynamic>? ?? [];
    final coords = rawCoords.map((c) {
      final map = c as Map<String, dynamic>;
      return LatLng(
        (map['lat'] as num).toDouble(),
        (map['lng'] as num).toDouble(),
      );
    }).toList();

    final schedule = data['schedule'] as Map<String, dynamic>? ?? {};

    return RouteModel(
      routeId: doc.id,
      routeName: data['routeName'] as String? ?? '',
      stops: List<String>.from(data['stops'] as List? ?? []),
      stopCoordinates: coords,
      assignedDriverId: data['assignedDriverId'] as String? ?? '',
      morningSchedule: schedule['morning'] as String? ?? '',
      eveningSchedule: schedule['evening'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'routeName': routeName,
      'stops': stops,
      'stopCoordinates': stopCoordinates
          .map((c) => {'lat': c.latitude, 'lng': c.longitude})
          .toList(),
      'assignedDriverId': assignedDriverId,
      'schedule': {
        'morning': morningSchedule,
        'evening': eveningSchedule,
      },
    };
  }
}
