import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../models/bus_model.dart';
import '../services/firestore_service.dart';
import '../services/tracking_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RouteSelectionScreen extends StatefulWidget {
  final String role;
  final String uid;

  const RouteSelectionScreen({
    super.key,
    required this.role,
    required this.uid,
  });

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<RouteModel> _routes = [];
  String? _favoriteRouteId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      // Seed routes on first run (no-op if already seeded)
      await _firestoreService.seedDefaultRoutesIfEmpty();
      final routes = await _firestoreService.getRoutes();
      final profile = await _firestoreService.getUserProfile(widget.uid);
      final favId = profile?.favoriteRouteId ?? await _firestoreService.getFavoriteRoute(widget.uid);
      final defaultRoute = profile?.effectiveDefaultRouteId ?? favId;

      await NotificationService.setDefaultRoute(defaultRoute);
      await NotificationService.setCurrentViewingRoute(null);

      if (mounted) {
        setState(() {
          _routes = routes;
          _favoriteRouteId = favId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load routes: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(String routeId) async {
    final newFav = _favoriteRouteId == routeId ? '' : routeId;
    setState(() => _favoriteRouteId = newFav.isEmpty ? null : newFav);
    await _firestoreService.saveFavoriteRoute(widget.uid, newFav);
    await NotificationService.setDefaultRoute(newFav.isNotEmpty ? newFav : null);
    await NotificationService.setCurrentViewingRoute(null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newFav.isNotEmpty ? '⭐ Saved as Default Route!' : 'Removed from Default Routes'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToLogin() {
    if (TrackingService.instance.isTracking) {
      final activeRouteName = TrackingService.instance.activeRoute?.routeName ?? 'your route';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📍 Live tracking for $activeRouteName continues in background until reaching VIT Chennai College.',
          ),
          backgroundColor: const Color(0xFF0D47A1),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateToLogin();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FC),
        appBar: AppBar(
          title: Text(
            widget.role.toLowerCase() == 'driver' ? 'Select Route to Drive' : 'Select Your Route',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Login',
            onPressed: _navigateToLogin,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout / Switch Account',
              onPressed: _navigateToLogin,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0D47A1)),
            SizedBox(height: 16),
            Text(
              'Loading routes…',
              style: TextStyle(color: Color(0xFF0D47A1)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadRoutes();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_routes.isEmpty) {
      return const Center(child: Text('No routes found.'));
    }

    return StreamBuilder<Map<String, BusLocation>>(
      stream: _firestoreService.getActiveRoutesMapStream(),
      builder: (context, snapshot) {
        final activeRoutesMap = snapshot.data ?? {};

        // Find if this driver is actively driving any route
        RouteModel? myActiveRoute;
        if (widget.role.toLowerCase() == 'driver') {
          for (final route in _routes) {
            final activeBus = activeRoutesMap[route.routeId];
            if (activeBus != null && activeBus.isOnline && activeBus.driverId == widget.uid) {
              myActiveRoute = route;
              break;
            }
          }
        }

        return RefreshIndicator(
          onRefresh: _loadRoutes,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: _routes.length + (myActiveRoute != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (myActiveRoute != null && index == 0) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.shade400, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR ACTIVE TRIP IN PROGRESS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              myActiveRoute.routeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _navigateToRoute(myActiveRoute!),
                        child: const Text('Resume Trip'),
                      ),
                    ],
                  ),
                );
              }

              final routeIndex = myActiveRoute != null ? index - 1 : index;
              final route = _routes[routeIndex];
              final isFav = route.routeId == _favoriteRouteId;
              final activeBus = activeRoutesMap[route.routeId];
              final isOnline = activeBus != null && activeBus.isOnline;
              final isMyTrip = isOnline && activeBus.driverId == widget.uid && widget.role.toLowerCase() == 'driver';

              return _RouteCard(
                route: route,
                isFavorite: isFav,
                isOnline: isOnline,
                isMyTrip: isMyTrip,
                onFavoriteToggle: () => _toggleFavorite(route.routeId),
                onTap: () => _onRouteTapped(route, myActiveRoute),
              );
            },
          ),
        );
      },
    );
  }

  void _onRouteTapped(RouteModel route, RouteModel? myActiveRoute) {
    if (widget.role.toLowerCase() == 'driver' && myActiveRoute != null && myActiveRoute.routeId != route.routeId) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
              SizedBox(width: 8),
              Text('Trip in Progress'),
            ],
          ),
          content: Text(
            'You are currently broadcasting live GPS on "${myActiveRoute.routeName}".\n\nWould you like to resume your active trip, or open "${route.routeName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToRoute(route);
              },
              child: Text('Open ${route.routeId.toUpperCase()}'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToRoute(myActiveRoute);
              },
              child: const Text('Resume Active Trip'),
            ),
          ],
        ),
      );
    } else {
      _navigateToRoute(route);
    }
  }

  Future<void> _navigateToRoute(RouteModel route) async {
    if (widget.role.toLowerCase() == 'student') {
      _firestoreService.recordRouteAccess(widget.uid, route.routeId, route.routeName);
    }
    // Set viewing route asynchronously in background without blocking screen transition
    NotificationService.setCurrentViewingRoute(route.routeId);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          role: widget.role,
          uid: widget.uid,
          routeModel: route,
        ),
      ),
    );

    // Revert to student's default route when exiting back to Route Selection
    NotificationService.setCurrentViewingRoute(null);
  }
}

class _RouteCard extends StatelessWidget {
  final RouteModel route;
  final bool isFavorite;
  final bool isOnline;
  final bool isMyTrip;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;

  const _RouteCard({
    required this.route,
    required this.isFavorite,
    required this.isOnline,
    required this.isMyTrip,
    required this.onFavoriteToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isMyTrip
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      elevation: isMyTrip ? 4 : 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Colors.green.withValues(alpha: 0.15)
                          : const Color(0xFF0D47A1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      color: isOnline ? Colors.green.shade800 : const Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.routeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (isMyTrip)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '🟢 YOUR ACTIVE TRIP',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              )
                            else if (isOnline)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: const Text(
                                  '🟢 LIVE TRIP',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⚪ OFFLINE',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                ),
                              ),
                            if (isFavorite)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '⭐ DEFAULT ROUTE',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.brown),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? Colors.amber.shade700 : Colors.grey.shade400,
                    ),
                    onPressed: onFavoriteToggle,
                    tooltip: isFavorite ? 'Remove Default' : 'Set as Default Route',
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                route.stops.join(' ➜ '),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 14, color: Color(0xFF0D47A1)),
                        const SizedBox(width: 5),
                        Text(
                          'Trip starts by ${_formatStartTime(route.morningSchedule)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${route.stops.length} stops',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatStartTime(String timeStr) {
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
}