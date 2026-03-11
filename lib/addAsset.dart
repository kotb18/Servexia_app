import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

int? maxAssets;
int? currentAssetNumber;

class AddAssetScreen extends StatefulWidget {
  final String groupId;
  const AddAssetScreen({super.key, required this.groupId});
  static const String screenroute = 'addAsset';

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  String? selectedSite;
  String? selectedLocation;
  String? selectedAssetName;
  String? selectedAssetId;

  final _formKey = GlobalKey<FormState>();

  final siteController = TextEditingController();
  final locationController = TextEditingController();
  final assetNameController = TextEditingController();
  final assetNumberController = TextEditingController();

  bool loading = false;
  getVariables() async {
    final doc = await FirebaseFirestore.instance
        .collection('variables')
        .doc('kotb')
        .get();

    if (!doc.exists) {
      return;
    }

    final data = doc.data();

    maxAssets = data!['maxAssets'];
  }

  getCurrentAssetNumber() async {
    final snap = await FirebaseFirestore.instance
        .collection('assets')
        .doc(widget.groupId)
        .collection('items')
        .count()
        .get();

    currentAssetNumber = snap.count;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getVariables();
    getCurrentAssetNumber();
  }

  @override
  void dispose() {
    siteController.dispose();
    locationController.dispose();
    assetNameController.dispose();
    assetNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;
    if (maxAssets != null &&
        currentAssetNumber != null &&
        currentAssetNumber! >= maxAssets!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لقد وصلت الحد الأقصى للأصول المسموح بها. '),
        ),
      );
      return;
    }

    setState(() => loading = true);
    await FirebaseFirestore.instance
        .collection('assets')
        .doc(widget.groupId)
        .set({'groupId': widget.groupId});

    final assetRef = FirebaseFirestore.instance
        .collection('assets')
        .doc(widget.groupId)
        .collection('items')
        .doc();

    await assetRef.set({
      'id': assetRef.id,
      'site': siteController.text.trim(), // الموقع
      'location': locationController.text.trim(), // مكانه داخل الموقع
      'name': assetNameController.text.trim(), // اسم المعدة
      'number': assetNumberController.text.trim(), // رقم المعدة
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    setState(() => loading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة أصل'), centerTitle: true),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: loading ? null : _saveAsset,
              icon: const Icon(Icons.save),
              label: const Text('حفظ الأصل'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _sectionCard(
                      title: 'الموقع',
                      icon: Icons.location_city,
                      child: _siteDropdown(),
                    ),
                    _sectionCard(
                      title: 'المكان داخل الموقع',
                      icon: Icons.place,
                      child: _locationDropdown(),
                    ),
                    _sectionCard(
                      title: 'بيانات المعدة',
                      icon: Icons.precision_manufacturing,
                      child: Column(
                        children: [
                          _assetNameDropdown(),
                          const SizedBox(height: 12),
                          _assetNumberField(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _siteDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final sites = snap.data!.docs
            .map((e) => e['site'] as String)
            .toSet()
            .toList();

        return Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return sites; // 👈 تظهر أول ما تضغط
            }
            return sites.where(
              (name) => name.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              ),
            );
          },
          onSelected: (String selection) {
            siteController.text = selection; // نحفظه هنا
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textController, // 👈 مهم جدًا
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'الموقع',
                    hintText: 'مثال: مصنع القاهرة',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'أدخل الموقع' : null,
                  onChanged: (v) {
                    siteController.text = v; // 👈 لو كتب قيمة جديدة
                  },
                );
              },
        );
      },
    );
  }

  /// 🔽 المكان
  Widget _locationDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .where('site', isEqualTo: selectedSite)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final locations = snap.data!.docs
            .map((e) => e['location'] as String)
            .toSet()
            .toList();

        return Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return locations; // تظهر أول ما تضغط
            }
            return locations.where(
              (name) => name.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              ),
            );
          },
          onSelected: (String selection) {
            selectedLocation = selection;
            locationController.text = selection;
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textController, // 👈 المهم
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'المكان داخل الموقع',
                    hintText: 'الدور الأول - غرفة المولدات',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'أدخل المكان' : null,
                  onChanged: (v) {
                    selectedLocation = v;
                    locationController.text = v;
                  },
                );
              },
        );
      },
    );
  }

  Widget _assetNameDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .where('site', isEqualTo: selectedSite)
          .where('location', isEqualTo: selectedLocation)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final names = snap.data!.docs
            .map((e) => e['name'] as String)
            .toSet()
            .toList();

        return Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return names;
            }
            return names.where(
              (name) => name.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              ),
            );
          },
          onSelected: (String selection) {
            assetNameController.text = selection;
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'اسم المعدة',
                    hintText: 'مولد كهرباء',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'أدخل اسم المعدة' : null,
                  onChanged: (v) {
                    assetNameController.text = v;
                  },
                );
              },
        );
      },
    );
  }

  /// 🔽 رقم المعدة
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _assetNumberField() {
    return TextFormField(
      controller: assetNumberController,
      decoration: InputDecoration(
        labelText: 'رقم المعدة',
        hintText: 'GEN-001',
        prefixIcon: const Icon(Icons.numbers),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'أدخل رقم المعدة' : null,
    );
  }
}
