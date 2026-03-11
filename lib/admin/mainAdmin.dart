import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maintenance/admin/feedBack.dart';

class MainAdmin extends StatelessWidget {
  const MainAdmin({super.key});
  static const String screenroute = 'mainAdmin';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم الأدمن'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _adminButton(
              icon: Iconsax.message_question,
              title: 'الاقتراحات\nوالشكاوى',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedbacksPage()),
                );
              },
            ),

            _adminButton(
              icon: Iconsax.user,
              title: 'مسح السجلات المنتهية',
              onTap: () {
                deleteExpiredAttendance(context);
              },
            ),

            _adminButton(
              icon: Iconsax.setting,
              title: 'الإعدادات',
              onTap: () {},
            ),

            _adminButton(
              icon: Iconsax.logout,
              title: 'تسجيل الخروج',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.blue),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> deleteExpiredAttendance(BuildContext context) async {
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();

  final attendanceSnapshot = await firestore.collection('attendance').get();

  int deletedCount = 0;

  for (final groupDoc in attendanceSnapshot.docs) {
    final expiredRecords = await groupDoc.reference
        .collection('records')
        .where('expiredAt', isLessThan: Timestamp.now())
        .get();
    print('11111111111');
    for (final record in expiredRecords.docs) {
      batch.delete(record.reference);
      deletedCount++;
    }
  }

  if (deletedCount > 0) {
    await batch.commit();
  }
  await deleteGroupBatch();

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: Text('تم مسح $deletedCount سجل حضور منتهي بنجاح'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

Future<void> deleteGroupBatch() async {
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();
  await firestore
      .collection('groups')
      .where('willDeleteAt', isLessThan: Timestamp.fromDate(DateTime.now()))
      .get()
      .then((snapshot) async {
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
          final groupRef = firestore.collection('groups').doc(doc.id);
          batch.delete(groupRef);

          // ===== teams =====
          final teamRef = firestore.collection('teams').doc(doc.id);
          final teamsSnapshot = await teamRef.collection('members').get();

          for (final item in teamsSnapshot.docs) {
            batch.delete(item.reference);
          }

          batch.delete(teamRef);
          //====== users ======
          final usersRef = firestore.collection('faceEmbedding').doc(doc.id);
          final usersSnapshot = await usersRef.collection('users').get();

          for (final item in usersSnapshot.docs) {
            batch.delete(item.reference);
          }

          batch.delete(teamRef);

          // ===== tasks =====
          final tasksRef = firestore.collection('tasks').doc(doc.id);
          final taskItemsSnapshot = await tasksRef.collection('items').get();

          for (final item in taskItemsSnapshot.docs) {
            final worksSnapshot = await item.reference
                .collection('works')
                .get();

            for (final work in worksSnapshot.docs) {
              batch.delete(work.reference);
            }

            batch.delete(item.reference);
          }
          batch.delete(tasksRef);

          // ===== assets =====
          final assetsRef = firestore.collection('assets').doc(doc.id);
          final assetItemsSnapshot = await assetsRef.collection('items').get();

          for (final item in assetItemsSnapshot.docs) {
            final worksSnapshot = await item.reference
                .collection('works')
                .get();

            for (final work in worksSnapshot.docs) {
              batch.delete(work.reference);
            }

            batch.delete(item.reference);
          }
          batch.delete(assetsRef);
          /////////////warehouse///////////////
          final warehouseRef = firestore.collection('inventory').doc(doc.id);
          final warehouseItemsSnapshot = await warehouseRef
              .collection('items')
              .get();

          for (final item in warehouseItemsSnapshot.docs) {
            final worksSnapshot = await item.reference
                .collection('movements')
                .get();

            for (final work in worksSnapshot.docs) {
              batch.delete(work.reference);
            }

            batch.delete(item.reference);
          }
          batch.delete(warehouseRef);

          // ===== attendance =====
          final attendanceRef = firestore.collection('attendance').doc(doc.id);

          final recordsSnapshot = await attendanceRef
              .collection('records')
              .get();

          for (final record in recordsSnapshot.docs) {
            batch.delete(record.reference);
          }

          batch.delete(attendanceRef);

          // ===== COMMIT =====
          await batch.commit();
        }
      });

  // ===== groups =====
}
