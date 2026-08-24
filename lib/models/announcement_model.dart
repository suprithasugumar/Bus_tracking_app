import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String routeId;
  final String message;
  final String postedBy;
  final DateTime timestamp;

  Announcement({
    required this.id,
    required this.routeId,
    required this.message,
    required this.postedBy,
    required this.timestamp,
  });

  DateTime get postedAt => timestamp;

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Announcement(
      id: doc.id,
      routeId: data['routeId'] as String? ?? '',
      message: data['message'] as String? ?? '',
      postedBy: data['postedBy'] as String? ?? 'Driver',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'routeId': routeId,
      'message': message,
      'postedBy': postedBy,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
