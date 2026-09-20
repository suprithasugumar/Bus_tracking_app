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
    await _db.collection('users').doc(uid).set({
      'name': name,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserPreferences(
    String uid, {
    bool? lowDataMode,
    bool? highContrastMap,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (lowDataMode != null) data['lowDataMode'] = lowDataMode;
    if (highContrastMap != null) data['highContrastMap'] = highContrastMap;
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  // ─── Routes ────────────────────────────────────────────────────────────────

  /// Returns all routes as a one-time future (used for route selection screen)
  Future<List<RouteModel>> getRoutes() async {
    final snapshot = await _db.collection('routes').get();
    final list = snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList();
    list.sort((a, b) {
      final numA = int.tryParse(a.routeId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      final numB = int.tryParse(b.routeId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      if (numA != numB) return numA.compareTo(numB);
      return a.routeName.compareTo(b.routeName);
    });
    return list;
  }

  /// Seed or update the 80 morning Chennai routes with accurate coordinates and VIT CHENNAI destination
  Future<void> seedDefaultRoutesIfEmpty({bool force = false}) async {
    try {
      final configDoc = await _db.collection('system_config').doc('routes_metadata').get();
      final currentVersion = configDoc.exists ? (configDoc.data()?['version'] as int? ?? 1) : 1;
      const targetVersion = 3;

      final existingSnapshot = await _db.collection('routes').limit(80).get();
      if (force || currentVersion < targetVersion || existingSnapshot.docs.length < SeedService.defaultRoutes.length) {
        final routes = SeedService.defaultRoutes;
        const chunkSize = 40;
        for (int i = 0; i < routes.length; i += chunkSize) {
          final end = (i + chunkSize < routes.length) ? i + chunkSize : routes.length;
          final batch = _db.batch();
          for (int j = i; j < end; j++) {
            final route = routes[j];
            final ref = _db.collection('routes').doc(route.routeId);
            batch.set(ref, route.toMap(), SetOptions(merge: true));
          }
          await batch.commit();
        }
        await _db.collection('system_config').doc('routes_metadata').set({
          'version': targetVersion,
          'totalRoutes': routes.length,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  // ─── Tracking System Configuration ────────────────────────────────────────

  /// Fetches system tracking thresholds (e.g. stopRadiusMeters, proximityAlertRadiusMeters)
  Future<Map<String, dynamic>> getTrackingConfig() async {
    try {
      final doc = await _db.collection('system_config').doc('tracking').get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
    } catch (_) {}
    return {
      'stopRadiusMeters': 50.0,
      'proximityAlertRadiusMeters': 500.0,
      'jitterAccuracyThresholdMeters': 50.0,
    };
  }

  // ─── FCM Token & Selected Stop Persistence ──────────────────────────────────

  Future<void> saveFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveUserSelectedStop({
    required String uid,
    required String routeId,
    required int stopIndex,
    required String stopName,
  }) async {
    await _db.collection('users').doc(uid).set({
      'routeId': routeId,
      'selectedStopIndex': stopIndex,
      'selectedStopName': stopName,
      'selectedStopId': 'stop_$stopIndex',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveUserAssignedRoute({
    required String uid,
    required String routeId,
    required String routeName,
    String busNumber = '',
  }) async {
    await _db.collection('users').doc(uid).set({
      'assignedRouteId': routeId,
      'assignedRouteName': routeName,
      'assignedBusNumber': busNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  /// Check if the driver currently has an active trip on any route
  Future<BusLocation?> getDriverActiveTrip(String driverId) async {
    final doc = await _db.collection('bus_location').doc(driverId).get();
    if (doc.exists && doc.data() != null) {
      final bus = BusLocation.fromFirestore(doc);
      if (bus.isOnline && bus.routeId.isNotEmpty) {
        return bus;
      }
    }
    return null;
  }

  /// Driver writes their live GPS position with heading, stop progress, and stopStatuses
  Future<void> updateBusLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    required String routeName,
    required String routeId,
    String? busId,
    required double speed,
    double heading = 0.0,
    required bool isOnline,
    bool isTracking = true,
    int currentStopIndex = 0,
    List<String> completedStops = const [],
    Map<String, dynamic> stopStatuses = const {},
    String? tripId,
    int passengerCount = 0,
  }) async {
    final data = <String, dynamic>{
      'driverId': driverId,
      'busId': (busId != null && busId.isNotEmpty) ? busId : routeId,
      'latitude': latitude,
      'longitude': longitude,
      'isOnline': isOnline,
      'isTracking': isTracking,
      'routeName': routeName,
      'routeId': routeId,
      'speed': speed,
      'heading': heading,
      'currentStopIndex': currentStopIndex,
      'completedStops': completedStops,
      'stopStatuses': stopStatuses,
      'passengerCount': passengerCount,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (tripId != null && tripId.isNotEmpty) {
      data['tripId'] = tripId;
    }
    await _db.collection('bus_location').doc(driverId).set(data, SetOptions(merge: true));
  }

  /// Mark driver as offline / end trip while preserving last known location and stop stats
  Future<void> endDriverTrip(
    String driverId, {
    double? latitude,
    double? longitude,
    int? currentStopIndex,
    List<String>? completedStops,
    Map<String, dynamic>? stopStatuses,
  }) async {
    final data = <String, dynamic>{
      'isOnline': false,
      'isTracking': false,
      'speed': 0,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (latitude != null && longitude != null) {
      data['latitude'] = latitude;
      data['longitude'] = longitude;
    }
    if (currentStopIndex != null) {
      data['currentStopIndex'] = currentStopIndex;
    }
    if (completedStops != null) {
      data['completedStops'] = completedStops;
    }
    if (stopStatuses != null) {
      data['stopStatuses'] = stopStatuses;
    }
    await _db.collection('bus_location').doc(driverId).set(
      data,
      SetOptions(merge: true),
    );
  }


  /// Student subscribes to a specific driver's location
  Stream<BusLocation?> getBusLocationStream(String driverId) {
    return _db
        .collection('bus_location')
        .doc(driverId)
        .snapshots()
        .map((snap) => snap.exists ? BusLocation.fromFirestore(snap) : null);
  }

  /// Student / screen subscribes to a specific route's bus location document
  /// (returns the bus document so student sees online live movement or offline last known location)
  Stream<BusLocation?> getRouteBusLocationStream(String routeId) {
    return _db
        .collection('bus_location')
        .where('routeId', isEqualTo: routeId)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      // Prefer currently online bus on this route if multiple exist
      final docs = snap.docs;
      final onlineDoc = docs.where((d) => (d.data()['isOnline'] as bool? ?? false)).firstOrNull;
      return BusLocation.fromFirestore(onlineDoc ?? docs.first);
    });
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

  /// Returns a map of routeId -> BusLocation for all currently online routes
  Stream<Map<String, BusLocation>> getActiveRoutesMapStream() {
    return _db
        .collection('bus_location')
        .snapshots()
        .map((snap) {
      final map = <String, BusLocation>{};
      for (final doc in snap.docs) {
        final bus = BusLocation.fromFirestore(doc);
        if (bus.routeId.isNotEmpty) {
          // If already mapped and this one is not online, keep the online one
          if (!map.containsKey(bus.routeId) || bus.isOnline) {
            map[bus.routeId] = bus;
          }
        }
      }
      return map;
    });
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  Future<void> sendRouteNotification({
    required String routeId,
    required String message,
    required String type, // delay | breakdown | info | approaching | arrival | completed
    String? stopName,
    int? stopIndex,
  }) async {
    final data = <String, dynamic>{
      'routeId': routeId,
      'message': message,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (stopName != null && stopName.isNotEmpty) {
      data['stopName'] = stopName;
    }
    if (stopIndex != null) {
      data['stopIndex'] = stopIndex;
    }
    await _db.collection('notifications').add(data);
  }

  Stream<List<Map<String, dynamic>>> getNotificationsForRoute(String routeId) {
    return _db
        .collection('notifications')
        .where('routeId', isEqualTo: routeId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final tA = a['timestamp'];
        final tB = b['timestamp'];
        if (tA is Timestamp && tB is Timestamp) {
          return tB.compareTo(tA);
        }
        return 0;
      });
      return list.take(30).toList();
    });
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

  /// Save student's preferred/favorite route (and sets as default route)
  Future<void> saveFavoriteRoute(String uid, String routeId) async {
    await _db.collection('users').doc(uid).set({
      'favoriteRouteId': routeId,
      'defaultRouteId': routeId,
      'updatedAt': FieldValue.serverTimestamp(),
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

  /// Records student accessing a route, tracks usage frequency,
  /// and automatically determines the student's most accessed route.
  Future<void> recordRouteAccess(String uid, String routeId, String routeName) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final data = userDoc.data() ?? {};
      final Map<String, dynamic> rawCounts = data['routeAccessCounts'] is Map
          ? Map<String, dynamic>.from(data['routeAccessCounts'] as Map)
          : {};

      final int currentCount = (rawCounts[routeId] as num?)?.toInt() ?? 0;
      rawCounts[routeId] = currentCount + 1;

      // Determine the most accessed route ID
      String mostAccessedId = routeId;
      int maxCount = currentCount + 1;
      rawCounts.forEach((k, v) {
        final c = (v as num).toInt();
        if (c > maxCount) {
          maxCount = c;
          mostAccessedId = k;
        }
      });

      final updateData = <String, dynamic>{
        'lastAccessedRouteId': routeId,
        'lastAccessedRouteName': routeName,
        'lastAccessedAt': FieldValue.serverTimestamp(),
        'routeAccessCounts': rawCounts,
        'mostAccessedRouteId': mostAccessedId,
      };

      // If user does not have an explicit default route, assign most accessed as default
      if (data['defaultRouteId'] == null && data['assignedRouteId'] == null) {
        updateData['defaultRouteId'] = mostAccessedId;
      }

      await _db.collection('users').doc(uid).set(updateData, SetOptions(merge: true));
    } catch (_) {}
  }
}