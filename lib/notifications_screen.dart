import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
      ),

      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("No notifications yet"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {

              final data = docs[i];
              final bool isRead = data['read'] ?? false;

              return GestureDetector(
                onTap: () async {
                  await docs[i].reference.update({'read': true});
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

                      CircleAvatar(
                        backgroundColor:
                        isRead ? Colors.grey : Colors.blue,
                        child: const Icon(
                          Icons.notifications,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isRead ? Colors.black : Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              data['body'] ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                      // 🔥 زر حذف
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await docs[i].reference.delete();
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
              );
            },
          );
        },
      ),
    );
  }
}