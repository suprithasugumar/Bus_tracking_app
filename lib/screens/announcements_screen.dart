import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bus_model.dart';
import '../services/firestore_service.dart';

/// Displays announcements for a route.
/// Drivers can post new announcements; students can only read.
class AnnouncementsScreen extends StatefulWidget {
  final String routeId;
  final String routeName;
  final String role;
  final String uid;
  final String displayName;

  const AnnouncementsScreen({
    super.key,
    required this.routeId,
    required this.routeName,
    required this.role,
    required this.uid,
    required this.displayName,
  });

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _msgCtrl = TextEditingController();
  bool _isDriver = false;

  @override
  void initState() {
    super.initState();
    _isDriver = widget.role.toLowerCase() == 'driver';
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _postAnnouncement() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) return;

    await _firestoreService.postAnnouncement(
      routeId: widget.routeId,
      message: msg,
      postedBy: widget.displayName,
    );

    _msgCtrl.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement posted'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Driver-only compose area
          if (_isDriver)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText:
                            'Post an announcement to ${widget.routeName}…',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: _postAnnouncement,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),

          // Announcements list
          Expanded(
            child: StreamBuilder<List<Announcement>>(
              stream: _firestoreService
                  .announcementsStream(widget.routeId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No announcements yet',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final timeStr = DateFormat('d MMM · h:mm a')
                        .format(item.postedAt);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.campaign,
                                    size: 18, color: Color(0xFF1565C0)),
                                const SizedBox(width: 6),
                                Text(
                                  item.postedBy,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1565C0),
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                                // Driver can delete their own announcements
                                if (_isDriver)
                                  GestureDetector(
                                    onTap: () => _firestoreService
                                        .deleteAnnouncement(item.id),
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(Icons.delete_outline,
                                          size: 18, color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.message,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
