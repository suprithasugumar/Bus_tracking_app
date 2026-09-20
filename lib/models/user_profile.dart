class UserProfile {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String? routeId;
  final String? assignedRouteId;
  final String? assignedRouteName;
  final String? assignedBusNumber;
  final String? selectedStopId;
  final String? selectedStopName;
  final int? selectedStopIndex;
  final String? fcmToken;
  final bool lowDataMode;
  final bool highContrastMap;
  final String? defaultRouteId;
  final String? mostAccessedRouteId;
  final String? favoriteRouteId;
  final Map<String, int> routeAccessCounts;

  UserProfile({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.routeId,
    this.assignedRouteId,
    this.assignedRouteName,
    this.assignedBusNumber,
    this.selectedStopId,
    this.selectedStopName,
    this.selectedStopIndex,
    this.fcmToken,
    this.lowDataMode = false,
    this.highContrastMap = false,
    this.defaultRouteId,
    this.mostAccessedRouteId,
    this.favoriteRouteId,
    this.routeAccessCounts = const {},
  });

  /// Computes the student's primary/default route for receiving background push alerts
  /// (Prioritizes official college-assigned route, then explicitly chosen default/favorite, then most accessed route).
  String? get effectiveDefaultRouteId {
    if (assignedRouteId != null &&
        assignedRouteId!.isNotEmpty &&
        assignedRouteId != 'Not Assigned') {
      return assignedRouteId;
    }
    if (defaultRouteId != null && defaultRouteId!.isNotEmpty) {
      return defaultRouteId;
    }
    if (favoriteRouteId != null && favoriteRouteId!.isNotEmpty) {
      return favoriteRouteId;
    }
    if (mostAccessedRouteId != null && mostAccessedRouteId!.isNotEmpty) {
      return mostAccessedRouteId;
    }
    if (routeId != null && routeId!.isNotEmpty && routeId != 'Not Assigned') {
      return routeId;
    }
    return null;
  }

  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    final Map<String, int> counts = {};
    if (data['routeAccessCounts'] is Map) {
      (data['routeAccessCounts'] as Map).forEach((k, v) {
        if (v is num) counts[k.toString()] = v.toInt();
      });
    }

    return UserProfile(
      uid: uid,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      routeId: data['routeId'] ?? data['assignedRouteId'],
      assignedRouteId: data['assignedRouteId'] ?? data['routeId'],
      assignedRouteName: data['assignedRouteName'] ?? data['routeName'],
      assignedBusNumber: data['assignedBusNumber'] ?? data['busNumber'],
      selectedStopId: data['selectedStopId'],
      selectedStopName: data['selectedStopName'],
      selectedStopIndex: (data['selectedStopIndex'] as num?)?.toInt(),
      fcmToken: data['fcmToken'],
      lowDataMode: data['lowDataMode'] as bool? ?? false,
      highContrastMap: data['highContrastMap'] as bool? ?? false,
      defaultRouteId: data['defaultRouteId'] ?? data['favoriteRouteId'] ?? data['assignedRouteId'],
      mostAccessedRouteId: data['mostAccessedRouteId'],
      favoriteRouteId: data['favoriteRouteId'] ?? data['defaultRouteId'],
      routeAccessCounts: counts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'routeId': routeId,
      'assignedRouteId': assignedRouteId,
      'assignedRouteName': assignedRouteName,
      'assignedBusNumber': assignedBusNumber,
      'selectedStopId': selectedStopId,
      'selectedStopName': selectedStopName,
      'selectedStopIndex': selectedStopIndex,
      'fcmToken': fcmToken,
      'lowDataMode': lowDataMode,
      'highContrastMap': highContrastMap,
      'defaultRouteId': defaultRouteId,
      'mostAccessedRouteId': mostAccessedRouteId,
      'favoriteRouteId': favoriteRouteId,
      'routeAccessCounts': routeAccessCounts,
    };
  }
}

