import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Register with role
  Future<User?> register(String email, String password, String role) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Save role in Firestore
      await _firestoreService.saveUserRole(userCredential.user!.uid, role);

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Login
  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
