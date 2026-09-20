import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Screen displaying in-app notification history for students and drivers,
/// ordered by time descending from Firestore `/notifications` collection.
class NotificationHistoryScreen extends StatefulWidget {
  final String? routeId;
  final String? routeName;

  const NotificationHistoryScreen({
    super.key,
    this.routeId,
    this.routeName,
  });

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  String _selectedFilter = 'All'; // 'All' | 'Delays' | 'Breakdowns' | 'General'

  @override
  Widget build(BuildContext context) {
    Stream<QuerySnapshot> stream;
    if (widget.routeId != null && widget.routeId!.isNotEmpty) {
      stream = FirebaseFirestore.instance
          .collection('notifications')
          .where('routeId', isEqualTo: widget.routeId)
          .snapshots();
    } else {
      stream = FirebaseFirestore.instance
          .collection('notifications')
          .snapshots();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (widget.routeName != null)
              Text(
                widget.routeName!,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', Icons.all_inbox),
                  const SizedBox(width: 8),
                  _filterChip('Approaching', Icons.directions_bus_rounded),
                  const SizedBox(width: 8),
                  _filterChip('Arrivals', Icons.pin_drop_rounded),
                  const SizedBox(width: 8),
                  _filterChip('Delays', Icons.warning_amber_rounded),
                  const SizedBox(width: 8),
                  _filterChip('Breakdowns', Icons.car_crash_outlined),
                  const SizedBox(width: 8),
                  _filterChip('General', Icons.info_outline),
                ],
              ),
            ),
          ),

          // Notification List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No recent notifications found for this route',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final rawDocs = snapshot.data?.docs ?? [];
                // Sort in-memory by timestamp descending
                final docs = List<DocumentSnapshot>.from(rawDocs);
                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>? ?? {};
                  final dataB = b.data() as Map<String, dynamic>? ?? {};
                  final tA = dataA['timestamp'];
                  final tB = dataB['timestamp'];
                  if (tA is Timestamp && tB is Timestamp) {
                    return tB.compareTo(tA);
                  }
                  return 0;
                });

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final routeId = data['routeId'] as String?;
                  if (widget.routeId != null && widget.routeId!.isNotEmpty) {
                    if (routeId != null && routeId != widget.routeId) return false;
                  }
                  final type = (data['type'] as String? ?? 'info').toLowerCase();
                  if (_selectedFilter == 'Approaching') return type == 'approaching';
                  if (_selectedFilter == 'Arrivals') return type == 'arrival';
                  if (_selectedFilter == 'Delays') return type == 'delay';
                  if (_selectedFilter == 'Breakdowns') return type == 'breakdown';
                  if (_selectedFilter == 'General') {
                    return type != 'delay' && type != 'breakdown' && type != 'approaching' && type != 'arrival';
                  }
                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Broadcasts, delay alerts, and arrival notifications for this route will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    return _NotificationCard(data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isSelected ? Colors.white : const Color(0xFF0D47A1),
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selectedColor: const Color(0xFF0D47A1),
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : Colors.grey.shade800,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = label);
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _NotificationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = (data['type'] as String? ?? 'info').toLowerCase();
    final message = data['message'] as String? ?? 'No details provided';
    final timestamp = data['timestamp'];
    DateTime? dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    }

    Color bannerColor;
    IconData icon;
    String badgeTitle;

    if (type == 'breakdown') {
      bannerColor = Colors.red.shade700;
      icon = Icons.car_crash_rounded;
      badgeTitle = 'Breakdown Alert';
    } else if (type == 'delay') {
      bannerColor = Colors.amber.shade800;
      icon = Icons.warning_amber_rounded;
      badgeTitle = 'Delay Notice';
    } else if (type == 'approaching') {
      bannerColor = const Color(0xFF0288D1);
      icon = Icons.directions_bus_rounded;
      badgeTitle = 'Approaching (~5m)';
    } else if (type == 'arrival') {
      bannerColor = const Color(0xFF00897B);
      icon = Icons.pin_drop_rounded;
      badgeTitle = 'Arrived at Stop';
    } else if (type == 'completed') {
      bannerColor = Colors.green.shade700;
      icon = Icons.check_circle_outline_rounded;
      badgeTitle = 'Trip Completed';
    } else {
      bannerColor = const Color(0xFF0D47A1);
      icon = Icons.info_rounded;
      badgeTitle = 'Route Alert';
    }

    final formattedTime = dateTime != null
        ? DateFormat('hh:mm a • dd MMM yyyy').format(dateTime)
        : 'Just now';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: bannerColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bannerColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeTitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: bannerColor,
                          ),
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF1E293B),
                      height: 1.35,
                    ),
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
