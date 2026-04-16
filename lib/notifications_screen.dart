import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // ================= FORMAT DATE =================
  String formatSmartDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;

    final time =
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

    if (diff == 0) return "Today • $time";
    if (diff == 1) return "Yesterday • $time";

    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return "${days[dt.weekday - 1]} • ${dt.day}/${dt.month}/${dt.year} - $time";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login first")),
      );
    }

    final uid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No notifications yet"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,

            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>?;

              if (data == null) return const SizedBox();

              final title = (data['title'] ?? 'Notification').toString();
              final body = (data['body'] ?? '').toString();
              final isRead = data['read'] == true;

              final timestamp = data['createdAt'];
              final DateTime? dateTime =
              timestamp is Timestamp ? timestamp.toDate() : null;

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,

                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),

                onDismissed: (_) async {
                  await doc.reference.delete();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Notification deleted")),
                    );
                  }
                },

                child: InkWell(
                  onTap: () async {
                    await doc.reference.update({'read': true});
                  },

                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),

                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.white
                          : const Color(0xFFE8F0FF),

                      borderRadius: BorderRadius.circular(15),

                      border: Border.all(
                        color: isRead
                            ? Colors.grey.shade200
                            : Colors.blue,
                      ),
                    ),

                    child: Row(
                      children: [

                        // ================= ICON =================
                        CircleAvatar(
                          backgroundColor:
                          isRead ? Colors.grey : Colors.blue,
                          child: const Icon(
                            Icons.notifications,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(width: 12),

                        // ================= TEXT =================
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isRead
                                      ? Colors.black
                                      : Colors.blue,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(
                                body,
                                style: const TextStyle(fontSize: 13),
                              ),

                              const SizedBox(height: 6),

                              if (dateTime != null)
                                Text(
                                  formatSmartDate(dateTime),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // ================= DELETE BUTTON =================
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Delete notification"),
                                content: const Text(
                                    "Are you sure you want to delete this notification?"),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await doc.reference.delete();

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Deleted successfully")),
                              );
                            }
                          },
                        ),

                        if (!isRead)
                          const Icon(
                            Icons.circle,
                            color: Colors.blue,
                            size: 10,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}