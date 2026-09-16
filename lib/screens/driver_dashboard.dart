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
  DateTime? _tripStartTime;
  Timer? _locationTimer;
  Position? _lastPosition;
  String? _otherActiveRouteName;
  String? _otherActiveRouteId;

  @override
  void initState() {
    super.initState();
    _restoreTripState();
  }

  Future<void> _restoreTripState() async {
    try {
      final busLoc = await _firestoreService.getBusLocationOnce(widget.uid);
      if (busLoc != null && busLoc.isOnline && mounted) {
        if (busLoc.routeId == widget.routeModel.routeId) {
          setState(() {
            _isOnline = true;
            _otherActiveRouteName = null;
            _otherActiveRouteId = null;
            _tripStartTime = busLoc.timestamp ?? DateTime.now();
            _lastPosition = Position(
              latitude: busLoc.latitude,
              longitude: busLoc.longitude,
              timestamp: busLoc.timestamp ?? DateTime.now(),
              accuracy: 4.0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: busLoc.speed / 3.6,
              speedAccuracy: 0,
            );
          });
          _startLocationTimer();
        } else {
          // Driver is active on a different route
          setState(() {
            _isOnline = false;
            _otherActiveRouteName = busLoc.routeName.isNotEmpty ? busLoc.routeName : busLoc.routeId;
            _otherActiveRouteId = busLoc.routeId;
          });
        }
      } else if (mounted) {
        setState(() {
          _isOnline = false;
          _otherActiveRouteName = null;
          _otherActiveRouteId = null;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _locationTimer = null;
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

    // If driver already has another route running, end it first
    if (_otherActiveRouteId != null && _otherActiveRouteId != widget.routeModel.routeId) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.swap_horiz, color: Color(0xFF0D47A1)),
              SizedBox(width: 8),
              Text('Switch Active Route?'),
            ],
          ),
          content: Text(
            'You have an ongoing trip on "$_otherActiveRouteName". Starting this route will end that previous trip and start broadcasting "${widget.routeModel.routeName}".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Switch & Start'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await _firestoreService.endDriverTrip(widget.uid);
    }

    setState(() {
      _isOnline = true;
      _otherActiveRouteName = null;
      _otherActiveRouteId = null;
      _tripStartTime = DateTime.now();
      _currentStopIndex = 0;
      _isSendingLocation = true;
    });

    // Immediately send first position strictly for this route
    await _sendLocation();

    _startLocationTimer();

    if (mounted) {
      setState(() {
        _isSendingLocation = false;
      });
      _showSnack('🟢 Trip Started for ${widget.routeModel.routeName}!');
    }
  }

  void _startLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _sendLocation();
    });
  }

  Future<void> _stopTrip() async {
    _locationTimer?.cancel();
    _locationTimer = null;

    if (_isOnline) {
      final endTime = DateTime.now();
      final startTime = _tripStartTime ?? endTime.subtract(const Duration(minutes: 15));

      // 1. Mark driver as offline in Firestore
      await _firestoreService.updateBusLocation(
        driverId: widget.uid,
        latitude: _lastPosition?.latitude ?? 0,
        longitude: _lastPosition?.longitude ?? 0,
        routeName: widget.routeModel.routeName,
        routeId: widget.routeModel.routeId,
        speed: 0,
        passengerCount: 0,
        isOnline: false,
      );

      // 2. Persist completed trip to /trips collection
      try {
        await _firestoreService.recordCompletedTrip(
          routeId: widget.routeModel.routeId,
          routeName: widget.routeModel.routeName,
          driverId: widget.uid,
          driverName: 'Driver',
          startTime: startTime,
          endTime: endTime,
          stopsCompleted: _currentStopIndex + 1,
          totalStops: widget.routeModel.stops.length,
        );
      } catch (e) {
        debugPrint('[TripHistory] Error saving trip record: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isOnline = false;
        _isSendingLocation = false;
        _otherActiveRouteName = null;
        _otherActiveRouteId = null;
      });
      _showSnack('🏁 Trip Ended & Saved to Trip History.');
    }
  }

  Future<void> _endOtherTripAndStartHere() async {
    if (_otherActiveRouteId != null) {
      await _firestoreService.endDriverTrip(widget.uid);
      setState(() {
        _otherActiveRouteName = null;
        _otherActiveRouteId = null;
      });
      await _startTrip();
    }
  }

  Future<bool> _handleBackPress() async {
    if (!_isOnline) return true;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.directions_bus, color: Colors.green),
            SizedBox(width: 8),
            Text('Trip in Progress'),
          ],
        ),
        content: const Text(
          'Your trip is currently active and broadcasting real-time GPS.\n\nWhat would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: const Text('Stay in Dashboard'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'background'),
            child: const Text('Keep Live in Background'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, 'stop'),
            child: const Text('End Trip & Leave'),
          ),
        ],
      ),
    );

    if (action == 'stop') {
      await _stopTrip();
      return true;
    } else if (action == 'background') {
      return true;
    }
    return false;
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
        passengerCount: 0,
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

  // ─── Notifications & Alerts ────────────────────────────────────────────────

  Future<void> _sendDelayAlert() async {
    await _firestoreService.sendRouteNotification(
      routeId: widget.routeModel.routeId,
      message:
          'Delay alert on ${widget.routeModel.routeName}. Bus running ~15 mins late.',
      type: 'delay',
    );
    _showSnack('⚠️ Delay alert sent to all students on this route');
  }

  Future<void> _sendTrafficAlert() async {
    await _firestoreService.sendRouteNotification(
      routeId: widget.routeModel.routeId,
      message:
          'Heavy traffic congestion encountered along ${widget.routeModel.routeName}.',
      type: 'traffic',
    );
    _showSnack('🚦 Traffic delay broadcasted to route subscribers.');
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

  Future<void> _triggerEmergencySos() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Trigger Emergency SOS?'),
          ],
        ),
        content: const Text(
          'This will instantly alert Fleet Control & Emergency Dispatch with your exact GPS location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('TRANSMIT SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final lat = _lastPosition?.latitude ?? 13.0827;
      final lng = _lastPosition?.longitude ?? 80.2707;
      await _firestoreService.sendSosAlert(
        driverId: widget.uid,
        driverName: 'Driver',
        routeId: widget.routeModel.routeId,
        routeName: widget.routeModel.routeName,
        latitude: lat,
        longitude: lng,
        message: 'EMERGENCY: Immediate assistance requested on ${widget.routeModel.routeName}',
      );
      _showSnack('🚨 SOS Broadcast Sent to Central Command!');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isOnline,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canLeave = await _handleBackPress();
        if (canLeave && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FC),
        appBar: AppBar(
          title: const Text('Driver Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canLeave = await _handleBackPress();
              if (canLeave && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Active Route Conflict Warning ──────────────────────────────
              if (_otherActiveRouteId != null && !_isOnline)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade400, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Active Trip on Another Route',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You currently have a live trip in progress on "$_otherActiveRouteName". To broadcast this route, end that trip first.',
                        style: TextStyle(fontSize: 13, color: Colors.brown.shade800),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _endOtherTripAndStartHere,
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('End Other Trip & Start This Route'),
                        ),
                      ),
                    ],
                  ),
                ),

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
                        'Sharing location for ${widget.routeModel.routeName}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
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

            // ── Alerts & Incident Dispatch ──────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Broadcast Incident to Students',
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AlertButton(
                          label: 'Traffic Jam',
                          icon: Icons.traffic,
                          color: Colors.amber.shade800,
                          onTap: _sendTrafficAlert,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AlertButton(
                          label: 'Breakdown',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                          onTap: _sendBreakdownAlert,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Emergency SOS Command ───────────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, color: Colors.red, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Emergency Protocol',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap in case of medical emergency, accident, or security incident to transmit high-priority alert to Dispatch.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _triggerEmergencySos,
                      icon: const Icon(Icons.emergency, size: 22),
                      label: const Text(
                        'TRANSMIT EMERGENCY SOS',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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