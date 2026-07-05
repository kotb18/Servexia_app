import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeDetailsPage extends StatefulWidget {
  final Map<String, dynamic> employeeData;
  final bool isConfirmed;
  final String groupId;
  final bool isAdmin;

  const EmployeeDetailsPage({
    Key? key,
    required this.employeeData,
    required this.isConfirmed,
    required this.groupId,
    required this.isAdmin,
  }) : super(key: key);

  @override
  State<EmployeeDetailsPage> createState() => _EmployeeDetailsPageState();
}

class _EmployeeDetailsPageState extends State<EmployeeDetailsPage> {
  bool isLoading = false;

  // Permissions state
  Map<String, bool> permissions = {
    'المخازن': false,
    'إضافة صنف مخزني': false,
    'الفواتير والمشتريات': false,
    'العملاء والموردين': false,
    'المتجر الإليكتروني': false,
    'الأصول والمعدات': false,
    'إضافة أصل أو معدة': false,
    'إضافة مهمة': false,
    'طلبات الانضمام': false,
  };

  @override
  void initState() {
    super.initState();
    _loadExistingPermissions();
  }

  Future<void> _loadExistingPermissions() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('employees_permissions')
          .doc(widget.groupId)
          .collection('items')
          .doc(widget.employeeData['id'])
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          permissions.forEach((key, value) {
            if (data.containsKey(key)) {
              permissions[key] = data[key] ?? false;
            }
          });
        });
      }
    } catch (e) {
      debugPrint('Error loading permissions: \$e');
    }
  }

  Future<void> _savePermissions() async {
    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('employees_permissions')
          .doc(widget.groupId)
          .set({'groupId': widget.groupId});
      await FirebaseFirestore.instance
          .collection('employees_permissions')
          .doc(widget.groupId)
          .collection('items')
          .doc(widget.employeeData['id'])
          .set({
            ...permissions,
            'employeeId': widget.employeeData['id'],
            'employeeName': widget.employeeData['name'],
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الصلاحيات بنجاح ✅'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: \$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'غير متوفر';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employeeData;
    final Timestamp? joinedAt = employee['joinedAt'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF1E3A5F),
          title: const Text(
            'بيانات الموظف',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          actions: [
            if (widget.isConfirmed)
              IconButton(
                icon: const Icon(Icons.save, color: Colors.white),
                tooltip: 'حفظ الصلاحيات',
                onPressed: isLoading ? null : _savePermissions,
              ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Info Card
                    _buildInfoCard(employee, joinedAt),

                    const SizedBox(height: 24),

                    // Permissions Section
                    if (widget.isConfirmed && widget.isAdmin) ...[
                      _buildSectionTitle('صلاحيات الوصول'),
                      const SizedBox(height: 12),
                      _buildPermissionsCard(),
                      const SizedBox(height: 24),
                      _buildSaveButton(),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> employee, Timestamp? joinedAt) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with photo
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E3A5F), const Color(0xFF2D5A87)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Photo
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    backgroundImage: employee['photoURL'] != null
                        ? NetworkImage(employee['photoURL'])
                        : null,
                    child: employee['photoURL'] == null
                        ? const Icon(
                            Icons.person,
                            size: 45,
                            color: Color(0xFF1E3A5F),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['name'] ?? 'غير معروف',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          employee['job'] ?? 'غير محدد',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.badge_outlined,
                  label: 'معرف الموظف',
                  value: employee['id'] ?? 'غير متوفر',
                  isCopyable: true,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.phone_outlined,
                  label: 'رقم الهاتف',
                  value: employee['phone'] ?? 'غير متوفر',
                  isCopyable: true,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'تاريخ الانضمام',
                  value: _formatDate(joinedAt),
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.verified_outlined,
                  label: 'حالة التأكيد',
                  value: widget.isConfirmed
                      ? 'تم التأكيد ✅'
                      : 'في انتظار التأكيد ⏳',
                  valueColor: widget.isConfirmed ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isCopyable = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: const Color(0xFF1E3A5F)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? const Color(0xFF1E3A5F),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (isCopyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
            onPressed: () {
              // Copy to clipboard logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم النسخ ✅'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: permissions.entries.map((entry) {
          final index = permissions.keys.toList().indexOf(entry.key);
          return Column(
            children: [
              if (index > 0)
                const Divider(height: 1, indent: 20, endIndent: 20),
              _buildPermissionTile(entry.key, entry.value),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPermissionTile(String title, bool value) {
    IconData icon;
    switch (title) {
      case 'المخازن':
        icon = Icons.warehouse_outlined;
        break;
      case 'إضافة صنف مخزني':
        icon = Icons.add_box_outlined;
        break;
      case 'الفواتير والمشتريات':
        icon = Icons.receipt_long_outlined;
        break;
      case 'العملاء والموردين':
        icon = Icons.people_outline;
        break;
      case 'المتجر الإليكتروني':
        icon = Icons.shopping_cart_outlined;
        break;
      case 'الأصول والمعدات':
        icon = Icons.account_balance_outlined;
        break;
      case 'إضافة أصل أو معدة':
        icon = Icons.add_business_outlined;
        break;
      case 'إضافة مهمة':
        icon = Icons.build_outlined;
        break;
      case 'طلبات الانضمام':
        icon = Icons.groups_outlined;
        break;
      default:
        icon = Icons.check_circle_outline;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF1E3A5F).withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: value ? const Color(0xFF1E3A5F) : Colors.grey[400],
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: value ? const Color(0xFF1E3A5F) : Colors.grey[600],
        ),
      ),
      subtitle: Text(
        value ? 'مسموح بالوصول' : 'غير مسموح',
        style: TextStyle(
          fontSize: 12,
          color: value ? Colors.green[600] : Colors.grey[400],
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: (newValue) {
          setState(() {
            permissions[title] = newValue;
          });
        },
        activeColor: const Color(0xFF1E3A5F),
        activeTrackColor: const Color(0xFF1E3A5F).withOpacity(0.3),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _savePermissions,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          isLoading ? 'جاري الحفظ...' : 'حفظ الصلاحيات',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFF1E3A5F).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  /*   Widget _buildUnconfirmedBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700], size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الموظف غير مؤكد',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'لا يمكن إضافة صلاحيات حتى يتم تأكيد حساب الموظف',
                  style: TextStyle(color: Colors.orange[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  } */
}

// ==================== USAGE EXAMPLE ====================
// Navigate to this page from your previous page like this:
/*
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EmployeeDetailsPage(
      employeeData: {
        'id': 'x1iDYFcfV5RCt2yOZkZBZIUoR0z1',
        'name': 'Ahmed Mohamed Kotb',
        'job': 'مدير المجموعة',
        'phone': '+201206401932',
        'photoURL': 'https://lh3.googleusercontent.com/a/ACg8ocIoesJAZfUb6r-I_eY2QDwV_DB_nH626RvmyL6lzC2FrQjcJ3U=',
        'joinedAt': Timestamp.fromDate(DateTime(2026, 4, 19, 0, 40, 57)),
      },
      isConfirmed: true,
    ),
  ),
);
*/

// ==================== FIRESTORE RULES (Optional) ====================
/*
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /employees_permissions/{employeeId} {
      allow read, write: if request.auth != null;
    }
  }
}
*/
