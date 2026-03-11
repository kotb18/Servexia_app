import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddInventoryItemScreen extends StatefulWidget {
  final String groupId;
  const AddInventoryItemScreen({super.key, required this.groupId});
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

  bool loading = false;

  @override
  void dispose() {
    nameController.dispose();
    skuController.dispose();
    qtyController.dispose();
    unitController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  /// 🔎 البحث عن المواقع
  Future<List<String>> searchLocations(String query) async {
    if (query.isEmpty) return [];

    final snap = await FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.groupId)
        .collection('items')
        .orderBy('location')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(10)
        .get();

    final set = <String>{};

    for (var doc in snap.docs) {
      if (doc['location'] != null) {
        set.add(doc['location']);
      }
    }

    return set.toList();
  }

  /// 🔎 البحث عن الوحدات
  Future<List<String>> searchUnits(String query) async {
    if (query.isEmpty) return [];

    final snap = await FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.groupId)
        .collection('items')
        .orderBy('unit')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(10)
        .get();

    final set = <String>{};

    for (var doc in snap.docs) {
      if (doc['unit'] != null) {
        set.add(doc['unit']);
      }
    }

    return set.toList();
  }

  Future<void> saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final docRef = FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.groupId)
        .collection('items')
        .doc();

    await docRef.set({
      'name': nameController.text.trim(),
      'sku': skuController.text.trim(),
      'quantity': int.parse(qtyController.text),
      'unit': unitController.text.trim(),
      'location': locationController.text.trim(),
      'notes': notesController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'deleted': false,
    });

    await docRef.collection('movements').add({
      'type': 'in',
      'qty': int.parse(qtyController.text),
      'unit': unitController.text.trim(),
      'note': '',
      'createdBy':
          FirebaseAuth.instance.currentUser?.displayName ?? 'غير معروف',
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => loading = false);
    Navigator.pop(context);
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
        padding: const EdgeInsets.all(16),
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
                    validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                  ),

                  const SizedBox(height: 12),

                  _buildField(
                    controller: skuController,
                    label: 'كود الصنف (SKU)',
                    icon: Icons.qr_code,
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
                    validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                  ),

                  const SizedBox(height: 12),

                  /// وحدة القياس (Autocomplete)
                  Autocomplete<String>(
                    optionsBuilder: (textEditingValue) async {
                      if (textEditingValue.text == '') {
                        return const Iterable<String>.empty();
                      }

                      final results = await searchUnits(textEditingValue.text);
                      return results;
                    },
                    onSelected: (value) {
                      unitController.text = value;
                    },
                    fieldViewBuilder: (context, controller, focusNode, _) {
                      controller.text = unitController.text;

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'مطلوب' : null,
                        decoration: _inputDecoration(
                          'وحدة القياس (عدد، كيلو، متر...)',
                          Icons.straighten,
                        ),
                        onChanged: (v) => unitController.text = v,
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  /// الموقع (Autocomplete)
                  Autocomplete<String>(
                    optionsBuilder: (textEditingValue) async {
                      if (textEditingValue.text == '') {
                        return const Iterable<String>.empty();
                      }

                      final results = await searchLocations(
                        textEditingValue.text,
                      );
                      return results;
                    },
                    onSelected: (value) {
                      locationController.text = value;
                    },
                    fieldViewBuilder: (context, controller, focusNode, _) {
                      controller.text = locationController.text;

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'مطلوب' : null,
                        decoration: _inputDecoration(
                          'الموقع (مخزن 1، مخزن A...)',
                          Icons.location_on,
                        ),
                        onChanged: (v) => locationController.text = v,
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  /// ملاحظات
                  _sectionTitle('ملاحظات'),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: _inputDecoration('ملاحظات إضافية', Icons.notes),
                  ),

                  const SizedBox(height: 30),

                  /// زر الحفظ
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: loading ? null : saveItem,
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'حفظ الصنف',
                              style: TextStyle(fontSize: 16),
                            ),
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
