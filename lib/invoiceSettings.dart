import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoiceSettingsPage extends StatefulWidget {
  const InvoiceSettingsPage({
    super.key,
    required this.groupId,
    required this.items,
    required this.name,
    required this.phone,
    required this.address,
    required this.customerId,
    required this.isFromConstCustomers,
  });
  static const String routeName = '/invoiceSettings';
  final String groupId;
  final List<Map> items;
  final String name;
  final String phone;
  final String address;
  final String customerId;
  final bool isFromConstCustomers;

  @override
  State<InvoiceSettingsPage> createState() => _InvoiceSettingsPageState();
}

class _InvoiceSettingsPageState extends State<InvoiceSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  File? _logoFile;
  bool _isLoading = false;

  // خيارات التحكم في ظهور عناصر الفاتورة
  bool _showLogo = true;
  bool _showAddress = true;
  bool _showPhone = true;
  bool _showEmail = true;
  bool _showNotes = true;
  bool _showTax = true;
  bool _showDiscount = true;
  int? lastInvoiceNumber;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // تحميل الإعدادات من Firestore و SharedPreferences
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      // 1. تحميل بيانات المؤسسة من Firestore (بافتراض وجود مستند واحد للمؤسسة)
      final doc = await FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.groupId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['address'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _emailController.text = data['email'] ?? '';
        lastInvoiceNumber = data['lastInvoiceNumber'] ?? 0;
      }

      // 2. تحميل خيارات الظهور من SharedPreferences (محلياً)
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showLogo = prefs.getBool('showLogo${widget.groupId}') ?? true;
        _showAddress = prefs.getBool('showAddress${widget.groupId}') ?? true;
        _showPhone = prefs.getBool('showPhone${widget.groupId}') ?? true;
        _showEmail = prefs.getBool('showEmail${widget.groupId}') ?? true;
        _showNotes = prefs.getBool('showNotes${widget.groupId}') ?? true;
        _showTax = prefs.getBool('showTax${widget.groupId}') ?? true;
        _showDiscount = prefs.getBool('showDiscount${widget.groupId}') ?? true;

        String? logoPath = prefs.getString('logoPath${widget.groupId}');
        if (logoPath != null) {
          _logoFile = File(logoPath);
        }
      });
    } catch (e) {
      debugPrint("Error loading settings: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // اختيار الشعار من المعرض
  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logoFile = File(pickedFile.path);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logoPath${widget.groupId}', pickedFile.path);
    }
  }

  // حفظ الإعدادات
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. حفظ بيانات المؤسسة في Firestore
      await FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.groupId)
          .set({
            'name': _nameController.text,
            'address': _addressController.text,
            'phone': _phoneController.text,
            'email': _emailController.text,
            'updatedAt': FieldValue.serverTimestamp(),
            'showLogo': _showLogo,
            'showAddress': _showAddress,
            'showPhone': _showPhone,
            'showEmail': _showEmail,
            'showNotes': _showNotes,
            'showTax': _showTax,
            'showDiscount': _showDiscount,
            'lastInvoiceNumber': lastInvoiceNumber,
          });

      // 2. حفظ خيارات الظهور محلياً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('showLogo${widget.groupId}', _showLogo);
      await prefs.setBool('showAddress${widget.groupId}', _showAddress);
      await prefs.setBool('showPhone${widget.groupId}', _showPhone);
      await prefs.setBool('showEmail${widget.groupId}', _showEmail);
      await prefs.setBool('showNotes${widget.groupId}', _showNotes);
      await prefs.setBool('showTax${widget.groupId}', _showTax);
      await prefs.setBool('showDiscount${widget.groupId}', _showDiscount);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الإعدادات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الحفظ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, false);
        return false;
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إعدادات الفاتورة'),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('بيانات المؤســسة '),
                        _buildCompanyInfoFields(),
                        const SizedBox(height: 24),

                        _buildSectionTitle('شعار المؤســسة'),
                        _buildLogoPicker(),
                        const SizedBox(height: 24),

                        _buildSectionTitle('خيارات ظهور عناصر الفاتورة'),
                        _buildVisibilityToggles(),
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'حفظ كافة الإعدادات',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }

  Widget _buildCompanyInfoFields() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTextField(_nameController, 'اسم المؤسسة', Icons.business),
            const SizedBox(height: 12),
            _buildTextField(_addressController, 'العنوان', Icons.location_on),
            const SizedBox(height: 12),
            _buildTextField(
              _phoneController,
              'رقم الهاتف',
              Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _emailController,
              'البريد الإلكتروني',
              Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null,
    );
  }

  Widget _buildLogoPicker() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: _logoFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_logoFile!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.image, size: 50, color: Colors.grey),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اختر شعار المؤسسة ليظهر في أعلى الفاتورة'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('تحميل الشعار'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityToggles() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildSwitchTile(
            'إظهار الشعار',
            _showLogo,
            (v) => setState(() => _showLogo = v),
          ),
          _buildSwitchTile(
            'إظهار العنوان',
            _showAddress,
            (v) => setState(() => _showAddress = v),
          ),
          _buildSwitchTile(
            'إظهار الهاتف',
            _showPhone,
            (v) => setState(() => _showPhone = v),
          ),
          _buildSwitchTile(
            'إظهار البريد الإلكتروني',
            _showEmail,
            (v) => setState(() => _showEmail = v),
          ),
          _buildSwitchTile(
            'إظهار الملاحظات',
            _showNotes,
            (v) => setState(() => _showNotes = v),
          ),
          _buildSwitchTile(
            'إظهار الضريبة',
            _showTax,
            (v) => setState(() => _showTax = v),
          ),
          _buildSwitchTile(
            'إظهار الخصم',
            _showDiscount,
            (v) => setState(() => _showDiscount = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue.shade800,
    );
  }
}
