import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FeedbacksPage extends StatelessWidget {
  const FeedbacksPage({super.key});
  static const String screenroute = 'feedbacks';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاقتراحات والشكاوى')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feedback')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد رسائل حتى الآن'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: Text(data['message'] ?? ''),
                  subtitle: Text(
                    data['email'] ?? 'مستخدم مجهول',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('feedback')
                          .doc(doc.id)
                          .delete();
                    },
                    icon: Icon(Icons.delete_outline_rounded),
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
