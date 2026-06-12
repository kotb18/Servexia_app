import 'dart:convert';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/invoicePage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

bool showUnits = false;
bool showLocations = false;
List<String> units = [];
List<String> locations = [];
String? codeCheck;

class AddInventoryItemScreen extends StatefulWidget {
  final String groupId;
  final bool isFromInvoice;
  final String invoiceType;
  final String customerId;
  const AddInventoryItemScreen({
    super.key,
    required this.groupId,
    required this.isFromInvoice,
    required this.invoiceType,
    required this.customerId,
  });
  static const String screenroute = 'addInventoryItem';

  @override
  State<AddInventoryItemScreen> createState() => _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState extends State<AddInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final skuController = TextEditingController();
  final qtyController = TextEditingController();
  final unitController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();
  final coastController = TextEditingController();
  final priceController = TextEditingController();
  // final barcodeController = TextEditingController();

  bool loading = false;

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
    // barcodeController.dispose();
    super.dispose();
  }

  Widget _showUnitsPicker() {
    if (units.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 200, // علشان يعمل scroll لو كتير
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: units.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final u = units[index];
            final isSelected = unitController.text == u;

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  unitController.text = u;
                  showUnits = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1E88E5).withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        u,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF1E88E5)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF1E88E5),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _showLocationsPicker() {
    if (units.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 200, // علشان يعمل scroll لو كتير
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: locations.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final u = locations[index];
            final isSelected = locationController.text == u;

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  locationController.text = u;
                  showLocations = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1E88E5).withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        u,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF1E88E5)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF1E88E5),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<List<String>> searchUnits2() async {
    final snap = await FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.groupId)
        .collection('items')
        .orderBy('unit')
        .limit(10)
        .get();

    final set = <String>{};

    for (var doc in snap.docs) {
      if (doc['unit'] != null) {
        set.add(doc['unit']);
      }
    }

    return units = set.toList();
  }

  Future<List<String>> searchLocations2() async {
    final snap = await FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.groupId)
        .collection('items')
        .orderBy('location')
        .limit(10)
        .get();

    final set = <String>{};

    for (var doc in snap.docs) {
      if (doc['location'] != null) {
        set.add(doc['location']);
      }
    }

    return locations = set.toList();
  }

  Future<void> saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.isFromInvoice) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePage(
            groupId: widget.groupId,
            itemsSale: [],
            itemsPurchase: [
              {
                'id': skuController.text.trim(),
                'isInventoryItem': false,
                'name': nameController.text.trim(),
                'sku': skuController.text.trim(),
                'quantity': int.parse(qtyController.text),
                'unit': unitController.text.trim(),
                'location': locationController.text.trim(),
                'notes': notesController.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
                'deleted': false,
                'price': priceController.text.isNotEmpty
                    ? double.parse(priceController.text)
                    : 0.0,
                'coast': coastController.text.isNotEmpty
                    ? double.parse(coastController.text)
                    : 0.0,
              },
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
    } else {
      setState(() => loading = true);
      final existingItem = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(widget.groupId)
          .collection('items')
          .doc(skuController.text.trim())
          .get();
      if (existingItem.exists) {
        setState(() => loading = false);
        _showError("يوجد صنف آخر بنفس الكود، الرجاء استخدام كود مختلف");
        return;
      }

      final docRef = FirebaseFirestore.instance
          .collection('inventory')
          .doc(widget.groupId)
          .collection('items')
          .doc(skuController.text.trim());

      await docRef.set({
        'name': nameController.text.trim(),
        'sku': skuController.text.trim(),
        'quantity': double.parse(qtyController.text),
        'unit': unitController.text.trim(),
        'location': locationController.text.trim(),
        'notes': notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'deleted': false,
        'price': priceController.text.isNotEmpty
            ? double.parse(priceController.text)
            : 0.0,
        'coast': coastController.text.isNotEmpty
            ? double.parse(coastController.text)
            : 0.0,
        'isInStore': false,
        'imagesList': [],
      });

      await docRef.collection('movements').add({
        'type': 'in',
        'qty': double.parse(qtyController.text),
        'unit': unitController.text.trim(),
        'note': notesController.text.trim(),
        'createdBy':
            FirebaseAuth.instance.currentUser?.displayName ?? 'غير معروف',
        'createdAt': FieldValue.serverTimestamp(),
        'price': priceController.text.isNotEmpty
            ? double.parse(priceController.text)
            : 0.0,
        'coast': coastController.text.isNotEmpty
            ? double.parse(coastController.text)
            : 0.0,
      });

      setState(() => loading = false);
      Navigator.pop(context);
    }
  }

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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    searchUnits2();
    searchLocations2();
    print("Units >>> $units");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'إضافة صنف مخزني',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            TextButton.icon(
              onPressed: () async {
                nameController.clear();
                skuController.clear();
                qtyController.clear();
                unitController.clear();
                locationController.clear();
                notesController.clear();
                priceController.clear();
                // barcodeController.clear();
                T? getDynamicValue<T>(
                  Map<String, dynamic> data,
                  List<String> keys,
                ) {
                  for (String key in keys) {
                    if (data.containsKey(key) && data[key] != null) {
                      // Attempt to cast to the desired type, or convert if possible
                      if (T == String) {
                        return data[key].toString() as T;
                      } else if (T == double) {
                        return double.tryParse(data[key].toString()) as T?;
                      } else if (T == int) {
                        return int.tryParse(data[key].toString()) as T?;
                      } else {
                        return data[key] as T;
                      }
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
                final String format = scanResult['format'] ?? '';

                if (raw.isEmpty) {
                  _showError("لم يتم قراءة أي بيانات");
                  return;
                }

                print("RAW: $raw");
                print("FORMAT: $format");
                print("TYPE >>> ${raw.runtimeType}");
                // 🧠 1. محاولة تحليل JSON
                try {
                  final data = jsonDecode(raw);

                  if (data is Map<String, dynamic>) {
                    // Try multiple common keys for product name
                    final name =
                        getDynamicValue<String>(data, [
                          'name',
                          'title',
                          'product_name',
                        ]) ??
                        '';
                    // Try multiple common keys for barcode
                    final barcode =
                        getDynamicValue<String>(data, [
                          'barcode',
                          'upc',
                          'ean',
                          'sku',
                          'code',
                        ]) ??
                        '';
                    // Try multiple common keys for price
                    final price =
                        getDynamicValue<double>(data, [
                          'price',
                          'unit_price',
                          'item_price',
                        ]) ??
                        0.0;

                    print("JSON QR");
                    print('name: $name');
                    print('barcode: $barcode');
                    print('price: $price');

                    // 👉 Auto-fill
                    nameController.text = name;
                    skuController.text = barcode;
                    coastController.text = price.toString();

                    return;
                  }
                } catch (_) {}

                // 🟡 2. Barcode (أرقام فقط)
                if (RegExp(r'^[0-9]+$').hasMatch(raw)) {
                  print("Barcode Detected");

                  skuController.text = raw;

                  // 👉 ممكن تعمل search في Firebase هنا
                  return;
                }

                // 🌐 3. Link
                if (raw.startsWith("http")) {
                  print("Link Detected");

                  skuController.text = raw;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "تم قراءة رابط، تأكد من استخدامه بشكل صحيح",
                      ),
                    ),
                  );
                  return;
                }

                // 🟠 4. نص عادي
                print("Plain Text");

                nameController.text = raw;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("تم ملء الاسم من الكود، راجع البيانات"),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner, size: 24),
              label: const Text(
                'اضافة عن طريق مسح باركود',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                elevation: 6,
                shadowColor: Colors.black.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 50),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        /// بيانات الصنف
                        _sectionTitle('بيانات الصنف'),

                        const SizedBox(height: 12),

                        _buildField(
                          controller: nameController,
                          label: 'اسم الصنف',
                          icon: Icons.inventory_2,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'مطلوب' : null,
                        ),

                        const SizedBox(height: 12),

                        _buildField(
                          controller: skuController,
                          label: 'كود الصنف (barcode)',
                          icon: Icons.qr_code,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: coastController,
                          label: 'سعر التكلفة (اختياري)',
                          keyboard: TextInputType.number,
                          icon: Icons.attach_money,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            final parsed = double.tryParse(v);
                            if (parsed == null) return 'يجب أن يكون رقم';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: priceController,
                          label: 'سعر الصنف (اختياري)',
                          keyboard: TextInputType.number,
                          icon: Icons.attach_money,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            final parsed = double.tryParse(v);
                            if (parsed == null) return 'يجب أن يكون رقم';
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        /// الكمية والموقع
                        _sectionTitle('المخزون والموقع'),

                        const SizedBox(height: 12),

                        _buildField(
                          controller: qtyController,
                          label: 'الكمية',
                          icon: Icons.format_list_numbered,
                          keyboard: TextInputType.number,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'مطلوب' : null,
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: unitController,

                          validator: (v) =>
                              v == null || v.isEmpty ? 'مطلوب' : null,
                          decoration:
                              _inputDecoration(
                                'وحدة القياس (عدد، كيلو، متر...)',
                                Icons.straighten,
                              ).copyWith(
                                // إضافة زر لمسح النص أو فتح الخيارات الشائعة
                              ),
                          onTap: () async {
                            setState(() {
                              showUnits = !showUnits;
                              showLocations = !showUnits;
                            });

                            print("Units >>> $units");
                            if (!mounted) return;
                          },
                          onChanged: (v) {
                            unitController.text = v;
                          },
                        ),
                        showUnits ? _showUnitsPicker() : SizedBox.shrink(),
                        // دالة مساعدة لعرض الخيارات بشكل منظم
                        const SizedBox(height: 12),

                        /// الموقع (Autocomplete)
                        TextFormField(
                          controller: locationController,

                          validator: (v) =>
                              v == null || v.isEmpty ? 'مطلوب' : null,
                          decoration: _inputDecoration(
                            'الموقع (مخزن 1، مخزن A...)',
                            Icons.location_on,
                          ),
                          onTap: () async {
                            setState(() {
                              showLocations = !showLocations;
                              showUnits = !showLocations;
                            });

                            if (!mounted) return;
                          },
                          onChanged: (v) => locationController.text = v,
                        ),
                        showLocations
                            ? _showLocationsPicker()
                            : SizedBox.shrink(),

                        // دالة مساعدة لعرض الخيارات بشكل منظم
                        const SizedBox(height: 20),

                        /// ملاحظات
                        _sectionTitle('ملاحظات'),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: _inputDecoration(
                            'ملاحظات إضافية',
                            Icons.notes,
                          ),
                        ),

                        const SizedBox(height: 30),

                        /// زر الحفظ
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: loading ? null : saveItem,
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    widget.isFromInvoice
                                        ? 'إضافة الصنف'
                                        : 'حفظ الصنف',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
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

  bool isProcessing = false;

  @override
  void initState() {
    super.initState();

    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    controller.start(); // 👈 مهم جدًا يقلل مشاكل التهيئة
  }

  @override
  void dispose() {
    controller.stop(); // 👈 وقف الكاميرا أولًا
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (isProcessing || !mounted) return;

    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;

    final rawValue = barcode?.rawValue;

    if (rawValue == null || rawValue.trim().isEmpty) return;

    isProcessing = true;

    try {
      await controller.stop(); // 👈 وقف الكاميرا فورًا

      if (!mounted) return;

      Navigator.pop(context, {
        "raw": rawValue.trim(),
        "format": barcode?.format.name,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء قراءة الكود'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      isProcessing = false; // 👈 مهم جدًا
    }
  }

  @override
  void deactivate() {
    // 👇 مهم جدًا لمنع logs / re-init عند التنقل بين الصفحات
    controller.stop();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("مسح QR"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),

          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "وجّه الكاميرا نحو QR الخاص بالصنف",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
