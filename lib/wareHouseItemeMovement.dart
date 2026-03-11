// item_details_refactored.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------------------
// 1. Data Model (لتمثيل بيانات الحركة بشكل نظيف)
// -----------------------------------------------------------------------------

class Movement {
  final String type; // 'in' or 'out'
  final int qty;
  final String unit;
  final String note;
  final String createdBy;
  final DateTime createdAt;

  Movement.fromMap(Map<String, dynamic> data)
    : type = data['type'] ?? 'out',
      qty = data['qty'] ?? 0,
      unit = data['unit'] ?? '',
      note = data['note'] ?? '',
      createdBy = data['createdBy'] ?? 'غير معروف',
      createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
}

// -----------------------------------------------------------------------------
// 2. Service Layer (طبقة الخدمات - لفصل منطق الوصول للبيانات)
// -----------------------------------------------------------------------------

class InventoryService {
  final String groupId;
  final String itemId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  InventoryService({required this.groupId, required this.itemId});

  DocumentReference get _itemRef => _firestore
      .collection('inventory')
      .doc(groupId)
      .collection('items')
      .doc(itemId);

  Stream<DocumentSnapshot<Map<String, dynamic>>> itemStream() {
    return _itemRef.snapshots()
        as Stream<DocumentSnapshot<Map<String, dynamic>>>;
  }

  Stream<QuerySnapshot> movementsStream() {
    return _itemRef
        .collection('movements')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> addMovement({
    required int qty,
    required String type,
    String? note,
    required String currentUser,
  }) async {
    final itemSnap = await _itemRef.get();
    final data = itemSnap.data() as Map<String, dynamic>;
    final currentQty = data['quantity'];

    final newQty = type == 'in' ? currentQty + qty : currentQty - qty;

    if (newQty < 0) {
      throw Exception('الكمية غير كافية في المخزون.');
    }

    // 1. تحديث الكمية الرئيسية
    await _itemRef.update({'quantity': newQty});

    // 2. إضافة سجل الحركة
    await _itemRef.collection('movements').add({
      'type': type,
      'qty': qty,
      'unit': data['unit'],
      'note': note ?? '',
      'createdBy': currentUser,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

// -----------------------------------------------------------------------------
// 3. UI Components (مكونات واجهة المستخدم النظيفة)
// -----------------------------------------------------------------------------

// 3.1. شاشة سجل الحركات (كشاشة منفصلة)
class MovementHistoryScreen extends StatelessWidget {
  final InventoryService service;

  const MovementHistoryScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الحركات')),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.movementsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('خطأ: ${snap.error}'));
          }
          if (snap.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد حركات مسجلة.'));
          }

          return ListView.builder(
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, index) {
              final movement = Movement.fromMap(
                snap.data!.docs[index].data() as Map<String, dynamic>,
              );
              final isIncoming = movement.type;
              final color = isIncoming == 'in'
                  ? Colors.green.shade700
                  : Colors.red.shade700;
              final icon = isIncoming == 'in'
                  ? Icons.arrow_downward
                  : Icons.arrow_upward;
              final formattedDate = DateFormat(
                'dd/MM/yyyy - HH:mm',
              ).format(movement.createdAt);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(
                    '${movement.qty} ${movement.unit}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('بواسطة: ${movement.createdBy}'),
                      if (movement.note.isNotEmpty)
                        Text('ملاحظة: ${movement.note}'),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    isIncoming == 'in'
                        ? 'إضافة'
                        : isIncoming == 'delete'
                        ? 'حذف'
                        : 'صرف',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
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

// 3.2. حوار الحركة (كـ StatelessWidget)
class MovementDialog extends StatelessWidget {
  final String type;
  final Function(int qty, String? note) onSave;

  const MovementDialog({super.key, required this.type, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    final isIncoming = type == 'in';

    return AlertDialog(
      title: Text(isIncoming ? 'إضافة كمية' : 'صرف كمية'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'الكمية',
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'ملاحظة (اختياري)',
              prefixIcon: Icon(Icons.note),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            final qty = int.tryParse(qtyController.text) ?? 0;
            if (qty <= 0) return;

            Navigator.pop(context);
            onSave(qty, noteController.text.trim());
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 4. Item Details Screen (الشاشة الرئيسية - أصبحت StatelessWidget)
// -----------------------------------------------------------------------------

class InventoryItemDetailsScreenRefactored extends StatefulWidget {
  final String groupId;
  final String itemId;
  final bool deletedItems;

  const InventoryItemDetailsScreenRefactored({
    super.key,
    required this.groupId,
    required this.itemId,
    required this.deletedItems,
  });
  static const String screenroute = 'inventoryItemDetailsScreenRefactored';

  @override
  State<InventoryItemDetailsScreenRefactored> createState() =>
      _InventoryItemDetailsScreenRefactoredState();
}

class _InventoryItemDetailsScreenRefactoredState
    extends State<InventoryItemDetailsScreenRefactored> {
  late final InventoryService _service;
  bool _loading = false;

  String get _currentUser =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'غير معروف';

  @override
  void initState() {
    super.initState();
    _service = InventoryService(groupId: widget.groupId, itemId: widget.itemId);
  }

  Future<void> _handleMovement(String type, int qty, String? note) async {
    setState(() => _loading = true);
    try {
      await _service.addMovement(
        qty: qty,
        type: type,
        note: note,
        currentUser: _currentUser,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت عملية ${type == 'in' ? 'الإضافة' : 'الصرف'} بنجاح',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openMovementDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => MovementDialog(
        type: type,
        onSave: (qty, note) => _handleMovement(type, qty, note),
      ),
    );
  }

  void _openMovementsHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MovementHistoryScreen(service: _service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.deletedItems
        ? MovementHistoryScreen(service: _service)
        : Scaffold(
            appBar: AppBar(
              title: const Text(
                'تفاصيل الصنف',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: _openMovementsHistory,
                  tooltip: 'سجل الحركات',
                ),
              ],
            ),
            body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _service.itemStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('خطأ في تحميل البيانات: ${snap.error}'),
                  );
                }
                if (!snap.hasData || !snap.data!.exists) {
                  return const Center(child: Text('الصنف غير موجود.'));
                }

                final item = snap.data!.data()!;
                final currentQuantity = item['quantity'] ?? 0;
                final unit = item['unit'] ?? 'وحدة';

                return Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 4.1. بطاقة تفاصيل الصنف (UI/UX Improvement)
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['name'] ?? 'صنف غير مسمى',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('تأكيد الحذف'),
                                            content: const Text(
                                              'هل أنت متأكد أنك تريد حذف هذا الصنف؟',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('إلغاء'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('inventory')
                                                      .doc(widget.groupId)
                                                      .collection('items')
                                                      .doc(widget.itemId)
                                                      .update({
                                                        'deleted': true,
                                                      });
                                                  Navigator.pop(context, true);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text('حذف'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await FirebaseFirestore.instance
                                                .collection('inventory')
                                                .doc(widget.groupId)
                                                .collection('items')
                                                .doc(widget.itemId)
                                                .update({'deleted': true});
                                            await FirebaseFirestore.instance
                                                .collection('inventory')
                                                .doc(widget.groupId)
                                                .collection('items')
                                                .doc(widget.itemId)
                                                .collection('movements')
                                                .add({
                                                  'type': 'delete',
                                                  'qty': currentQuantity,
                                                  'unit': unit,
                                                  'note': 'حذف الصنف بالكامل',
                                                  'createdBy': _currentUser,
                                                  'createdAt':
                                                      FieldValue.serverTimestamp(),
                                                });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'تم حذف الصنف بنجاح.',
                                                ),
                                              ),
                                            );
                                            Navigator.pop(context);
                                          } catch (e) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'خطأ في الحذف: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                _buildDetailRow(
                                  context,
                                  'الكمية الحالية',
                                  '$currentQuantity $unit',
                                  Icons.inventory_2_outlined,
                                  currentQuantity > 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                _buildDetailRow(
                                  context,
                                  'كود الصنف',
                                  item['sku'] ?? 'غير محدد',
                                  Icons.qr_code,
                                ),
                                _buildDetailRow(
                                  context,
                                  'الموقع',
                                  item['location'] ?? 'غير محدد',
                                  Icons.location_on_outlined,
                                ),
                                if (item['notes'] != null &&
                                    item['notes'].toString().isNotEmpty)
                                  _buildDetailRow(
                                    context,
                                    'ملاحظات',
                                    item['notes'],
                                    Icons.note_alt_outlined,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // 4.2. شريط الإجراءات (Actions Bar)
                        Text(
                          'إدارة حركة المخزون',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _openMovementDialog('in'),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('إضافة كمية'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _openMovementDialog('out'),
                                icon: const Icon(Icons.remove_circle_outline),
                                label: const Text('صرف كمية'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                );
              },
            ),
          );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String title,
    String value,
    IconData icon, [
    Color? valueColor,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              '$title:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
