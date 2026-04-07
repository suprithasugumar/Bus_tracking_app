import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

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
      if (mounted) {
        setState(() {
          _routes = routes;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        title: const Text(
          'Select Your Route',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
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

    return RefreshIndicator(
      onRefresh: _loadRoutes,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final route = _routes[index];
          return _RouteCard(
            route: route,
            onTap: () => _onRouteTapped(route),
          );
        },
      ),
    );
  }

  void _onRouteTapped(RouteModel route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          role: widget.role,
          uid: widget.uid,
          routeModel: route,
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final RouteModel route;
  final VoidCallback onTap;

  const _RouteCard({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
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
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_bus,
                        color: Color(0xFF0D47A1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      route.routeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  _ScheduleChip(
                    icon: Icons.wb_sunny_outlined,
                    time: route.morningSchedule,
                  ),
                  const SizedBox(width: 8),
                  _ScheduleChip(
                    icon: Icons.nights_stay_outlined,
                    time: route.eveningSchedule,
                  ),
                  const Spacer(),
                  Text(
                    '${route.stops.length} stops',
                    style: const TextStyle(
                      fontSize: 12,
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
}

class _ScheduleChip extends StatelessWidget {
  final IconData icon;
  final String time;

  const _ScheduleChip({required this.icon, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            time,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}