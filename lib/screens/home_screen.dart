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
  final Map<int, Widget> _loadedTabs = {};

  @override
  void initState() {
    super.initState();
    // Set this route as the active viewing route in background
    NotificationService.setCurrentViewingRoute(widget.routeModel.routeId);
  }

  @override
  void dispose() {
    // Revert viewing route back to default route
    NotificationService.setCurrentViewingRoute(null);
    super.dispose();
  }

  Widget _getTab(int index) {
    if (_loadedTabs.containsKey(index)) {
      return _loadedTabs[index]!;
    }
    Widget tab;
    switch (index) {
      case 0:
        tab = widget.role.toLowerCase() == 'driver'
            ? DriverDashboard(
                uid: widget.uid,
                routeModel: widget.routeModel,
              )
            : StudentTrackingScreen(
                routeModel: widget.routeModel,
              );
        break;
      case 1:
        tab = AnnouncementsScreen(
          routeId: widget.routeModel.routeId,
          routeName: widget.routeModel.routeName,
          role: widget.role,
          uid: widget.uid,
          displayName: widget.displayName,
        );
        break;
      case 2:
        tab = TripHistoryScreen(
          routeId: widget.routeModel.routeId,
          routeName: widget.routeModel.routeName,
        );
        break;
      case 3:
      default:
        tab = ProfileScreen(
          uid: widget.uid,
          role: widget.role,
          routeName: widget.routeModel.routeName,
        );
        break;
    }
    _loadedTabs[index] = tab;
    return tab;
  }

  @override
  Widget build(BuildContext context) {
    // Ensure current active tab is loaded
    _getTab(_selectedIndex);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          4,
          (i) => _loadedTabs[i] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF0D47A1),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11.5,
        unselectedFontSize: 10.5,
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
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
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