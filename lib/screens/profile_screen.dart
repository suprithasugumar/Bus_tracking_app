import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
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
  bool _lowDataMode = false;
  bool _highContrastMap = false;
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
        _lowDataMode = profile?.lowDataMode ?? false;
        _highContrastMap = profile?.highContrastMap ?? false;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
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

                  // Transit & Route Information
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'College Transit Details',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Assigned Route with Empty State
                  _buildTransitTile(
                    label: 'Assigned Route',
                    value: (_profile?.assignedRouteName != null &&
                            _profile!.assignedRouteName!.isNotEmpty)
                        ? _profile!.assignedRouteName!
                        : (widget.routeName.isNotEmpty && widget.routeName != 'Not Assigned')
                            ? widget.routeName
                            : 'Route not assigned yet',
                    icon: Icons.alt_route,
                    isUnassigned: (_profile?.assignedRouteName == null ||
                            _profile!.assignedRouteName!.isEmpty) &&
                        (widget.routeName.isEmpty || widget.routeName == 'Not Assigned'),
                    emptySubtext:
                        'Please select your route in route selection or contact college transport administrator.',
                  ),
                  const SizedBox(height: 10),

                  // Bus Number
                  _buildTransitTile(
                    label: 'Bus Number',
                    value: (_profile?.assignedBusNumber != null &&
                            _profile!.assignedBusNumber!.isNotEmpty)
                        ? _profile!.assignedBusNumber!
                        : 'Bus # (To be allocated by admin)',
                    icon: Icons.directions_bus,
                    isUnassigned: _profile?.assignedBusNumber == null ||
                        _profile!.assignedBusNumber!.isEmpty,
                  ),
                  const SizedBox(height: 10),

                  // Selected Stop
                  _buildTransitTile(
                    label: 'Selected Boarding Stop',
                    value: (_profile?.selectedStopName != null &&
                            _profile!.selectedStopName!.isNotEmpty)
                        ? _profile!.selectedStopName!
                        : 'No stop chosen yet',
                    icon: Icons.pin_drop,
                    isUnassigned: _profile?.selectedStopName == null ||
                        _profile!.selectedStopName!.isEmpty,
                    emptySubtext:
                        'Open live tracking and pick your stop for proximity alerts.',
                  ),

                  const SizedBox(height: 20),


                  // ── Preferences & Performance ──
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'App Preferences',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          dense: true,
                          title: const Text('Low-Data Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          subtitle: const Text('Reduces map telemetry & polyline refresh rate to conserve data', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                          value: _lowDataMode,
                          activeThumbColor: const Color(0xFF0D47A1),
                          onChanged: (val) async {
                            setState(() => _lowDataMode = val);
                            await _firestoreService.updateUserPreferences(widget.uid, lowDataMode: val);
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(val ? '🟢 Low-Data mode enabled.' : 'Standard telemetry enabled.'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          dense: true,
                          title: const Text('High-Contrast Map', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          subtitle: const Text('Enhance visibility of stops, bus markers, and route paths', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                          value: _highContrastMap,
                          activeThumbColor: const Color(0xFF0D47A1),
                          onChanged: (val) async {
                            setState(() => _highContrastMap = val);
                            await _firestoreService.updateUserPreferences(widget.uid, highContrastMap: val);
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(val ? '🎨 High-Contrast map styling enabled.' : 'Standard map styling enabled.'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

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
                        final defaultRoute = _profile?.effectiveDefaultRouteId;
                        if (defaultRoute != null && defaultRoute.isNotEmpty) {
                          await NotificationService.setDefaultRoute(defaultRoute);
                        }
                        await NotificationService.setCurrentViewingRoute(null);
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
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Widget _buildTransitTile({
    required String label,
    required String value,
    required IconData icon,
    bool isUnassigned = false,
    String? emptySubtext,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnassigned ? const Color(0xFFFFFBEB) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnassigned ? const Color(0xFFFDE68A) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isUnassigned
                    ? const Color(0xFFD97706)
                    : const Color(0xFF0D47A1),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUnassigned
                      ? const Color(0xFFB45309)
                      : Colors.grey.shade700,
                ),
              ),
              if (isUnassigned) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isUnassigned
                  ? const Color(0xFF92400E)
                  : const Color(0xFF1E293B),
            ),
          ),
          if (isUnassigned && emptySubtext != null) ...[
            const SizedBox(height: 4),
            Text(
              emptySubtext,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.amber.shade900.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}