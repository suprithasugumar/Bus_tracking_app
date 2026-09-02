import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';
import '../models/bus_model.dart';
import '../models/user_profile.dart';
import '../models/announcement_model.dart';
import '../models/trip_record_model.dart';
import 'seed_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── User ──────────────────────────────────────────────────────────────────

  Future<void> saveUserRole(String uid, String role,
      {String name = '', String phone = '', String email = ''}) async {
    await _db.collection('users').doc(uid).set({
      'role': role,
      'name': name,
      'phone': phone,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) return doc['role'] as String?;
    return null;
  }

  Future<void> saveUserRouteId(String uid, String routeId) async {
    await _db.collection('users').doc(uid).update({'routeId': routeId});
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromMap(doc.data()!, uid);
    }
    return null;
  }

  Future<void> updateUserProfile(String uid, String name, String phone) async {
    await _db.collection('users').doc(uid).update({
      'name': name,
      'phone': phone,
    });
  }

  // ─── Routes ────────────────────────────────────────────────────────────────

  /// Returns all routes as a one-time future (used for route selection screen)
  Future<List<RouteModel>> getRoutes() async {
    final snapshot = await _db.collection('routes').get();
    return snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList()
      ..sort((a, b) => a.routeName.compareTo(b.routeName));
  }

  /// Seed 10 default Chennai routes if the collection is empty
  Future<void> seedDefaultRoutesIfEmpty() async {
    final snapshot = await _db.collection('routes').limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // already seeded

    final batch = _db.batch();
    for (final route in SeedService.defaultRoutes) {
      final ref = _db.collection('routes').doc(route.routeId);
      batch.set(ref, route.toMap());
    }
    await batch.commit();
  }

  // ─── Bus Location ──────────────────────────────────────────────────────────

  /// Read a single driver's bus location document once
  Future<BusLocation?> getBusLocationOnce(String driverId) async {
    final doc = await _db.collection('bus_location').doc(driverId).get();
    if (doc.exists && doc.data() != null) {
      return BusLocation.fromFirestore(doc);
    }
    return null;
  }

  /// Driver writes their live GPS position
  Future<void> updateBusLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    required String routeName,
    required String routeId,
    required double speed,
    required bool isOnline,
    int passengerCount = 0,
  }) async {
    await _db.collection('bus_location').doc(driverId).set({
      'latitude': latitude,
      'longitude': longitude,
      'isOnline': isOnline,
      'routeName': routeName,
      'routeId': routeId,
      'speed': speed,
      'passengerCount': passengerCount,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Student subscribes to a specific driver's location
  Stream<BusLocation?> getBusLocationStream(String driverId) {
    return _db
        .collection('bus_location')
        .doc(driverId)
        .snapshots()
        .map((snap) => snap.exists ? BusLocation.fromFirestore(snap) : null);
  }

  /// Returns all currently online buses (for admin / multi-bus view)
  Stream<List<BusLocation>> getActiveBusesStream() {
    return _db
        .collection('bus_location')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BusLocation.fromFirestore(d)).toList());
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  Future<void> sendRouteNotification({
    required String routeId,
    required String message,
    required String type, // delay | breakdown | info
  }) async {
    await _db.collection('notifications').add({
      'routeId': routeId,
      'message': message,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getNotificationsForRoute(String routeId) {
    return _db
        .collection('notifications')
        .where('routeId', isEqualTo: routeId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ─── Announcements ─────────────────────────────────────────────────────────

  /// Driver posts a new announcement for a route
  Future<void> postAnnouncement({
    required String routeId,
    required String message,
    required String postedBy,
  }) async {
    await _db.collection('announcements').add({
      'routeId': routeId,
      'message': message,
      'postedBy': postedBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of announcements for a route (newest first)
  Stream<List<Announcement>> announcementsStream(String routeId) {
    return _db
        .collection('announcements')
        .where('routeId', isEqualTo: routeId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => Announcement.fromFirestore(d)).toList();
      list.sort((a, b) => b.postedAt.compareTo(a.postedAt));
      return list;
    });
  }

  /// Driver deletes one of their own announcements
  Future<void> deleteAnnouncement(String announcementId) async {
    await _db.collection('announcements').doc(announcementId).delete();
  }

  // ─── Trip History ───────────────────────────────────────────────────────────

  /// Record a completed trip to /trips
  Future<void> recordCompletedTrip({
    required String routeId,
    required String routeName,
    required String driverId,
    required String driverName,
    required DateTime startTime,
    required DateTime endTime,
    required int stopsCompleted,
    required int totalStops,
  }) async {
    final durationMinutes = endTime.difference(startTime).inMinutes;
    await _db.collection('trips').add({
      'routeId': routeId,
      'routeName': routeName,
      'driverId': driverId,
      'driverName': driverName,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationMinutes': durationMinutes > 0 ? durationMinutes : 1,
      'stopsCompleted': stopsCompleted,
      'totalStops': totalStops,
      'status': 'COMPLETED',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of trip records for a route (newest first)
  Stream<List<TripRecord>> tripHistoryStream(String routeId) {
    return _db
        .collection('trips')
        .where('routeId', isEqualTo: routeId)
        .orderBy('startTime', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TripRecord.fromFirestore(d)).toList());
  }

  // ─── Emergency SOS ──────────────────────────────────────────────────────────

  /// Driver posts an emergency SOS alert
  Future<void> sendSosAlert({
    required String driverId,
    required String driverName,
    required String routeId,
    required String routeName,
    required double latitude,
    required double longitude,
    required String message,
  }) async {
    await _db.collection('sos_alerts').add({
      'driverId': driverId,
      'driverName': driverName,
      'routeId': routeId,
      'routeName': routeName,
      'latitude': latitude,
      'longitude': longitude,
      'message': message,
      'status': 'ACTIVE',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ─── Student Feedback & Issue Reporting ──────────────────────────────────────

  /// Submit student issue or feedback
  Future<void> submitStudentFeedback({
    required String uid,
    required String studentName,
    required String routeId,
    required String category, // 'delay', 'overcrowding', 'lost_item', 'driver_behavior', 'general'
    required String details,
  }) async {
    await _db.collection('feedback').add({
      'studentId': uid,
      'studentName': studentName,
      'routeId': routeId,
      'category': category,
      'details': details,
      'status': 'OPEN',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ─── Favorite Route Persistence ─────────────────────────────────────────────

  /// Save student's preferred/favorite route
  Future<void> saveFavoriteRoute(String uid, String routeId) async {
    await _db.collection('users').doc(uid).set({
      'favoriteRouteId': routeId,
    }, SetOptions(merge: true));
  }

  /// Retrieve favorite route ID for user
  Future<String?> getFavoriteRoute(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data()?['favoriteRouteId'] as String?;
    }
    return null;
  }
}