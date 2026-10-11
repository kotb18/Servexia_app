import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/invoicePage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AddInventoryItemScreen extends StatefulWidget {
  final String groupId;
  final bool isFromInvoice;
  final String invoiceType;
  final String customerId;
  final bool isEditMode;
  final List itemsPurchase;
  final bool isFromWarehouseScreen;

  const AddInventoryItemScreen({
    super.key,
    required this.groupId,
    required this.isFromInvoice,
    required this.invoiceType,
    required this.customerId,
    required this.isEditMode,
    required this.itemsPurchase,
    required this.isFromWarehouseScreen,
  });

  static const String screenroute = 'addInventoryItem';

  @override
  State<AddInventoryItemScreen> createState() => _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState extends State<AddInventoryItemScreen> {
  static const Color _primary = Color(0xFF1769E0);
  static const Color _ink = Color(0xFF172B4D);
  static const Color _canvas = Color(0xFFF4F7FC);

  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final skuController = TextEditingController();
  final qtyController = TextEditingController();
  final unitController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();
  final coastController = TextEditingController();
  final priceController = TextEditingController();

  List<String> units = [];
  List<String> locations = [];
  bool showUnits = false;
  bool showLocations = false;
  bool loading = false;
  bool generatingSku = false;
  bool? isWeighted;
  bool _skuSelectedOnce = false;

  CollectionReference<Map<String, dynamic>> get _itemsRef => FirebaseFirestore
      .instance
      .collection('inventory')
      .doc(widget.groupId)
      .collection('items');

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    _fillNextSku();
  }

  @override
  void dispose() {
    nameController.dispose();
    skuController.dispose();
    qtyController.dispose();
    unitController.dispose();
    locationController.dispose();
    notesController.dispose();
    coastController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final results = await Future.wait([
        _itemsRef.orderBy('unit').limit(100).get(),
        _itemsRef.orderBy('location').limit(100).get(),
      ]);
      final unitSet = <String>{};
      final locationSet = <String>{};
      for (final doc in results[0].docs) {
        final value = doc.data()['unit']?.toString().trim() ?? '';
        if (value.isNotEmpty) unitSet.add(value);
      }
      for (final doc in results[1].docs) {
        final value = doc.data()['location']?.toString().trim() ?? '';
        if (value.isNotEmpty) locationSet.add(value);
      }
      if (!mounted) return;
      setState(() {
        units = unitSet.toList()..sort();
        locations = locationSet.toList()..sort();
      });
    } catch (_) {
      // The form remains usable even if suggestions cannot be loaded.
    }
  }

  Future<void> _fillNextSku() async {
    if (generatingSku || !mounted) return;
    setState(() => generatingSku = true);
    try {
      final snapshot = await _itemsRef.get();
      var highestExistingNumber = 0;
      final digitsOnly = RegExp(r'^\d+$');

      for (final item in snapshot.docs) {
        final rawSku = (item.data()['sku'] ?? item.id).toString().trim();
        if (!digitsOnly.hasMatch(rawSku)) continue;
        final number = int.tryParse(rawSku);
        if (number != null && number > highestExistingNumber) {
          highestExistingNumber = number;
        }
      }

      final counterRef = FirebaseFirestore.instance
          .collection('inventory')
          .doc(widget.groupId)
          .collection('settings')
          .doc('sku_sequence');

      final nextNumber = await FirebaseFirestore.instance.runTransaction<int>((
        transaction,
      ) async {
        final counterSnapshot = await transaction.get(counterRef);
        final lastNumber =
            (counterSnapshot.data()?['lastNumber'] as num?)?.toInt() ?? 0;
        final next =
            (lastNumber > highestExistingNumber
                ? lastNumber
                : highestExistingNumber) +
            1;
        transaction.set(counterRef, {
          'lastNumber': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return next;
      });

      if (!mounted) return;
      // Do not overwrite a code the user has already entered.
      if (skuController.text.trim().isEmpty) {
        setState(() => skuController.text = nextNumber.toString());
      }
    } catch (e) {
      if (mounted) {
        _showSnack('تعذر توليد كود الصنف. يمكنك إدخاله يدويًا.');
      }
    } finally {
      if (mounted) setState(() => generatingSku = false);
    }
  }

  double _number(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }

  Future<void> saveItem() async {
    FocusScope.of(context).unfocus();
    setState(() {
      showUnits = false;
      showLocations = false;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final sku = skuController.text.trim();
    if (!RegExp(r'^\d+$').hasMatch(sku)) {
      _showError('كود الصنف يجب أن يتكون من أرقام فقط');
      return;
    }

    final quantity = _number(qtyController.text);
    final cost = _number(coastController.text);
    final price = _number(priceController.text);

    if (widget.isFromInvoice) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePage(
            groupId: widget.groupId,
            isEditMode: widget.isEditMode,
            itemsSale: [],
            itemsPurchase: [
              {
                'id': sku,
                'isInventoryItem': false,
                'name': nameController.text.trim(),
                'sku': sku,
                'quantity': quantity,
                'unit': unitController.text.trim(),
                'location': locationController.text.trim(),
                'notes': notesController.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
                'price': price,
                'coast': cost,
                'isInStore': false,
                'imagesList': [],
                'isNewlyAdded': true,
                'isWeighted': isWeighted ?? false,
              },
              ...widget.itemsPurchase,
            ],
            isFormStore: false,
            name: '',
            phone: '',
            address: '',
            customerId: widget.customerId,
            isFromConstCustomers: false,
            isFromWorkSpace: false,
            type: widget.invoiceType,
          ),
        ),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final docRef = _itemsRef.doc(sku);
      final existingItem = await docRef.get();

      if (existingItem.exists) {
        if (mounted) setState(() => loading = false);
        _showError('يوجد صنف آخر بنفس الكود، الرجاء استخدام كود مختلف');
        return;
      }

      // Save the item and its opening movement atomically.
      final batch = FirebaseFirestore.instance.batch();
      batch.set(docRef, {
        'name': nameController.text.trim(),
        'sku': sku,
        'quantity': quantity,
        'unit': unitController.text.trim(),
        'location': locationController.text.trim(),
        'notes': notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'price': price,
        'coast': cost,
        'isInStore': false,
        'imagesList': [],
        'isNewlyAdded': false,
        'isWeighted': isWeighted ?? false,
      });

      final movementRef = docRef.collection('movements').doc();
      batch.set(movementRef, {
        'type': 'in',
        'qty': quantity,
        'unit': unitController.text.trim(),
        'note': notesController.text.trim(),
        'createdBy':
            FirebaseAuth.instance.currentUser?.displayName ?? 'غير معروف',
        'createdAt': FieldValue.serverTimestamp(),
        'price': price,
        'coast': cost,
      });
      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showError('تعذر حفظ الصنف. تأكد من الاتصال وحاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      title: 'خطأ',
      desc: message,
      btnOkText: 'حسنًا',
      btnOkOnPress: () {},
    ).show();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  T? _getDynamicValue<T>(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (!data.containsKey(key) || data[key] == null) continue;
      final value = data[key];
      if (T == String) return value.toString() as T;
      if (T == double) return double.tryParse(value.toString()) as T?;
      if (T == int) return int.tryParse(value.toString()) as T?;
      if (value is T) return value;
    }
    return null;
  }

  Future<void> _scanCode() async {
    final scanResult = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (!mounted || scanResult == null) return;

    final raw = (scanResult['raw'] ?? '').toString().trim();
    if (raw.isEmpty) {
      _showError('لم يتم قراءة أي بيانات');
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final name =
            _getDynamicValue<String>(decoded, [
              'name',
              'title',
              'product_name',
            ]) ??
            '';
        final barcode =
            _getDynamicValue<String>(decoded, [
              'barcode',
              'upc',
              'ean',
              'sku',
              'code',
            ]) ??
            '';
        final price =
            _getDynamicValue<double>(decoded, [
              'price',
              'unit_price',
              'item_price',
            ]) ??
            0.0;

        setState(() {
          if (name.isNotEmpty) nameController.text = name;
          if (barcode.isNotEmpty) skuController.text = barcode;
          if (price > 0) coastController.text = price.toString();
        });
        return;
      }
    } catch (_) {
      // Raw value may be a barcode or plain text rather than JSON.
    }

    if (RegExp(r'^[0-9]+$').hasMatch(raw)) {
      setState(() => skuController.text = raw);
    } else if (raw.startsWith('http')) {
      _showSnack('تمت قراءة رابط وليس باركود رقميًا؛ أدخل كود الصنف يدويًا');
    } else {
      setState(() => nameController.text = raw);
      _showSnack('تم ملء الاسم من الكود؛ راجع البيانات قبل الحفظ');
    }
  }

  Future<void> _showChoices({
    required String title,
    required List<String> values,
    required TextEditingController controller,
    required bool isUnit,
  }) async {
    final searchController = TextEditingController();
    String query = '';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = values
                .where((e) => e.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * .72,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8E0EC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: searchController,
                          onChanged: (value) =>
                              setSheetState(() => query = value),
                          decoration: InputDecoration(
                            hintText: 'بحث...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: _canvas,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            ...filtered.map(
                              (value) => ListTile(
                                leading: Icon(
                                  isUnit
                                      ? Icons.straighten_rounded
                                      : Icons.location_on_outlined,
                                  color: _primary,
                                ),
                                title: Text(value),
                                trailing: controller.text == value
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: _primary,
                                      )
                                    : null,
                                onTap: () => Navigator.pop(sheetContext, value),
                              ),
                            ),
                            if (query.trim().isNotEmpty &&
                                !values.contains(query.trim()))
                              ListTile(
                                leading: const Icon(
                                  Icons.add_circle_outline,
                                  color: _primary,
                                ),
                                title: Text('استخدام "$query"'),
                                subtitle: const Text('إضافة قيمة جديدة'),
                                onTap: () =>
                                    Navigator.pop(sheetContext, query.trim()),
                              ),
                            if (filtered.isEmpty && query.trim().isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('لا توجد اختيارات محفوظة بعد'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();

    if (!mounted || selected == null || selected.trim().isEmpty) return;
    setState(() {
      controller.text = selected.trim();
      if (isUnit) {
        showUnits = false;
        if (!units.contains(selected.trim())) units.add(selected.trim());
      } else {
        showLocations = false;
        if (!locations.contains(selected.trim()))
          locations.add(selected.trim());
      }
    });
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primary, size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFFAFBFE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      labelStyle: const TextStyle(color: Color(0xFF66758B), fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFF9AA7B8), fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE1E8F2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE1E8F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE05252)),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? hint,
    String? Function(String?)? validator,
    bool selectAllOnce = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      textInputAction: TextInputAction.next,
      onTap: () {
        if (selectAllOnce && !_skuSelectedOnce) {
          _skuSelectedOnce = true;
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      },
      decoration: _decoration(label, icon, hint: hint, suffix: suffix),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAF0F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B19365C),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8290A4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _gap([double height = 14]) => SizedBox(height: height);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: _primary),
        scaffoldBackgroundColor: _canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      child: Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إضافة صنف مخزني',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 3),
              Text(
                'أدخل بيانات الصنف لإضافته إلى المخزون',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF8190A5),
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsetsDirectional.only(end: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                tooltip: 'مسح باركود',
                onPressed: loading ? null : _scanCode,
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFEAF0F7)),
          ),
        ),
        body: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1459C7), Color(0xFF287CF0)],
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x251765D8),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 13),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'بيانات صنف جديد',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'املأ الحقول المطلوبة ثم احفظ البيانات',
                                style: TextStyle(
                                  color: Color(0xFFDDEAFF),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: loading ? null : _scanCode,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: .14,
                            ),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.document_scanner_outlined),
                        ),
                      ],
                    ),
                  ),
                  _section(
                    title: 'بيانات الصنف',
                    subtitle: 'الاسم والكود والأسعار',
                    icon: Icons.widgets_outlined,
                    children: [
                      _field(
                        controller: nameController,
                        label: 'اسم الصنف',
                        hint: 'اكتب اسم الصنف هنا',
                        icon: Icons.inventory_2_outlined,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'اسم الصنف مطلوب'
                            : null,
                      ),
                      _gap(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _field(
                              controller: skuController,
                              label: 'كود الصنف (SKU)',
                              hint: 'أرقام فقط',
                              icon: Icons.qr_code_2_rounded,
                              keyboard: TextInputType.number,
                              selectAllOnce: true,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'الكود مطلوب'
                                  : null,
                              suffix: generatingSku
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 56,
                            width: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: IconButton(
                              tooltip: 'توليد كود جديد',
                              onPressed: (loading || generatingSku)
                                  ? null
                                  : _fillNextSku,
                              icon: const Icon(Icons.autorenew_rounded),
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                      _gap(),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: coastController,
                              label: 'التكلفة',
                              hint: '0.00',
                              icon: Icons.payments_outlined,
                              keyboard: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                if (_number(v) < 0)
                                  return 'لا يمكن أن تكون سالبة';
                                if (double.tryParse(v.replaceAll(',', '.')) ==
                                    null) {
                                  return 'أدخل رقمًا صحيحًا';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              controller: priceController,
                              label: 'سعر البيع',
                              hint: '0.00',
                              icon: Icons.sell_outlined,
                              keyboard: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'السعر مطلوب';
                                }
                                if (double.tryParse(v.replaceAll(',', '.')) ==
                                    null) {
                                  return 'أدخل رقمًا صحيحًا';
                                }
                                if (_number(v) < 0)
                                  return 'لا يمكن أن يكون سالبًا';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _section(
                    title: 'المخزون والموقع',
                    subtitle: 'الكمية ووحدة القياس ومكان التخزين',
                    icon: Icons.warehouse_outlined,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _canvas,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5ECF5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.scale_outlined, color: _primary),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'صنف يباع بالوزن',
                                    style: TextStyle(
                                      color: _ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'لتحديد طبيعة الصنف عند قراءة الباركود',
                                    style: TextStyle(
                                      color: Color(0xFF8290A4),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: isWeighted ?? false,
                              activeColor: _primary,
                              onChanged: (value) =>
                                  setState(() => isWeighted = value),
                            ),
                          ],
                        ),
                      ),
                      _gap(),
                      _field(
                        controller: qtyController,
                        label: 'الكمية الافتتاحية',
                        hint: 'أدخل الكمية',
                        icon: Icons.numbers_rounded,
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'الكمية مطلوبة';
                          }
                          if (double.tryParse(v.replaceAll(',', '.')) == null) {
                            return 'أدخل كمية رقمية صحيحة';
                          }
                          if (_number(v) < 0)
                            return 'الكمية لا يمكن أن تكون سالبة';
                          return null;
                        },
                      ),
                      _gap(),
                      _field(
                        controller: unitController,
                        label: 'وحدة القياس',
                        hint: 'عدد، قطعة، كيلو، متر...',
                        icon: Icons.straighten_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'وحدة القياس مطلوبة'
                            : null,
                        suffix: IconButton(
                          tooltip: 'اختيار وحدة',
                          onPressed: () => _showChoices(
                            title: 'اختيار وحدة القياس',
                            values: units,
                            controller: unitController,
                            isUnit: true,
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ),
                      _gap(),
                      _field(
                        controller: locationController,
                        label: 'الموقع / المخزن',
                        hint: 'المستودع الرئيسي',
                        icon: Icons.location_on_outlined,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'الموقع مطلوب'
                            : null,
                        suffix: IconButton(
                          tooltip: 'اختيار موقع',
                          onPressed: () => _showChoices(
                            title: 'اختيار الموقع',
                            values: locations,
                            controller: locationController,
                            isUnit: false,
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ),
                    ],
                  ),
                  _section(
                    title: 'ملاحظات إضافية',
                    subtitle: 'أي تفاصيل تحتاج الرجوع إليها لاحقًا',
                    icon: Icons.notes_rounded,
                    children: [
                      TextFormField(
                        controller: notesController,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: _decoration(
                          'ملاحظات',
                          Icons.edit_note_rounded,
                          hint: 'اكتب ملاحظات عن الصنف أو التخزين...',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      onPressed: loading ? null : saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        disabledBackgroundColor: const Color(0xFF9CB9E8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save_rounded),
                                const SizedBox(width: 10),
                                Text(
                                  widget.isFromInvoice
                                      ? 'إضافة الصنف للفاتورة'
                                      : 'حفظ الصنف',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Servexia • إدارة مخزونك بسهولة',
                      style: TextStyle(color: Color(0xFF98A5B7), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  late final MobileScannerController controller;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (isProcessing || !mounted) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final rawValue = barcode?.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    isProcessing = true;
    try {
      await controller.stop();
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
      if (!mounted) return;
      Navigator.pop(context, {'raw': rawValue, 'format': barcode?.format.name});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء قراءة الكود')),
        );
      }
      isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('مسح باركود / QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, child) {
              return IconButton(
                tooltip: 'تشغيل / إيقاف الفلاش',
                onPressed: () => controller.toggleTorch(),
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'وجّه الكاميرا نحو باركود أو QR الخاص بالصنف',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
