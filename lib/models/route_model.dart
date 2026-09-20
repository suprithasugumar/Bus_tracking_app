import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/directions_service.dart';

class RouteModel {
  final String routeId;
  final String routeName;
  final List<String> stops;
  final List<LatLng> stopCoordinates;
  final List<LatLng> polylinePoints;
  final String encodedPolyline;
  final List<String> scheduledTimes;
  final String assignedDriverId;
  final String morningSchedule;
  final String eveningSchedule;
  final String busNumber;

  RouteModel({
    required this.routeId,
    required this.routeName,
    required this.stops,
    required this.stopCoordinates,
    List<LatLng>? polylinePoints,
    String? encodedPolyline,
    List<String>? scheduledTimes,
    required this.assignedDriverId,
    required this.morningSchedule,
    required this.eveningSchedule,
    this.busNumber = '',
  })  : polylinePoints = (polylinePoints != null && polylinePoints.isNotEmpty)
            ? polylinePoints
            : (encodedPolyline != null && encodedPolyline.isNotEmpty
                ? DirectionsService.decodePolyline(encodedPolyline)
                : stopCoordinates),
        encodedPolyline = encodedPolyline ??
            (polylinePoints != null && polylinePoints.isNotEmpty
                ? DirectionsService.encodePolyline(polylinePoints)
                : DirectionsService.encodePolyline(stopCoordinates)),
        scheduledTimes = scheduledTimes ?? [];

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawCoords = data['stopCoordinates'] as List<dynamic>? ?? [];
    final coords = rawCoords.map((c) {
      final map = c as Map<String, dynamic>;
      return LatLng(
        (map['lat'] as num).toDouble(),
        (map['lng'] as num).toDouble(),
      );
    }).toList();

    List<LatLng> polyPoints = [];
    String encodedStr = '';

    final rawPoly = data['polylinePoints'];
    if (rawPoly is String && rawPoly.isNotEmpty) {
      encodedStr = rawPoly;
      polyPoints = DirectionsService.decodePolyline(rawPoly);
    } else if (rawPoly is List && rawPoly.isNotEmpty) {
      polyPoints = rawPoly.map((c) {
        final map = c as Map<String, dynamic>;
        return LatLng(
          (map['lat'] as num).toDouble(),
          (map['lng'] as num).toDouble(),
        );
      }).toList();
      encodedStr = DirectionsService.encodePolyline(polyPoints);
    }

    final rawScheduledTimes = data['scheduledTimes'] as List<dynamic>? ?? [];
    final scheduledTimes = rawScheduledTimes.map((t) => t.toString()).toList();

    final schedule = data['schedule'] as Map<String, dynamic>? ?? {};

    return RouteModel(
      routeId: doc.id,
      routeName: data['routeName'] as String? ?? '',
      stops: List<String>.from(data['stops'] as List? ?? []),
      stopCoordinates: coords,
      polylinePoints: polyPoints.isNotEmpty ? polyPoints : coords,
      encodedPolyline: encodedStr.isNotEmpty
          ? encodedStr
          : DirectionsService.encodePolyline(coords),
      scheduledTimes: scheduledTimes,
      assignedDriverId: data['assignedDriverId'] as String? ?? '',
      morningSchedule: schedule['morning'] as String? ?? '',
      eveningSchedule: schedule['evening'] as String? ?? '',
      busNumber: data['busNumber'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'routeName': routeName,
      'stops': stops,
      'stopCoordinates': stopCoordinates
          .map((c) => {'lat': c.latitude, 'lng': c.longitude})
          .toList(),
      'polylinePoints': encodedPolyline.isNotEmpty
          ? encodedPolyline
          : DirectionsService.encodePolyline(polylinePoints),
      'scheduledTimes': scheduledTimes,
      'assignedDriverId': assignedDriverId,
      'busNumber': busNumber,
      'schedule': {
        'morning': morningSchedule,
        'evening': eveningSchedule,
      },
    };
  }
}

