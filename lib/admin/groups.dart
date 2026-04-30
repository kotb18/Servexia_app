import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GroupsMintor extends StatefulWidget {
  const GroupsMintor({super.key});
  static const String screenroute = 'groupsMintor';

  @override
  State<GroupsMintor> createState() => _GroupsMintorState();
}

class _GroupsMintorState extends State<GroupsMintor> {
  // ألوان التصميم
  final Color primaryColor = const Color(0xFF1A237E); // أزرق داكن احترافي
  final Color accentColor = const Color(0xFF3949AB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // خلفية فاتحة جداً لإبراز البطاقات
      appBar: AppBar(
        title: const Text(
          'متابعة المجموعات',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // أيقونة لعرض العدد الإجمالي في الهيدر
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('groups').snapshots(),
            builder: (context, snapshot) {
              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count مجموعة',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final groups = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final groupData = groups[index].data() as Map<String, dynamic>;
              return _buildGroupCard(
                groupData['name'] ?? 'بدون اسم',
                groupData['adminName'] ?? 'بدون مسؤول',
                groups[index].id,
              );
            },
          );
        },
      ),
    );
  }

  // تصميم بطاقة المجموعة
  Widget _buildGroupCard(String name, String admin, String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Icon(Icons.group_work_rounded, color: primaryColor),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Cairo',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'المسؤول: $admin',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            Text(id, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: () {
          // انتقل لتفاصيل المجموعة هنا
        },
      ),
    );
  }

  // واجهة تظهر عند عدم وجود بيانات
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد مجموعات حالياً',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 18,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
