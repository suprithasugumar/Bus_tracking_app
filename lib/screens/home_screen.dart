import 'package:flutter/material.dart';
import '../models/route_model.dart';
import 'driver_dashboard.dart';
import 'student_tracking_screen.dart';
import 'profile_screen.dart';
import '../services/notification_service.dart';
class HomeScreen extends StatefulWidget {
  final String role;
  final String uid;
  final RouteModel routeModel;

  const HomeScreen({
    super.key,
    required this.role,
    required this.uid,
    required this.routeModel,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Subscribe to route FCM topic when user enters the screen
    NotificationService.subscribeToRoute(widget.routeModel.routeId);
  }

  @override
  void dispose() {
    // Unsubscribe when leaving
    NotificationService.unsubscribeFromRoute(widget.routeModel.routeId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      widget.role.toLowerCase() == 'driver'
          ? DriverDashboard(
              uid: widget.uid,
              routeModel: widget.routeModel,
            )
          : StudentTrackingScreen(
              routeModel: widget.routeModel,
            ),
      ProfileScreen(
        uid: widget.uid,
        role: widget.role,
        routeName: widget.routeModel.routeName,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF0D47A1),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 2) {
            Navigator.popUntil(context, (route) => route.isFirst);
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Tracking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Logout',
          ),
        ],
      ),
    );
  }
}