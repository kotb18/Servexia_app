import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:maintenance/myInvoices.dart';
import 'package:maintenance/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// -----------------------------------------------------------------------------
// 1. Data Model (لتمثيل بيانات الحركة بشكل نظيف)
// -----------------------------------------------------------------------------

class Movement {
  final String type; // 'in' or 'out'
  final double qty;
  final String unit;
  final String note;
  final String createdBy;
  final DateTime createdAt;
  final String invoiceId;

  Movement.fromMap(Map<String, dynamic> data)
    : type = data['type'] ?? 'out',
      qty = data['qty'] ?? 0,
      unit = data['unit'] ?? '',
      note = data['note'] ?? '',
      createdBy = data['createdBy'] ?? 'غير معروف',
      createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      invoiceId = data['invoiceId'] ?? '';
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

  Query movementsQuery({String? typeFilter}) {
    Query query = _itemRef
        .collection('movements')
        .orderBy('createdAt', descending: true);

    if (typeFilter != null) {
      query = query.where('type', isEqualTo: typeFilter);
    }

    return query;
  }

  Future<void> addMovement({
    required double qty,
    required String type,
    String? note,
    required String currentUser,
  }) async {
    final itemSnap = await _itemRef.get();
    final data = itemSnap.data() as Map<String, dynamic>;
    final currentQty = data['quantity'];

    final double newQty = type == 'in' ? currentQty + qty : currentQty - qty;

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
class MovementHistoryScreen extends StatefulWidget {
  final InventoryService service;

  const MovementHistoryScreen({super.key, required this.service});

  @override
  State<MovementHistoryScreen> createState() => _MovementHistoryScreenState();
}

String? _selectedType;

class _MovementHistoryScreenState extends State<MovementHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 1. إظهار مؤشر تحميل (Loading)
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );

          try {
            // 2. جلب بيانات الصنف الحالية (للهيدر الخاص بالتقرير)
            final itemDoc = await FirebaseFirestore.instance
                .collection('inventory')
                .doc(widget.service.groupId)
                .collection('items')
                .doc(widget.service.itemId)
                .get();

            if (!itemDoc.exists) {
              throw Exception('الصنف غير موجود');
            }

            final itemData = itemDoc.data() as Map<String, dynamic>;

            // 3. جلب جميع الحركات من الـ Sub-collection (بدون تكرار)
            final movementsSnap = await FirebaseFirestore.instance
                .collection('inventory')
                .doc(widget.service.groupId)
                .collection('items')
                .doc(widget.service.itemId)
                .collection('movements')
                .orderBy('createdAt', descending: true)
                .get();

            final List<Map<String, dynamic>> movementsList = movementsSnap.docs
                .map((doc) => doc.data())
                .toList();

            // 4. إغلاق مؤشر التحميل
            Navigator.pop(context);

            if (movementsList.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد حركات مسجلة لتصديرها')),
              );
              return;
            }

            // 5. استدعاء دالة توليد الـ PDF التي صممناها سابقاً
            await generateItemMovementPdf(
              itemData: itemData,
              movementsList: movementsList,
            );
          } catch (e) {
            // إغلاق مؤشر التحميل في حالة الخطأ
            if (Navigator.canPop(context)) Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('حدث خطأ أثناء إعداد التقرير: $e')),
            );
          }
        },
        label: const Text('تقرير PDF'),
        icon: const Icon(Icons.picture_as_pdf),
        // backgroundColor: Colors.blue.shade800,
      ),
      appBar: AppBar(title: const Text('سجل الحركات')),
      body: FirestorePagination(
        key: ValueKey(_selectedType ?? 'all'),
        query: widget.service.movementsQuery(typeFilter: _selectedType),

        limit: 2, // ✅ دفعة مناسبة للسجلات الزمنية

        viewType: ViewType.list,
        isLive: true, // ✅ التحديثات الفورية (إضافة/حذف حركة)

        padding: const EdgeInsets.symmetric(vertical: 8),

        // ✅ حالة التحميل الأولي
        initialLoader: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),

        // ✅ حالة التحميل عند الوصول للنهاية
        bottomLoader: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),

        // ✅ حالة عدم وجود سجلات
        onEmpty: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'لا توجد حركات مسجلة',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),

        // ✅ بناء العنصر
        itemBuilder: (context, docs, index) {
          final movement = Movement.fromMap(
            docs[index].data() as Map<String, dynamic>,
          );

          final isIncoming = movement.type;
          final color = isIncoming == 'in'
              ? Colors.green.shade700
              : isIncoming == 'delete'
              ? Colors.orange.shade700
              : Colors.red.shade700;

          final icon = isIncoming == 'in'
              ? Icons.arrow_downward
              : isIncoming == 'delete'
              ? Icons.delete_outline
              : Icons.arrow_upward;

          final label = isIncoming == 'in'
              ? 'إضافة'
              : isIncoming == 'delete'
              ? 'حذف'
              : 'صرف';

          final formattedDate = DateFormat(
            'dd/MM/yyyy - HH:mm',
          ).format(movement.createdAt);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
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

                  if (movement.note.trim().isNotEmpty)
                    Material(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final invoiceService = InvoiceService();

                          final invoice = await invoiceService.getInvoice(
                            widget.service.groupId,
                            movement.invoiceId,
                          );

                          if (!context.mounted || invoice == null) return;

                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InvoiceDetailPage(
                                invoice: invoice,
                                groupId: widget.service.groupId,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.sticky_note_2_outlined,
                                size: 19,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ملاحظة',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      movement.note,
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 3.2. حوار الحركة (كـ StatelessWidget)
class MovementDialog extends StatelessWidget {
  final String type;
  final Function(double qty, String? note) onSave;

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
            final qty = double.tryParse(qtyController.text) ?? 0;
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
  final String country;
  const InventoryItemDetailsScreenRefactored({
    super.key,
    required this.groupId,
    required this.itemId,
    required this.deletedItems,
    required this.country,
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
  Map<String, dynamic>? _latestItemData;

  String get _currentUser =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'غير معروف';

  @override
  void initState() {
    print('vvvvvvvvvvvvvvvvvvv${widget.country}');
    super.initState();
    _service = InventoryService(groupId: widget.groupId, itemId: widget.itemId);
  }

  Future<void> _handleMovement(String type, double qty, String? note) async {
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
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'مساعدة AI للصنف',
                  onPressed: () {
                    // يتم تمرير بيانات الصنف الحية من StreamBuilder عند الضغط.
                    final item = _latestItemData;
                    if (item == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('بيانات الصنف غير جاهزة')),
                      );
                      return;
                    }
                    _showItemAiPicker(item);
                  },
                ),
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
                _latestItemData = item;
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
                                        await showDialog<bool>(
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
                                                  final snapshot =
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection(
                                                            'inventory',
                                                          )
                                                          .doc(widget.groupId)
                                                          .collection('items')
                                                          .doc(widget.itemId)
                                                          .collection(
                                                            'movements',
                                                          )
                                                          .get();

                                                  final batch =
                                                      FirebaseFirestore.instance
                                                          .batch();

                                                  for (var doc
                                                      in snapshot.docs) {
                                                    batch.delete(doc.reference);
                                                  }
                                                  final ref = FirebaseFirestore
                                                      .instance
                                                      .collection('inventory')
                                                      .doc(widget.groupId)
                                                      .collection('items')
                                                      .doc(widget.itemId);
                                                  batch.delete(ref);
                                                  await batch.commit();

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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'تم حذف الصنف بنجاح.',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailRow(
                                        context,
                                        'سعر الوحدة',
                                        '${item['price'] ?? 0.0}',
                                        Icons.attach_money,
                                        item['price'] != null &&
                                                item['price'] > 0
                                            ? Colors.blueAccent
                                            : Colors.red,
                                      ),
                                    ),

                                    //  const SizedBox(width: 20),
                                    IconButton(
                                      onPressed: () {
                                        _buildPriceDialog(item);
                                      },
                                      icon: Icon(
                                        Icons.edit,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                ),
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
                                  'المخزن',
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

  void _showItemAiPicker(Map<String, dynamic> item) {
    final tools = <({String name, String url, String badge, Color color})>[
      (
        name: 'ChatGPT',
        url: 'https://chatgpt.com/',
        badge: 'GPT',
        color: const Color(0xFF10A37F),
      ),
      (
        name: 'Claude',
        url: 'https://claude.ai/',
        badge: 'C',
        color: const Color(0xFFD97757),
      ),
      (
        name: 'Gemini',
        url: 'https://gemini.google.com/app',
        badge: 'G',
        color: const Color(0xFF4285F4),
      ),
      (
        name: 'Manus',
        url: 'https://manus.im/app',
        badge: 'M',
        color: const Color(0xFF635BFF),
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.teal),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مساعد المنتج الذكي',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'استفسر عن المنتج والسعر',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2F1),
                  child: Icon(Icons.copy_rounded, color: Colors.teal),
                ),
                title: const Text(
                  'نسخ البرومبت فقط',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'جاهز للصق في أي أداة AI',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _copyItemAiPrompt(item);
                },
              ),
              const Divider(height: 1),
              for (final tool in tools)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      tool.badge,
                      style: TextStyle(
                        color: tool.color,
                        fontWeight: FontWeight.w800,
                        fontSize: tool.badge.length > 1 ? 13 : 19,
                      ),
                    ),
                  ),
                  title: Text(
                    'نسخ وفتح ${tool.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 19),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openItemInAi(item, tool.name, tool.url);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildItemAiPrompt(Map<String, dynamic> item) {
    String readValue(List<String> keys, {String fallback = 'غير متوفر'}) {
      for (final key in keys) {
        final value = item[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return fallback;
    }

    // نقبل أسماء حقول منشأ شائعة في البيانات، ولا نخلطها ببلد المستخدم.
    final origin = readValue(
      [
        'countryOfOrigin',
        'originCountry',
        'madeIn',
        'country_of_origin',
        'origin',
        'country',
      ],
      fallback: widget.country.trim().isEmpty
          ? 'غير متوفر'
          : widget.country.trim(),
    );
    final productName = readValue([
      'name',
      'productName',
      'itemName',
    ], fallback: 'صنف غير مسمى');
    final sku = readValue(['sku', 'code']);
    final price = readValue(['price']);
    final unit = readValue(['unit']);

    return '''أنت مساعد متخصص في المنتجات والمشتريات. أريد معلومات موثوقة ومحدثة عن المنتج التالي:

- اسم المنتج: $productName
- بلد المنشأ المسجل: $origin
- كود المنتج: $sku
- السعر المسجل بالمخزون: $price
- الوحدة: $unit
- بلد المستخدم/السوق المطلوب للاستفسار عن السعر: ${widget.country}

المطلوب باختصار:
1. وضّح ما هو المنتج واستخداماته، واطلب توضيحًا إذا كان الاسم عامًا أو غير كافٍ.
2. إذا أمكن، قدّر سعره الحالي في سوق ${widget.country}، مع العملة وتاريخ التقدير ونطاق سعري تقريبي.
3. لا تخمّن السعر أو بلد المنشأ. إذا لم تتوفر بيانات موثوقة، اذكر ذلك واطلب الشركة المصنعة أو الموديل أو رابط المنتج.
4. اذكر مصادر وروابط حديثة للسعر عند توفر البحث على الإنترنت، وميّز السعر التقريبي عن السعر المسجل في المخزون.

أجب بالعربية بوضوح واختصار.''';
  }

  Future<void> _copyItemAiPrompt(Map<String, dynamic> item) async {
    try {
      await Clipboard.setData(ClipboardData(text: _buildItemAiPrompt(item)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ برومبت المنتج والسعر')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر نسخ البرومبت: $e')));
    }
  }

  Future<void> _openItemInAi(
    Map<String, dynamic> item,
    String aiName,
    String url,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: _buildItemAiPrompt(item)));
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'تم نسخ البرومبت. الصقه في $aiName'
                : 'تم نسخ البرومبت، لكن تعذر فتح $aiName',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تجهيز البرومبت: $e')));
    }
  }

  void _buildPriceDialog(Map<String, dynamic> item) {
    final priceController = TextEditingController(
      text: item['price'] != null ? item['price'].toString() : '',
    );
    final nameController = TextEditingController(text: item['name'] ?? '');

    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('تعديل بيانات الصنف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              onTap: () {
                nameController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: nameController.text.length,
                );
              },

              decoration: const InputDecoration(
                labelText: 'اسم الصنف',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: priceController,
              onTap: () {
                priceController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: priceController.text.length,
                );
              },
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'سعر الوحدة',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(priceController.text) ?? 0.0;
              final newName = nameController.text.trim();
              if (newPrice < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('السعر لا يمكن أن يكون سالبًا.'),
                  ),
                );
                return;
              }
              try {
                await FirebaseFirestore.instance
                    .collection('inventory')
                    .doc(widget.groupId)
                    .collection('items')
                    .doc(widget.itemId)
                    .update({'price': newPrice, 'name': newName});
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث السعر بنجاح.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في تحديث السعر: $e')),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
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

Future<void> generateItemMovementPdf({
  required Map<String, dynamic> itemData,
  required List<Map<String, dynamic>> movementsList,
}) async {
  final pdf = pw.Document();

  // تحميل الخطوط العربية (Cairo يدعم الـ Ligatures بشكل ممتاز)
  final arabicFont = await PdfGoogleFonts.cairoRegular();
  final arabicFontBold = await PdfGoogleFonts.cairoBold();

  String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      // الحل الجذري 1: ضبط الثيم العام للـ PDF ليدعم العربية
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
      header: (context) => _buildHeader(todayDate),
      footer: (context) => _buildFooter(context),
      build: (context) => [
        _buildItemInfoSection(itemData),
        pw.SizedBox(height: 20),
        _rtlText(
          "سجل حركات الصنف:",
          fontSize: 16,
          isBold: true,
          color: PdfColors.blue900,
        ),
        pw.SizedBox(height: 10),
        _buildMovementsTable(movementsList),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'حركات_${itemData['name']}_$todayDate.pdf',
  );
  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'حركات_${itemData['name']}_$todayDate.pdf',
  );
}

/// دالة سحرية لمعالجة أي نص عربي وضمان ترابط حروفه واتجاهه
pw.Widget _rtlText(
  String text, {
  double fontSize = 12,
  bool isBold = false,
  PdfColor? color,
}) {
  return pw.Directionality(
    textDirection: pw.TextDirection.rtl,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    ),
  );
}

pw.Widget _buildHeader(String date) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(bottom: 20),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.blue900, width: 2),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _rtlText(
          "تقرير حركة صنف مخزني",
          fontSize: 22,
          isBold: true,
          color: PdfColors.blue900,
        ),
        _rtlText("تاريخ التقرير: $date", fontSize: 12),
      ],
    ),
  );
}

pw.Widget _buildItemInfoSection(Map<String, dynamic> item) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      children: [
        _infoRow("اسم الصنف:", item['name']?.toString() ?? "---"),
        _infoRow("كود الصنف (SKU):", item['sku']?.toString() ?? "---"),
        _infoRow("المخزن / الموقع:", item['location']?.toString() ?? "---"),
        _infoRow(
          "الكمية الحالية:",
          "${item['quantity'] ?? 0} ${item['unit'] ?? ''}",
        ),
      ],
    ),
  );
}

pw.Widget _infoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: _rtlText(value),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.SizedBox(width: 100, child: _rtlText(label, isBold: true)),
      ],
    ),
  );
}

pw.Widget _buildMovementsTable(List<Map<String, dynamic>> movements) {
  return pw.TableHelper.fromTextArray(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
    cellAlignment: pw.Alignment.centerRight,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
    cellStyle: const pw.TextStyle(fontSize: 10),
    // الحل الجذري 2: إرسال النصوص كـ Widgets بدلاً من Strings داخل الجدول
    headers: [
      _rtlText('ملاحظات', isBold: true),
      _rtlText('المسؤول', isBold: true),
      _rtlText('الكمية', isBold: true),
      _rtlText('النوع', isBold: true),
      _rtlText('التاريخ', isBold: true),
    ],
    data: movements.map((m) {
      String dateStr = "---";
      if (m['createdAt'] != null) {
        DateTime dt = (m['createdAt'] as Timestamp).toDate();
        dateStr = DateFormat('yyyy-MM-dd HH:mm').format(dt);
      }
      String typeStr = m['type'] == 'in'
          ? 'دخول (+)'
          : (m['type'] == 'out' ? 'خروج (-)' : m['type'].toString());
      PdfColor typeColor = m['type'] == 'in'
          ? PdfColors.green700
          : PdfColors.red700;

      return [
        _rtlText(m['note']?.toString() ?? "---"),
        _rtlText(m['createdBy']?.toString() ?? "---"),
        _rtlText("${m['qty'] ?? 0} ${m['unit'] ?? ''}"),
        _rtlText(typeStr, color: typeColor),
        _rtlText(dateStr),
      ];
    }).toList(),
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(1.5),
      2: const pw.FlexColumnWidth(1),
      3: const pw.FlexColumnWidth(1),
      4: const pw.FlexColumnWidth(1.5),
    },
  );
}

pw.Widget _buildFooter(pw.Context context) {
  return pw.Container(
    alignment: pw.Alignment.center,
    margin: const pw.EdgeInsets.only(top: 10),
    child: _rtlText(
      "صفحة ${context.pageNumber} من ${context.pagesCount}",
      fontSize: 10,
      color: PdfColors.grey600,
    ),
  );
}
