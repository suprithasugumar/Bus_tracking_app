class UserProfile {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String? routeId;

  UserProfile({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.routeId,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      routeId: data['routeId'],
    );
  }
}
