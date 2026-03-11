import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminApprovalPage extends StatefulWidget {
  final String groupId;

  const AdminApprovalPage({super.key, required this.groupId});
  static const String screenroute = 'adminApproval';

  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات الانضمام')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teams')
            .doc(widget.groupId)
            .collection('members')
            .where('confirm', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد طلبات حالياً'));
          }

          final pendingMembers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: pendingMembers.length,
            itemBuilder: (context, index) {
              final member = pendingMembers[index];

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: ClipOval(
                      child:
                          member['photoURL'] != null &&
                              member['photoURL'].isNotEmpty
                          ? Image.network(member['photoURL'], fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                    ),
                  ),
                  title: Text(member['name'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الوظيفة: ${member['job'] ?? ''}'),
                      Text('الهاتف: ${member['phone'] ?? ''}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => approveMemberWithBatch(
                          groupId: widget.groupId,
                          memberId: member['id'],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () =>
                            _rejectMember(widget.groupId, member['id']),
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

Future<void> approveMemberWithBatch({
  required String groupId,
  required String memberId,
}) async {
  final firestore = FirebaseFirestore.instance;

  firestore.collection('teams').doc(groupId);
  final groupRef = firestore.collection('groups').doc(groupId);

  // 1️⃣ قراءة بيانات الفريق
  FirebaseFirestore.instance
      .collection('teams')
      .doc(groupId)
      .collection('members')
      .doc(memberId)
      .update({'confirm': true});

  // 3️⃣ Batch update
  final batch = firestore.batch();

  // تحديث قائمة الأعضاء

  // إضافة العضو للجروب
  batch.update(groupRef, {
    'members': FieldValue.arrayUnion([memberId]),
  });

  await batch.commit();
}

Future<void> _rejectMember(String groupId, String uid) async {
  FirebaseFirestore.instance
      .collection('teams')
      .doc(groupId)
      .collection('members')
      .doc(uid)
      .delete();
}
