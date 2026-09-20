import 'dart:async';
import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/firestore_service.dart';
import '../services/tracking_service.dart';
import '../utils/stop_utils.dart';

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
  final TrackingService _trackingService = TrackingService.instance;

  bool _isActionInProgress = false;
  String? _otherActiveRouteName;
  String? _otherActiveRouteId;

  @override
  void initState() {
    super.initState();
    _checkOtherActiveRoute();
    _trackingService.restoreIfActive(
      driverId: widget.uid,
      route: widget.routeModel,
    );
  }

  Future<void> _checkOtherActiveRoute() async {
    try {
      final busLoc = await _firestoreService.getBusLocationOnce(widget.uid);
      if (busLoc != null && busLoc.isOnline && mounted) {
        if (busLoc.routeId != widget.routeModel.routeId) {
          setState(() {
            _otherActiveRouteName = busLoc.routeName.isNotEmpty
                ? busLoc.routeName
                : busLoc.routeId;
            _otherActiveRouteId = busLoc.routeId;
          });
        }
      }
    } catch (_) {}
  }

  // ─── Trip Control ──────────────────────────────────────────────────────────

  Future<void> _startTrip() async {
    if (_isActionInProgress) return;

    // Check if driver has an ongoing trip on another route
    if (_otherActiveRouteId != null &&
        _otherActiveRouteId != widget.routeModel.routeId) {
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

    setState(() => _isActionInProgress = true);

    final success = await _trackingService.startTrip(
      driverId: widget.uid,
      route: widget.routeModel,
    );

    if (mounted) {
      setState(() {
        _isActionInProgress = false;
        _otherActiveRouteName = null;
        _otherActiveRouteId = null;
      });

      if (success) {
        _showSnack('🟢 Live Trip Started for ${widget.routeModel.routeName}! GPS Auto-ticking Active.');
      } else {
        _showSnack('⚠️ Location permission is required to start live tracking.');
      }
    }
  }

  Future<void> _stopTrip() async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);

    await _trackingService.endTrip();

    if (mounted) {
      setState(() {
        _isActionInProgress = false;
        _otherActiveRouteName = null;
        _otherActiveRouteId = null;
      });
      _showSnack('🏁 Trip Ended & Saved to Trip History.');
    }
  }

  Future<bool> _handleBackPress() async {
    if (!_trackingService.isTracking) return true;

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
          'Your trip is currently active and broadcasting real-time GPS in the background.\n\nWhat would you like to do?',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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

  // ─── Manual Stop Ticking ───────────────────────────────────────────────────

  Future<void> _toggleStop(int index) async {
    if (!_trackingService.isTracking) {
      _showSnack('💡 Please tap "Start Trip" first to begin tracking and ticking stops.');
      return;
    }
    final stopName = widget.routeModel.stops[index];
    final isDone = _trackingService.completedStops.contains(stopName);
    await _trackingService.toggleStopAtIndex(index);
    if (!isDone) {
      _showSnack('✅ Marked "$stopName" as Reached');
    } else {
      _showSnack('↩️ Unmarked "$stopName"');
    }
  }

  Future<void> _markNextStopManually() async {
    final nextIndex = StopUtils.getNextStopIndex(
      stops: widget.routeModel.stops,
      completedStops: _trackingService.completedStops,
      fallbackCurrentIndex: _trackingService.currentStopIndex,
      isOnline: _trackingService.isTracking,
    );
    if (nextIndex != -1 && nextIndex < widget.routeModel.stops.length - 1) {
      final stopName = widget.routeModel.stops[nextIndex];
      await _trackingService.markCurrentStopManually();
      _showSnack('✅ Marked stop reached: $stopName');
    } else {
      await _stopTrip();
      _showSnack('🏁 Trip completed! Final stop reached.');
    }
  }

  // ─── Incident Broadcasts ───────────────────────────────────────────────────

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
            child: const Text('TRANSMIT SOS',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final lat = _trackingService.lastPosition?.latitude ?? 13.0827;
      final lng = _trackingService.lastPosition?.longitude ?? 80.2707;
      await _firestoreService.sendSosAlert(
        driverId: widget.uid,
        driverName: 'Driver',
        routeId: widget.routeModel.routeId,
        routeName: widget.routeModel.routeName,
        latitude: lat,
        longitude: lng,
        message:
            'EMERGENCY: Immediate assistance requested on ${widget.routeModel.routeName}',
      );
      _showSnack('🚨 SOS Broadcast Sent to Central Command!');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _formatTripStartTime(String timeStr) {
    if (timeStr.isEmpty) return '6:45 AM';
    final clean = timeStr.trim().toUpperCase().replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = clean.contains(':') ? clean.split(':') : clean.split('.');
    if (parts.isEmpty) return timeStr;
    final hour = int.tryParse(parts[0].trim()) ?? 6;
    final min = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    final minStr = min.toString().padLeft(2, '0');
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:$minStr $period';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _trackingService.isTrackingNotifier,
        _trackingService.currentStopIndexNotifier,
        _trackingService.completedStopsNotifier,
        _trackingService.lastPositionNotifier,
      ]),
      builder: (context, _) {
        final isOnline = _trackingService.isTracking &&
            _trackingService.activeRoute?.routeId == widget.routeModel.routeId;
        final currentStopIndex = _trackingService.currentStopIndex;
        final completedStops = _trackingService.completedStops;
        final lastPos = _trackingService.lastPosition;

        final nextStopIndex = StopUtils.getNextStopIndex(
          stops: widget.routeModel.stops,
          completedStops: completedStops,
          fallbackCurrentIndex: currentStopIndex,
          isOnline: isOnline,
        );
        final hasNextStop = nextStopIndex >= 0 && nextStopIndex < widget.routeModel.stops.length;
        final nextStopName = hasNextStop ? widget.routeModel.stops[nextStopIndex] : 'VIT CHENNAI (Arrived)';
        final completedCount = completedStops.length;
        final totalStops = widget.routeModel.stops.length;
        final progressFraction = totalStops > 0 ? (completedCount / totalStops).clamp(0.0, 1.0) : 0.0;

        return PopScope(
          canPop: !isOnline,
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
                  // ── Active Route Conflict Warning ──────────────────────────
                  if (_otherActiveRouteId != null && !isOnline)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.amber.shade400, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.amber.shade800, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Active Route Conflict',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You are currently broadcasting on "$_otherActiveRouteName". '
                            'Tap Start Trip below to switch your live route to "${widget.routeModel.routeName}".',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Route Header Card ──────────────────────────────────────
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D47A1)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.directions_bus,
                                  color: Color(0xFF0D47A1), size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.routeModel.routeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$totalStops stops • Destination: VIT CHENNAI',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isOnline ? Colors.green : Colors.grey.shade400),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isOnline ? Icons.sensors : Icons.sensors_off,
                                    size: 13,
                                    color: isOnline ? Colors.green : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOnline ? 'LIVE' : 'OFFLINE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isOnline ? Colors.green : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 15, color: Color(0xFF0D47A1)),
                            const SizedBox(width: 6),
                            Text(
                              'Trip starts by ${_formatTripStartTime(widget.routeModel.morningSchedule)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Trip Control & Broadcast Status Card ───────────────────
                  _SectionCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isOnline
                                      ? '🟢 Broadcasting Live GPS'
                                      : '⚪ Trip Not Started',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: isOnline ? Colors.green.shade800 : Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOnline
                                      ? 'Background tracking active'
                                      : 'Tap Start Trip when ready to drive',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            if (isOnline && lastPos != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${(lastPos.speed * 3.6).toStringAsFixed(1)} km/h',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D47A1),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isOnline ? const Color(0xFFDC2626) : const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isActionInProgress
                                ? null
                                : (isOnline ? _stopTrip : _startTrip),
                            icon: Icon(
                                isOnline ? Icons.stop_circle_outlined : Icons.play_circle_filled,
                                size: 24),
                            label: Text(
                              isOnline ? 'End Trip (Finish Route)' : 'Start Live Trip',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Stops Checklist Card ───────────────────────────────────
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress Counter
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Route Stops Checklist',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$completedCount / $totalStops Ticked',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progressFraction,
                            minHeight: 7,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Helper Instruction Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: Color(0xFF16A34A)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Stops tick automatically when bus reaches the location (80m GPS geofence). You can also tap to tick manually.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Next Target Stop Banner (when online)
                        if (isOnline && hasNextStop)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE0F2FE), Color(0xFFF0FDF4)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0284C7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.navigation, size: 18, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'CURRENT TARGET STOP',
                                        style: TextStyle(
                                          color: Color(0xFF0369A1),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${nextStopIndex + 1}. $nextStopName',
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _toggleStop(nextStopIndex),
                                  child: const Text('Tick ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),

                        // List of Stops with Automatic / Manual Ticking
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.routeModel.stops.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          itemBuilder: (context, index) {
                            final stopName = widget.routeModel.stops[index];
                            final isDone = completedStops.contains(stopName);
                            final isNext = (index == nextStopIndex) && !isDone;
                            final isLast = index == widget.routeModel.stops.length - 1;

                            return InkWell(
                              onTap: () => _toggleStop(index),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? const Color(0xFFF0FDF4)
                                      : (isNext ? const Color(0xFFE0F2FE).withValues(alpha: 0.4) : Colors.transparent),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    // Stop Index Badge
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? const Color(0xFF16A34A)
                                            : (isNext
                                                ? const Color(0xFF0284C7)
                                                : (isLast ? const Color(0xFFDC2626) : const Color(0xFF64748B))),
                                        shape: BoxShape.circle,
                                      ),
                                      child: isDone
                                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                                          : Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Stop Name
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stopName,
                                            style: TextStyle(
                                              fontWeight: isNext || isDone ? FontWeight.bold : FontWeight.w500,
                                              fontSize: 13.5,
                                              color: isDone
                                                  ? Colors.grey.shade700
                                                  : (isNext ? const Color(0xFF0369A1) : const Color(0xFF1E293B)),
                                              decoration: isDone ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          if (isLast)
                                            const Text(
                                              'Final College Destination',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFDC2626),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Ticking Status & Checkbox
                                    if (isDone)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF86EFAC)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Reached',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF15803D),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (isNext)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF38BDF8)),
                                        ),
                                        child: const Text(
                                          'Next Stop ➔',
                                          style: TextStyle(
                                            color: Color(0xFF0284C7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.check_box_outline_blank,
                                        size: 20,
                                        color: Color(0xFF94A3B8),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        if (isOnline) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _markNextStopManually,
                              icon: const Icon(Icons.check),
                              label: Text(
                                hasNextStop && nextStopIndex < widget.routeModel.stops.length - 1
                                    ? 'Mark Next Stop Reached ($nextStopName)'
                                    : 'Finish Trip at VIT CHENNAI',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0D47A1),
                                side: const BorderSide(color: Color(0xFF0D47A1)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Alerts & Incident Dispatch ──────────────────────────────
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

                  // ── Emergency SOS Command ───────────────────────────────────
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
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap in case of medical emergency, accident, or security incident to transmit high-priority alert to Dispatch.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _triggerEmergencySos,
                            icon: const Icon(Icons.emergency, size: 22),
                            label: const Text(
                              'TRANSMIT EMERGENCY SOS',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.5),
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
      },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}