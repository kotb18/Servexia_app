import 'dart:convert';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/addAwarehouseItem.dart';
import 'package:maintenance/invoicePage.dart';
import 'package:maintenance/wareHouseItemeMovement.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

// ─── Global State ───
List<Map<String, dynamic>> itemsList = [];
String buttonText = '';
List<Map> items = [];
Set<String> selectedIds = {};
Map<String, double> itemCounters = {};

class StoreScreen extends StatefulWidget {
  final String groupId;
  final bool isFromInvoice;
  final bool deletedItems;
  final String invoiceType;
  final String customerId;
  final bool isEditMode;
  final List<Map<dynamic, dynamic>> itemsPurchase;
  const StoreScreen({
    super.key,
    required this.groupId,
    required this.isFromInvoice,
    required this.deletedItems,
    required this.invoiceType,
    required this.customerId,
    required this.isEditMode,
    required this.itemsPurchase,
  });
  static const String screenroute = 'StoreScreen';

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String? selectedLocation = 'all';
  String searchText = '';
  bool deletedItems = false;
  final searchController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController skuController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String scannedId = '';

  final Color primaryColor = const Color(0xFF2563EB);
  final Color secondaryColor = const Color(0xFF3B82F6);
  final Color accentColor = const Color(0xFF10B981);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color cardColor = Colors.white;
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color dangerColor = const Color(0xFFEF4444);

  // ═══ حالة إظهار/إخفاء الهيدر ═══
  bool _showHeader = true;

  // ─── تحميل المواقع ───
  Future<List<String>> loadLocations() async {
    final snap = await FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.groupId)
        .collection('items')
        .get();

    final set = <String>{};
    for (var doc in snap.docs) {
      if (doc['location'] != null && doc['location'].toString().isNotEmpty) {
        set.add(doc['location']);
      }
    }
    return set.toList()..sort();
  }

  // ─── Query البحث ───
  Query<Map<String, dynamic>> itemsQuery() {
    final search = searchText.trim().toLowerCase();

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.groupId)
        .collection('items');

    if (selectedLocation == null) {
      return query.where('name', isEqualTo: '__EMPTY__').limit(2);
    }

    if (selectedLocation != 'all') {
      query = query.where('location', isEqualTo: selectedLocation);
    }

    if (search.isNotEmpty) {
      final isSku = RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(search);
      if (isSku) {
        query = query
            .where(
              'sku',
              isGreaterThanOrEqualTo: search,
              isLessThanOrEqualTo: '$search\uf8ff',
            )
            .orderBy('sku');
      } else {
        query = query
            .where(
              'name',
              isGreaterThanOrEqualTo: search,
              isLessThanOrEqualTo: '$search\uf8ff',
            )
            .orderBy('name');
      }
    } else {
      query = query.orderBy('name');
    }
    return query;
  }

  // ─── جلب كل الأصناف للسكان (بدون Pagination) ───
  Future<void> _refreshItemsList() async {
    if (!widget.isFromInvoice) return;
    try {
      final query = itemsQuery();
      final snap = await query.get();
      itemsList = snap.docs.map((d) => d.data()).toList();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading itemsList: $e');
    }
  }

  TextEditingController itemNameController = TextEditingController();
  TextEditingController itemQuantityController = TextEditingController();
  TextEditingController itemPriceController = TextEditingController();
  TextEditingController itemBuyController = TextEditingController();

  void _showError(String msg) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      title: "خطأ",
      desc: msg,
      btnOkText: 'حسنـــــأً',
      btnOkOnPress: () {},
    ).show();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? dangerColor : accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.invoiceType == 'شراء') {
      items = widget.itemsPurchase;
    }
    if (widget.deletedItems) {
      items.clear();
      selectedIds.clear();
      itemCounters.clear();
    }
    if (items.isEmpty) {
      selectedIds.clear();
      itemCounters.clear();
      buttonText = ' اضافة ${selectedIds.length} عنصر';
    }
    for (var item in items) {
      final sku = item['sku']?.toString() ?? item['id']?.toString();
      if (sku != null && sku.isNotEmpty) {
        selectedIds.add(sku);
        itemCounters[sku] = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      }
    }
    _refreshItemsList();
  }

  @override
  void dispose() {
    searchController.dispose();
    itemNameController.dispose();
    itemQuantityController.dispose();
    itemPriceController.dispose();
    itemBuyController.dispose();
    selectedIds.clear();
    itemCounters.clear();
    super.dispose();
  }

  // ═══ معالج السكرول ═══
  void _handleScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final pos = notification.metrics.pixels;

      // سكرول لأسفل → إخفاء
      if (delta > 3 && pos > 20 && _showHeader) {
        setState(() => _showHeader = false);
      }
      // سكرول لأعلى → إظهار
      else if (delta < -3 && !_showHeader) {
        setState(() => _showHeader = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ═══════════════════════════════════════
            //  الهيدر (AppBar + Search + Filters)
            //  يختفي بالكامل مع السكرول لأسفل
            //  ويظهر فوراً مع السكرول لأعلى
            // ═══════════════════════════════════════
            ClipRect(
              child: AnimatedCrossFade(
                firstCurve: Curves.fastOutSlowIn,
                secondCurve: Curves.fastOutSlowIn,
                sizeCurve: Curves.fastOutSlowIn,
                duration: const Duration(milliseconds: 350),
                crossFadeState: _showHeader
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ─── AppBar ───
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, secondaryColor],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                      ),
                      child: AppBar(
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        centerTitle: true,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'المخـــــازن',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddInventoryItemScreen(
                                      groupId: widget.groupId,
                                      invoiceType: '',
                                      isFromInvoice: false,
                                      customerId: '',
                                      isEditMode: false,
                                      itemsPurchase: [],
                                      isFromWarehouseScreen: true,
                                    ),
                                  ),
                                );
                                _refreshItemsList();
                              },
                              child: const Text(
                                'اضافة صنف جديد',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        leading: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        actions: [
                          if (widget.isFromInvoice && items.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              child: Chip(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                label: Text(
                                  '${items.length} صنف',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ─── Search + Filters ───
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      decoration: BoxDecoration(
                        color: cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Search
                          Container(
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: TextField(
                              controller: searchController,
                              enabled:
                                  !deletedItems && selectedLocation != null,
                              textAlign: TextAlign.right,
                              decoration: InputDecoration(
                                hintText: 'ابحث باسم الصنف أو كود الصنف...',
                                hintStyle: TextStyle(
                                  color: textSecondary,
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: primaryColor,
                                ),
                                suffixIcon: searchText.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: textSecondary,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          searchController.clear();
                                          setState(() => searchText = '');
                                          _refreshItemsList();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() => searchText = value.trim());
                                _refreshItemsList();
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Locations
                          FutureBuilder<List<String>>(
                            future: loadLocations(),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return const SizedBox(
                                  height: 40,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final locations = snap.data!;
                              return SizedBox(
                                height: 44,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  children: [
                                    _buildFilterChip('الكل', 'all'),
                                    ...locations.map(
                                      (loc) => _buildFilterChip(loc, loc),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ),

            // ═══════════════════════════════════════
            //  القائمة مع مراقب السكرول
            // ═══════════════════════════════════════
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  _handleScroll(notification);
                  return false;
                },
                child:
                    (selectedLocation == null &&
                        searchText.isEmpty &&
                        !deletedItems)
                    ? _buildEmptySearch()
                    : FirestorePagination(
                        key: ValueKey(
                          '$selectedLocation-$searchText-$deletedItems',
                        ),
                        limit: widget.isFromInvoice ? 1000 : 10,
                        isLive: true,
                        query: itemsQuery(),
                        viewType: ViewType.list,
                        onEmpty: _buildEmptyList(),
                        bottomLoader: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        itemBuilder: (context, docs, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String sku = data['sku']?.toString() ?? doc.id;
                          final bool itemSelected =
                              selectedIds.contains(sku) && widget.isFromInvoice;
                          final double currentQty = itemCounters[sku] ?? 0.0;
                          final bool isWeightedItem =
                              data['isWeighted'] ?? false;
                          final String unitText =
                              data['unit']?.toString() ?? '';

                          return _buildItemCard(
                            data,
                            doc.id,
                            sku,
                            itemSelected,
                            currentQty,
                            isWeightedItem,
                            unitText,
                          );
                        },
                      ),
              ),
            ),
            !_showHeader ? SizedBox(height: 60) : SizedBox.shrink(),
          ],
        ),
      ),

      // ═══ Bottom Bar ثابت ═══
      bottomNavigationBar: widget.isFromInvoice
          ? ClipRRect(
              child: AnimatedCrossFade(
                firstCurve: Curves.fastOutSlowIn,
                secondCurve: Curves.fastOutSlowIn,
                sizeCurve: Curves.fastOutSlowIn,
                duration: const Duration(milliseconds: 350),
                crossFadeState: _showHeader
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: _buildInvoiceActionBar(),
                secondChild: const SizedBox.shrink(),
              ),
            )
          : ClipRRect(
              child: AnimatedCrossFade(
                firstCurve: Curves.fastOutSlowIn,
                secondCurve: Curves.fastOutSlowIn,
                sizeCurve: Curves.fastOutSlowIn,
                duration: const Duration(milliseconds: 350),
                crossFadeState: _showHeader
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: _buildStoreActionBar(),
                secondChild: const SizedBox.shrink(),
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedLocation == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: bgColor,
        selectedColor: primaryColor.withOpacity(0.1),
        side: BorderSide(
          color: isSelected ? primaryColor : Colors.grey.shade300,
          width: 1.5,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryColor : textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        onSelected: (_) {
          setState(() {
            selectedLocation = value;
            deletedItems = false;
            searchText = '';
            searchController.clear();
          });
          _refreshItemsList();
        },
      ),
    );
  }

  Widget _buildItemCard(
    Map<String, dynamic> data,
    String docId,
    String sku,
    bool itemSelected,
    double currentQty,
    bool isWeightedItem,
    String unitText,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: itemSelected
            ? Border.all(color: primaryColor.withOpacity(0.5), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: itemSelected
                ? primaryColor.withOpacity(0.1)
                : Colors.black.withOpacity(0.04),
            blurRadius: itemSelected ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _handleItemTap(data, docId, sku, isWeightedItem),
          onLongPress: widget.isFromInvoice
              ? () => _handleItemLongPress(data, docId, sku)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (widget.isFromInvoice)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: itemSelected ? primaryColor : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: itemSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : Icon(
                              Icons.add,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.1),
                          secondaryColor.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['name'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (data['deleted'] == true)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: dangerColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'محذوف',
                                style: TextStyle(
                                  color: dangerColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildInfoChip(
                            '${data['quantity'] ?? 0} $unitText',
                            Colors.blue.shade50,
                            Colors.blue.shade700,
                          ),
                          _buildInfoChip(
                            'السعر: ${data['price'] ?? 0}',
                            Colors.green.shade50,
                            Colors.green.shade700,
                          ),
                          if (sku.isNotEmpty)
                            _buildInfoChip(
                              sku,
                              Colors.grey.shade100,
                              textSecondary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (currentQty > 0 && widget.isFromInvoice)
                      GestureDetector(
                        onTap: () => _removeItem(sku),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isWeightedItem
                                    ? '${currentQty.toStringAsFixed(3)} ${unitText.isNotEmpty ? unitText : 'كجم'}'
                                    : '${currentQty.toStringAsFixed(currentQty.truncateToDouble() == currentQty ? 0 : 2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['location'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),

                    /// ممكن اشيلها في اي وقت
                    if (widget.isFromInvoice)
                      Row(
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_back_ios,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _handleItemTap(
    Map<String, dynamic> data,
    String docId,
    String sku,
    bool isWeightedItem,
  ) async {
    if (widget.isFromInvoice) {
      setState(() {
        if (!selectedIds.contains(sku)) {
          items.add({
            'id': sku,
            'isInventoryItem': true,
            'name': data['name'],
            'quantity': (itemCounters[sku] ?? 0) > 0 ? itemCounters[sku]! : 1.0,
            'unit': data['unit'],
            'sku': sku,
            'price': data['price'] ?? 0,
            'location': data['location'],
            'notes': data['notes'],
            'createdAt': FieldValue.serverTimestamp(),
            'deleted': false,
            'coast': itemBuyController.text.isNotEmpty
                ? double.tryParse(itemBuyController.text)
                : 0.0,
            'isNewlyAdded': false,
            'quantityInStock': data['quantity'] ?? 0,
          });
          selectedIds.add(sku);
          buttonText = ' اضافة ${selectedIds.length} عنصر';
        }

        itemCounters[sku] = (itemCounters[sku] ?? 0) + 1;
        for (var item in items.where(
          (i) => i['sku'] == sku || i['id'] == sku,
        )) {
          item['quantity'] = itemCounters[sku];
        }
      });
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InventoryItemDetailsScreenRefactored(
            groupId: widget.groupId,
            itemId: docId,
            deletedItems: deletedItems,
          ),
        ),
      );
    }
  }

  void _handleItemLongPress(
    Map<String, dynamic> data,
    String docId,
    String sku,
  ) {
    final existingQty = itemCounters[sku] ?? 1.0;
    itemQuantityController = TextEditingController(
      text: existingQty > 0 ? existingQty.toString() : '1',
    );
    itemPriceController = TextEditingController(
      text: data['price']?.toString() ?? '0',
    );
    itemBuyController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 24,
          right: 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_shopping_cart, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إضافة صنف للفاتورة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          '${data['name']} • المخزون: ${data['quantity']} ${data['unit']}',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: itemQuantityController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: widget.invoiceType == 'بيع'
                      ? 'الكمية المراد بيعها'
                      : 'الكمية المراد إضافتها',
                  labelStyle: TextStyle(
                    color: widget.invoiceType == 'بيع'
                        ? accentColor
                        : primaryColor,
                  ),
                  prefixIcon: Icon(
                    Icons.numbers,
                    color: widget.invoiceType == 'بيع'
                        ? accentColor
                        : primaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: bgColor,
                ),
                onTap: () {
                  itemQuantityController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: itemQuantityController.text.length,
                  );
                },
                validator: (value) {
                  if (widget.invoiceType == 'بيع') {
                    if (value == null || value.isEmpty)
                      return 'من فضلك أدخل الكمية';
                    final enteredQuantity = double.tryParse(value);
                    if (enteredQuantity == null) return 'أدخل قيمة رقمية صحيحة';
                    if (enteredQuantity > (data['quantity'] ?? 0))
                      return 'لا يمكن بيع كمية أكبر من الكمية المخزنية';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (widget.invoiceType == 'شراء')
                TextFormField(
                  controller: itemBuyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: 'سعر الشراء',
                    prefixIcon: Icon(Icons.attach_money, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: bgColor,
                  ),
                  onTap: () => itemBuyController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: itemBuyController.text.length,
                  ),
                ),
              if (widget.invoiceType == 'شراء') const SizedBox(height: 16),
              TextFormField(
                controller: itemPriceController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'سعر الوحدة',
                  prefixIcon: Icon(Icons.sell_outlined, color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: bgColor,
                ),
                onTap: () => itemPriceController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: itemPriceController.text.length,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final double qty =
                              double.tryParse(itemQuantityController.text) ??
                              1.0;
                          setState(() {
                            selectedIds.add(sku);
                            itemCounters[sku] = qty;
                            buttonText = ' اضافة ${selectedIds.length} عنصر';
                            items.removeWhere(
                              (item) => item['sku'] == sku || item['id'] == sku,
                            );
                          });
                          items.add({
                            'id': sku,
                            'isInventoryItem': true,
                            'name': data['name'],
                            'quantity': qty,
                            'unit': data['unit'],
                            'sku': sku,
                            'price':
                                double.tryParse(itemPriceController.text) ?? 0,
                            'location': data['location'],
                            'notes': data['notes'],
                            'createdAt': FieldValue.serverTimestamp(),
                            'deleted': false,
                            'coast': itemBuyController.text.isNotEmpty
                                ? double.tryParse(itemBuyController.text)
                                : 0.0,
                            'isNewlyAdded': false,
                            'quantityInStock': data['quantity'] ?? 0,
                          });
                          Navigator.pop(context);
                          _showSnackBar('تم إضافة ${data['name']} للفاتورة');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'إضافة للفاتورة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  void _removeItem(String sku) {
    setState(() {
      selectedIds.remove(sku);
      items.removeWhere((item) => item['sku'] == sku || item['id'] == sku);
      itemCounters.remove(sku);
      buttonText = ' اضافة ${selectedIds.length} عنصر';
    });
    _showSnackBar('تم إزالة الصنف');
  }

  Widget _buildInvoiceActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _handleScan,
              icon: const Icon(Icons.qr_code_scanner, size: 22),
              label: const Text(
                'امسح الباركود',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (items.isEmpty) {
                    _showSnackBar('لم يتم اختيار أي صنف', isError: true);
                    return;
                  }
                  if (widget.invoiceType == 'بيع') {
                    for (var item in items) {
                      if ((item['quantity'] ?? 0) >
                          (item['quantityInStock'] ?? 0)) {
                        _showSnackBar(
                          'الكمية المطلوبة للصنف ${item['name']} أكبر من الكمية المخزنية',
                          isError: true,
                        );
                        return;
                      }
                    }
                  }
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoicePage(
                        groupId: widget.groupId,
                        itemsSale:
                            (widget.invoiceType == 'بيع' ||
                                widget.invoiceType == 'عرض سعر')
                            ? items
                            : [],
                        itemsPurchase: widget.invoiceType == 'شراء'
                            ? items
                            : [],
                        name: '',
                        phone: '',
                        address: '',
                        customerId: widget.customerId,
                        isFromConstCustomers: false,
                        isFromWorkSpace: false,
                        type: widget.invoiceType,
                        isFormStore: false,
                        isEditMode: widget.isEditMode,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline, size: 22),
                label: Text(
                  items.isEmpty ? 'اختر أصنافاً' : 'اضافة ${items.length} عنصر',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: items.isNotEmpty
                      ? primaryColor
                      : Colors.grey.shade300,
                  foregroundColor: items.isNotEmpty
                      ? Colors.white
                      : textSecondary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _handleScan,
              icon: const Icon(Icons.qr_code_scanner, size: 22),
              label: const Text(
                'امسح الباركود',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor.withOpacity(0.1),
                foregroundColor: primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                  try {
                    final query = itemsQuery();
                    final snapshot = await query.get();
                    final List<Map<String, dynamic>> currentItems = snapshot
                        .docs
                        .map((doc) => doc.data())
                        .toList();
                    Navigator.pop(context);
                    if (currentItems.isEmpty) {
                      _showSnackBar('لا توجد بيانات لتصديرها', isError: true);
                      return;
                    }
                    generateInventoryPdf(currentItems);
                  } catch (e) {
                    Navigator.pop(context);
                    _showSnackBar(
                      'حدث خطأ أثناء جلب البيانات: $e',
                      isError: true,
                    );
                  }
                },
                icon: const Icon(Icons.picture_as_pdf, size: 22),
                label: const Text(
                  'تقرير PDF',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dangerColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleScan() async {
    T? getDynamicValue<T>(Map<String, dynamic> data, List<String> keys) {
      for (String key in keys) {
        if (data.containsKey(key) && data[key] != null) {
          if (T == String) return data[key].toString() as T;
          if (T == double) {
            return double.tryParse(data[key].toString()) as T?;
          }
          if (T == int) {
            return int.tryParse(data[key].toString()) as T?;
          }
          return data[key] as T;
        }
      }
      return null;
    }

    final scanResult = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (scanResult == null) return;

    final String raw = scanResult['raw'] ?? '';
    if (raw.isEmpty) {
      _showError("لم يتم قراءة أي بيانات");
      return;
    }

    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final name =
            getDynamicValue<String>(data, ['name', 'title', 'product_name']) ??
            '';
        final barcode =
            getDynamicValue<String>(data, [
              'barcode',
              'upc',
              'ean',
              'sku',
              'code',
            ]) ??
            '';
        final price =
            getDynamicValue<double>(data, [
              'price',
              'unit_price',
              'item_price',
            ]) ??
            0.0;
        debugPrint("JSON QR: name=$name, barcode=$barcode, price=$price");
        return;
      }
    } catch (_) {}

    if (RegExp(r'^[0-9]+$').hasMatch(raw)) {
      skuController.text = raw;

      if (!widget.isFromInvoice) {
        final weighteId = raw.substring(2, 7);
        final idx = itemsList.indexWhere(
          (item) => item['sku'] == raw || item['sku'] == weighteId,
        );
        final bool isWeighted = idx != -1
            ? (itemsList[idx]['isWeighted'] ?? false)
            : false;
        final String targetId = isWeighted ? weighteId : raw;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventoryItemDetailsScreenRefactored(
              groupId: widget.groupId,
              itemId: targetId,
              deletedItems: deletedItems,
            ),
          ),
        );
      } else {
        setState(() {
          scannedId = raw;
          final weighteId = raw.substring(2, 7);
          final index = itemsList.indexWhere(
            (item) => item['sku'] == raw || item['sku'] == weighteId,
          );

          if (index == -1) {
            _showError("المنتج غير موجود في القائمة");
            return;
          }

          final itemData = itemsList[index];
          final bool isWeighted = itemData['isWeighted'] ?? false;
          final String sku = isWeighted ? weighteId : raw;
          scannedId = sku;

          final double weightValue = isWeighted
              ? double.parse(
                  (double.parse(raw.substring(7, 12)) / 1000).toStringAsFixed(
                    2,
                  ),
                )
              : 1.0;

          if (!selectedIds.contains(sku) || isWeighted) {
            items.add({
              'id': sku,
              'isInventoryItem': true,
              'name': itemData['name'],
              'quantity': isWeighted
                  ? weightValue
                  : ((itemCounters[sku] ?? 0) > 0 ? itemCounters[sku]! : 1.0),
              'unit': itemData['unit'],
              'sku': sku,
              'price': itemData['price'] ?? 0,
              'location': itemData['location'],
              'notes': itemData['notes'],
              'createdAt': FieldValue.serverTimestamp(),
              'deleted': false,
              'coast': itemBuyController.text.isNotEmpty
                  ? double.tryParse(itemBuyController.text)
                  : 0.0,
              'isNewlyAdded': false,
              'quantityInStock': itemData['quantity'] ?? 0,
            });
            selectedIds.add(sku);
            buttonText = ' اضافة ${selectedIds.length} عنصر';
          }

          itemCounters[sku] =
              (itemCounters[sku] ?? 0) + (isWeighted ? weightValue : 1.0);

          if (!isWeighted) {
            for (var item in items.where(
              (i) => i['id'] == sku || i['sku'] == sku,
            )) {
              item['quantity'] = itemCounters[sku];
            }
          }
          debugPrint('Scan added: $items');
        });
      }
      return;
    }

    if (raw.startsWith("http")) {
      skuController.text = raw;
      _showSnackBar("تم قراءة رابط، تأكد من استخدامه بشكل صحيح");
      return;
    }

    nameController.text = raw;
    _showSnackBar("تم ملء الاسم من الكود، راجع البيانات");
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.filter_list, size: 48, color: primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'اختر "الكل" أو موقع المخزن',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لعرض الأصناف المتاحة في المخزن',
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            !deletedItems ? 'لا توجد أصناف' : 'لا توجد أصناف محذوفة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> generateInventoryPdf(List<Map<String, dynamic>> itemsList) async {
  final pdf = pw.Document();
  final arabicFont = await PdfGoogleFonts.cairoRegular();
  final arabicFontBold = await PdfGoogleFonts.cairoBold();
  String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
      header: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 15),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "تقرير الأصناف المخزنية",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    "تاريخ التقرير: $todayDate",
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.Text(
                "إجمالي الأصناف: ${itemsList.length}",
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      build: (context) {
        return [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey100,
              ),
              headerHeight: 30,
              cellHeight: 25,
              cellAlignment: pw.Alignment.centerRight,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headers: [
                'ملاحظات',
                'المخزن',
                'الكمية',
                'الوحدة',
                'كود الصنف',
                'اسم الصنف',
              ],
              data: itemsList
                  .map(
                    (item) => [
                      item['notes']?.toString() ?? "---",
                      item['location']?.toString() ?? "---",
                      item['quantity']?.toString() ?? "0",
                      item['unit']?.toString() ?? "---",
                      item['sku']?.toString() ?? "---",
                      item['name']?.toString() ?? "---",
                    ],
                  )
                  .toList(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(2.5),
              },
            ),
          ),
        ];
      },
      footer: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            "صفحة ${context.pageNumber} من ${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ),
      ),
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'تقرير_المخزن_$todayDate.pdf',
  );
  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'تقرير_المخزن_$todayDate.pdf',
  );
}
