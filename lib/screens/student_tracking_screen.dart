import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_model.dart';
import '../models/bus_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
class StudentTrackingScreen extends StatefulWidget {
  final RouteModel routeModel;

  const StudentTrackingScreen({
    super.key,
    required this.routeModel,
  });

  @override
  State<StudentTrackingScreen> createState() => _StudentTrackingScreenState();
}

class _StudentTrackingScreenState extends State<StudentTrackingScreen>
    with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  GoogleMapController? _mapController;

  // Animation for smooth bus marker movement
  AnimationController? _animController;
  Animation<double>? _latAnim;
  Animation<double>? _lngAnim;

  LatLng _busPosition = const LatLng(13.0694, 80.1948); // default Koyambedu
  LatLng _prevBusPosition = const LatLng(13.0694, 80.1948);

  BusLocation? _busLocation;
  StreamSubscription<BusLocation?>? _busStream;

  bool _isDriverOnline = false;
  DateTime? _lastUpdated;
  bool _hasNotifiedTwoStops = false;
  @override
  void initState() {
    super.initState();
    _initAnimation();

    // Use the driver assigned to this route (if any)
    final driverId = widget.routeModel.assignedDriverId;
    if (driverId.isNotEmpty) {
      _subscribeToDriver(driverId);
    } else {
      // Fallback: listen to any bus on this route
      _subscribeToRouteAnyDriver();
    }
  }

  void _initAnimation() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  void _subscribeToDriver(String driverId) {
    _busStream =
        _firestoreService.getBusLocationStream(driverId).listen((bus) {
      _handleBusUpdate(bus);
    });
  }

  /// If no driver is assigned, watch the entire bus_location collection for
  /// any bus on this route that is online.
  void _subscribeToRouteAnyDriver() {
    FirebaseFirestore.instance
        .collection('bus_location')
        .where('routeId', isEqualTo: widget.routeModel.routeId)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isNotEmpty) {
        final bus = BusLocation.fromFirestore(snap.docs.first);
        _handleBusUpdate(bus);
      } else {
        if (mounted) setState(() => _isDriverOnline = false);
      }
    });
  }

  void _handleBusUpdate(BusLocation? bus) {
    if (bus == null || !mounted) return;
    final newPos = LatLng(bus.latitude, bus.longitude);

    // Animate from old position to new
    _animController?.reset();
    _latAnim = Tween<double>(
      begin: _prevBusPosition.latitude,
      end: newPos.latitude,
    ).animate(CurvedAnimation(
        parent: _animController!, curve: Curves.easeInOut));
    _lngAnim = Tween<double>(
      begin: _prevBusPosition.longitude,
      end: newPos.longitude,
    ).animate(CurvedAnimation(
        parent: _animController!, curve: Curves.easeInOut));

    _animController?.addListener(() {
      if (!mounted) return;
      setState(() {
        _busPosition = LatLng(
          _latAnim?.value ?? newPos.latitude,
          _lngAnim?.value ?? newPos.longitude,
        );
      });
    });

    _animController?.forward();

    // Pan camera to follow bus
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(newPos),
    );

    setState(() {
      _prevBusPosition = newPos;
      _busLocation = bus;
      _isDriverOnline = bus.isOnline;
      _lastUpdated = bus.timestamp;
    });

    _checkProximityAndNotify(newPos);
  }

  void _checkProximityAndNotify(LatLng busPos) {
    if (widget.routeModel.stopCoordinates.isEmpty) return;

    int closestIndex = 0;
    double minDist = double.infinity;
    for (int i = 0; i < widget.routeModel.stopCoordinates.length; i++) {
      final d = _haversineKm(busPos, widget.routeModel.stopCoordinates[i]);
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }

    final remainingStops = widget.routeModel.stops.length - closestIndex - 1;
    
    // Notify when 2 stops away
    if (remainingStops <= 2 && remainingStops >= 0 && !_hasNotifiedTwoStops) {
      _hasNotifiedTwoStops = true;
      NotificationService.show(
        title: 'Bus Approaching! 🚌',
        body: '${widget.routeModel.routeName} is $remainingStops stops away from the final destination.',
      );
    }
    
    // Reset if driver loops around (optional, we'll keep it simple for now)
  }

  @override
  void dispose() {
    _busStream?.cancel();
    _animController?.dispose();
    super.dispose();
  }

  int _calculateETA() {
    if (!_isDriverOnline || widget.routeModel.stopCoordinates.isEmpty) return 0;
    // Find which stop the bus is closest to
    int closestIndex = 0;
    double minDist = double.infinity;
    for (int i = 0; i < widget.routeModel.stopCoordinates.length; i++) {
      final d = _haversineKm(
          _busPosition, widget.routeModel.stopCoordinates[i]);
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }
    final remaining = widget.routeModel.stops.length - closestIndex - 1;
    return remaining <= 0 ? 0 : remaining * 4; // ~4 min per stop
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(a.latitude)) *
            math.cos(_deg2rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _deg2rad(double d) => d * math.pi / 180;

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }

  Set<Polyline> _buildPolylines() {
    if (widget.routeModel.stopCoordinates.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: widget.routeModel.stopCoordinates,
        color: const Color(0xFF0D47A1),
        width: 4,
        patterns: [],
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Bus marker
    if (_isDriverOnline) {
      markers.add(Marker(
        markerId: const MarkerId('bus'),
        position: _busPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: '🚌 Bus – ${widget.routeModel.routeName}',
          snippet:
              '${_busLocation?.speed.toStringAsFixed(1) ?? '0'} km/h',
        ),
        zIndex: 3,
      ));
    }

    // Stop markers
    for (int i = 0;
        i < widget.routeModel.stops.length &&
            i < widget.routeModel.stopCoordinates.length;
        i++) {
      markers.add(Marker(
        markerId: MarkerId('stop_$i'),
        position: widget.routeModel.stopCoordinates[i],
        icon: BitmapDescriptor.defaultMarkerWithHue(
            i == widget.routeModel.stops.length - 1
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.routeModel.stops[i]),
        zIndex: 1,
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = widget.routeModel.stopCoordinates.isNotEmpty
        ? widget.routeModel.stopCoordinates.first
        : const LatLng(13.0694, 80.1948);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Status Banner ──────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: _isDriverOnline
                ? const Color(0xFF1B5E20)
                : Colors.orange.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _isDriverOnline ? Icons.circle : Icons.circle_outlined,
                  size: 10,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isDriverOnline
                        ? 'Driver Online – ${widget.routeModel.routeName}'
                        : 'Waiting for driver to start trip…',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  _formatTimestamp(_lastUpdated),
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),

          // ── Map ────────────────────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: 13,
              ),
              onMapCreated: (c) => _mapController = c,
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),

          // ── Info Cards ─────────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        label: 'ETA',
                        value: '${_calculateETA()} min',
                        color: const Color(0xFF0D47A1),
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: Icons.speed,
                        label: 'Speed',
                        value:
                            '${_busLocation?.speed.toStringAsFixed(0) ?? '—'} km/h',
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: Icons.place_outlined,
                        label: 'Stops',
                        value: '${widget.routeModel.stops.length}',
                        color: Colors.orange.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Stops',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.routeModel.stops.length,
                      itemBuilder: (ctx, i) => _StopChip(
                        label: widget.routeModel.stops[i],
                        isLast: i == widget.routeModel.stops.length - 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '🌅 ${widget.routeModel.morningSchedule}  '
                        '🌙 ${widget.routeModel.eveningSchedule}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10, color: color, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _StopChip extends StatelessWidget {
  final String label;
  final bool isLast;

  const _StopChip({required this.label, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isLast
                ? Colors.green.withValues(alpha: 0.15)
                : const Color(0xFF0D47A1).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isLast
                    ? Colors.green.shade300
                    : const Color(0xFF0D47A1).withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: isLast ? Colors.green.shade700 : const Color(0xFF0D47A1),
                fontWeight: FontWeight.w500),
          ),
        ),
        if (!isLast)
          const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
      ],
    );
  }
}
