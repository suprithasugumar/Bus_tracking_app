import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bus_model.dart';
import '../services/firestore_service.dart';

/// Shows a history of all trips on the selected route.
class TripHistoryScreen extends StatelessWidget {
  final String routeId;
  final String routeName;

  const TripHistoryScreen({
    super.key,
    required this.routeId,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<TripRecord>>(
        stream: firestoreService.tripHistoryStream(routeId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final trips = snap.data ?? [];
          if (trips.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No trips recorded yet',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Completed trips will appear here',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: trips.length,
            itemBuilder: (context, i) {
              final trip = trips[i];
              final dateStr =
                  DateFormat('EEE, d MMM yyyy').format(trip.startTime);
              final startStr =
                  DateFormat('h:mm a').format(trip.startTime);
              final endStr = trip.endTime != null
                  ? DateFormat('h:mm a').format(trip.endTime!)
                  : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            trip.isCompleted
                                ? Icons.check_circle
                                : Icons.access_time,
                            color: trip.isCompleted
                                ? Colors.green
                                : Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: trip.isCompleted
                                  ? Colors.green[50]
                                  : Colors.orange[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              trip.isCompleted ? 'Completed' : 'Ongoing',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: trip.isCompleted
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(trip.driverName,
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _timeChip(Icons.play_arrow, 'Start', startStr,
                              Colors.green),
                          const SizedBox(width: 10),
                          if (endStr != null)
                            _timeChip(Icons.stop, 'End', endStr, Colors.red),
                          const Spacer(),
                          Text(
                            trip.durationText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _timeChip(
      IconData icon, String label, String time, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          '$label $time',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }
}
