import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';

/// Shows the logged-in user's profile data from Firestore.
/// Allows editing of name and phone number.
class ProfileScreen extends StatefulWidget {
  final String uid;
  final String role;
  final String routeName;

  const ProfileScreen({
    super.key,
    required this.uid,
    required this.role,
    required this.routeName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _firestoreService.getUserProfile(widget.uid);
    if (mounted) {
      setState(() {
        _profile = profile;
        _nameCtrl.text = profile?.name ?? '';
        _phoneCtrl.text = profile?.phone ?? '';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUserProfile(
        widget.uid,
        _nameCtrl.text.trim(),
        _phoneCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        await _loadProfile(); // Refresh displayed data
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.role.toLowerCase() == 'student';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                      style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: isStudent
                        ? const Color(0xFF1565C0)
                        : Colors.green[700],
                    child: Icon(
                      isStudent ? Icons.school : Icons.directions_bus,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isStudent
                          ? const Color(0xFFE3F2FD)
                          : Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.role,
                      style: TextStyle(
                        color: isStudent
                            ? const Color(0xFF1565C0)
                            : Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name field
                  _buildField(
                    label: 'Full Name',
                    icon: Icons.person,
                    controller: _nameCtrl,
                    isEditing: _isEditing,
                  ),
                  const SizedBox(height: 14),

                  // Phone field
                  _buildField(
                    label: 'Phone Number',
                    icon: Icons.phone,
                    controller: _phoneCtrl,
                    isEditing: _isEditing,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  // Email (read-only always)
                  _buildReadOnlyTile(
                    label: 'Email',
                    value: _profile!.email,
                    icon: Icons.email,
                  ),
                  const SizedBox(height: 14),

                  // Route
                  _buildReadOnlyTile(
                    label: 'Assigned Route',
                    value: widget.routeName,
                    icon: Icons.route,
                  ),

                  const SizedBox(height: 32),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Logout',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await _authService.logout();
                        if (mounted && context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool isEditing,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        isEditing
            ? TextField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  prefixIcon: Icon(icon),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              )
            : _infoRow(icon, controller.text.isEmpty ? '—' : controller.text),
      ],
    );
  }

  Widget _buildReadOnlyTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        _infoRow(icon, value.isEmpty ? '—' : value),
      ],
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}