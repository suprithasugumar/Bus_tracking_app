import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_model.dart';
import '../services/firestore_service.dart';

class DriverDashboard extends StatefulWidget {
  final String uid;
  final RouteModel routeModel;

  const DriverDashboard({
    super.key,
    required this.uid,
    required this.routeModel,
  });

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isOnline = false;
  bool _isSendingLocation = false;
  int _currentStopIndex = 0;
  Timer? _locationTimer;
  Position? _lastPosition;

  @override
  void dispose() {
    _stopTrip();
    super.dispose();
  }

  // ─── Location Permissions ──────────────────────────────────────────────────

  Future<bool> _checkPermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      _showSnack(
          'Location permission permanently denied. Enable in device settings.');
      return false;
    }
    if (perm == LocationPermission.denied) return false;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Please enable location services on your device.');
      return false;
    }
    return true;
  }

  // ─── Trip Control ──────────────────────────────────────────────────────────

  Future<void> _startTrip() async {
    final ok = await _checkPermissions();
    if (!ok) return;

    setState(() {
      _isOnline = true;
      _currentStopIndex = 0;
      _isSendingLocation = true;
    });

    // Immediately send first position
    await _sendLocation();

    // Then every 5 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _sendLocation();
    });
  }

  void _stopTrip() {
    _locationTimer?.cancel();
    _locationTimer = null;

    if (_isOnline) {
      // Mark driver as offline in Firestore
      _firestoreService.updateBusLocation(
        driverId: widget.uid,
        latitude: _lastPosition?.latitude ?? 0,
        longitude: _lastPosition?.longitude ?? 0,
        routeName: widget.routeModel.routeName,
        routeId: widget.routeModel.routeId,
        speed: 0,
        isOnline: false,
      );
    }

    if (mounted) {
      setState(() {
        _isOnline = false;
        _isSendingLocation = false;
      });
    }
  }

  Future<void> _sendLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _lastPosition = position;

      await _firestoreService.updateBusLocation(
        driverId: widget.uid,
        latitude: position.latitude,
        longitude: position.longitude,
        routeName: widget.routeModel.routeName,
        routeId: widget.routeModel.routeId,
        speed: (position.speed * 3.6).clamp(0, 150), // m/s → km/h
        isOnline: true,
      );
    } catch (e) {
      // Silently queue when offline – Firestore will sync when reconnected
    }
  }

  // ─── Stop Marking ──────────────────────────────────────────────────────────

  void _markStopCompleted() {
    if (_currentStopIndex < widget.routeModel.stops.length - 1) {
      setState(() => _currentStopIndex++);
      _showSnack(
          '✅ Marked: ${widget.routeModel.stops[_currentStopIndex]}');
    } else {
      _stopTrip();
      _showSnack('🏁 Trip completed! All stops reached.');
    }
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  Future<void> _sendDelayAlert() async {
    await _firestoreService.sendRouteNotification(
      routeId: widget.routeModel.routeId,
      message:
          'Delay alert on ${widget.routeModel.routeName}. Bus running late.',
      type: 'delay',
    );
    _showSnack('⚠️ Delay alert sent to all students on this route');
  }

  Future<void> _sendBreakdownAlert() async {
    await _firestoreService.sendRouteNotification(
      routeId: widget.routeModel.routeId,
      message:
          'Breakdown reported on ${widget.routeModel.routeName}. Please use alternate transport.',
      type: 'breakdown',
    );
    _showSnack('🚨 Breakdown alert sent!');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        title: const Text('Driver Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Route Info ──────────────────────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route, color: Color(0xFF0D47A1)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.routeModel.routeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.routeModel.stops.join(' ➜ '),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🌅 ${widget.routeModel.morningSchedule}   '
                    '🌙 ${widget.routeModel.eveningSchedule}',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Trip Status ─────────────────────────────────────────────────
            _SectionCard(
              child: Column(
                children: [
                  Icon(
                    Icons.directions_bus,
                    size: 64,
                    color: _isOnline ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOnline ? 'Trip Active' : 'Trip Not Started',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isOnline ? Colors.green : Colors.red,
                    ),
                  ),
                  if (_isOnline) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Sharing location every 5 seconds',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (_lastPosition != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${_lastPosition!.latitude.toStringAsFixed(5)}, '
                        '${_lastPosition!.longitude.toStringAsFixed(5)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isOnline ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed:
                          _isSendingLocation ? null : (_isOnline ? _stopTrip : _startTrip),
                      icon: Icon(_isOnline ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isOnline ? 'Stop Trip' : 'Start Trip',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Stop Progress ───────────────────────────────────────────────
            if (_isOnline) ...[
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stop Progress',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(widget.routeModel.stops.length,
                        (i) {
                      final isDone = i < _currentStopIndex;
                      final isCurrent = i == _currentStopIndex;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isDone
                              ? Icons.check_circle
                              : isCurrent
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                          color: isDone
                              ? Colors.green
                              : isCurrent
                                  ? const Color(0xFF0D47A1)
                                  : Colors.grey,
                          size: 20,
                        ),
                        title: Text(
                          widget.routeModel.stops[i],
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isDone ? Colors.grey : null,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _markStopCompleted,
                        icon: const Icon(Icons.check),
                        label: Text(
                          _currentStopIndex <
                                  widget.routeModel.stops.length - 1
                              ? 'Mark Current Stop as Reached'
                              : 'Finish Trip',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D47A1),
                          side: const BorderSide(
                              color: Color(0xFF0D47A1)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Alerts ──────────────────────────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Send Alert to Students',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AlertButton(
                          label: 'Delay Alert',
                          icon: Icons.access_time,
                          color: Colors.orange,
                          onTap: _sendDelayAlert,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AlertButton(
                          label: 'Breakdown Alert',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.red,
                          onTap: _sendBreakdownAlert,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }
}

class _AlertButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AlertButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}