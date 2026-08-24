import 'package:flutter/material.dart';
import '../models/route_model.dart';
import 'driver_dashboard.dart';
import 'student_tracking_screen.dart';
import 'profile_screen.dart';
import 'announcements_screen.dart';
import 'trip_history_screen.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  final String role;
  final String uid;
  final RouteModel routeModel;
  final String displayName;

  const HomeScreen({
    super.key,
    required this.role,
    required this.uid,
    required this.routeModel,
    this.displayName = 'Driver',
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
      // Tab 0 – Main tracking / dashboard
      widget.role.toLowerCase() == 'driver'
          ? DriverDashboard(
              uid: widget.uid,
              routeModel: widget.routeModel,
            )
          : StudentTrackingScreen(
              routeModel: widget.routeModel,
            ),

      // Tab 1 – Announcements
      AnnouncementsScreen(
        routeId: widget.routeModel.routeId,
        routeName: widget.routeModel.routeName,
        role: widget.role,
        uid: widget.uid,
        displayName: widget.displayName,
      ),

      // Tab 2 – Trip History
      TripHistoryScreen(
        routeId: widget.routeModel.routeId,
        routeName: widget.routeModel.routeName,
      ),

      // Tab 3 – Profile
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
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 4) {
            // Logout
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
            icon: Icon(Icons.campaign_outlined),
            label: 'Announcements',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Trip History',
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