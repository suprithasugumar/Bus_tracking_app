import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';
import '../models/bus_model.dart';
import '../models/user_profile.dart';
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

  /// Driver writes their live GPS position
  Future<void> updateBusLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    required String routeName,
    required String routeId,
    required double speed,
    required bool isOnline,
  }) async {
    await _db.collection('bus_location').doc(driverId).set({
      'latitude': latitude,
      'longitude': longitude,
      'isOnline': isOnline,
      'routeName': routeName,
      'routeId': routeId,
      'speed': speed,
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
}