import 'package:cloud_firestore/cloud_firestore.dart';

class TripRecord {
  final String id;
  final String driverId;
  final String driverName;
  final String routeId;
  final String routeName;
  final DateTime startTime;
  final DateTime? endTime;

  TripRecord({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.routeId,
    required this.routeName,
    required this.startTime,
    this.endTime,
  });

  bool get isCompleted => endTime != null;

  String get durationText {
    final end = endTime ?? DateTime.now();
    final diff = end.difference(startTime);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min';
    }
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '${hours}h ${mins}m';
  }

  factory TripRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TripRecord(
      id: doc.id,
      driverId: data['driverId'] as String? ?? '',
      driverName: data['driverName'] as String? ?? 'Driver',
      routeId: data['routeId'] as String? ?? '',
      routeName: data['routeName'] as String? ?? '',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
    );
  }
}
