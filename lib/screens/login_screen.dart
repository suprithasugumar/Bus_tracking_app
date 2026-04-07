import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'route_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String _selectedRole = 'Student';
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
      _showSnack('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _isLogin
          ? await _authService.login(
              _email.text.trim(),
              _password.text.trim(),
            )
          : await _authService.register(
              _email.text.trim(),
              _password.text.trim(),
              _selectedRole,
            );

      if (user != null) {
        final role = await _firestoreService.getUserRole(user.uid);

        // For registration, role is just set – so redirect directly
        final effectiveRole = role ?? _selectedRole;

        if (_isLogin && role != null && role != _selectedRole) {
          _showSnack('Selected role does not match your account');
          setState(() => _isLoading = false);
          return;
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RouteSelectionScreen(
                role: effectiveRole,
                uid: user.uid,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showSnack('${_isLogin ? 'Login' : 'Registration'} failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                const Icon(Icons.directions_bus, size: 85, color: Colors.white),
                const SizedBox(height: 15),
                const Text(
                  'Smart Bus Tracking',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const Text(
                  'Chennai City Bus Tracker',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 40),
                _inputField(_email, 'Email', Icons.email),
                const SizedBox(height: 18),
                _inputField(_password, 'Password', Icons.lock,
                    isPassword: true),
                const SizedBox(height: 25),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Role',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _roleCard('Student', Icons.school)),
                    const SizedBox(width: 15),
                    Expanded(child: _roleCard('Driver', Icons.person)),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isLoading ? null : _handleAuth,
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF0D47A1)),
                          )
                        : Text(
                            _isLogin ? 'Login' : 'Register',
                            style: const TextStyle(
                              color: Color(0xFF0D47A1),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Register"
                        : 'Already have an account? Login',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      scribbleEnabled: false,
      enableIMEPersonalizedLearning: false,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon),
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _roleCard(String role, IconData icon) {
    final bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? const Color(0xFF0D47A1) : Colors.white),
            const SizedBox(height: 5),
            Text(
              role,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0D47A1) : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
