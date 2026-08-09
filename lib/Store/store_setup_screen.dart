import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintenance/Store/store_model.dart';
import 'package:maintenance/Store/store_service.dart';

class StoreSetupScreen extends StatefulWidget {
  final String groupId;
  final bool isFromSettings;

  const StoreSetupScreen({
    super.key,
    required this.groupId,
    required this.isFromSettings,
  });

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeService = StoreService();
  bool? _isClothes;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _shippingFeeController = TextEditingController();

  String _primaryColor = '#2196F3';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _colorOptions = [
    {'hex': '#2196F3', 'name': 'أزرق'},
    {'hex': '#F44336', 'name': 'أحمر'},
    {'hex': '#4CAF50', 'name': 'أخضر'},
    {'hex': '#FF9800', 'name': 'برتقالي'},
    {'hex': '#9C27B0', 'name': 'بنفسجي'},
    {'hex': '#00BCD4', 'name': 'سماوي'},
    {'hex': '#E91E63', 'name': 'وردي'},
    {'hex': '#795548', 'name': 'بني'},
    {'hex': '#607D8B', 'name': 'رمادي'},
    {'hex': '#FFEB3B', 'name': 'أصفر'},
  ];

  @override
  void initState() {
    super.initState();
    getStoreData();
  }

  Future<void> getStoreData() async {
    final store = await _storeService.getStoreById(widget.groupId);
    if (store != null && mounted) {
      setState(() {
        _nameController.text = store.name;
        _descriptionController.text = store.description ?? '';
        _phoneController.text = store.phone ?? '';
        _whatsappController.text = store.whatsapp ?? '';
        _emailController.text = store.email ?? '';
        _primaryColor = store.primaryColor;
        _isClothes = store.isClothes;
        _shippingFeeController.text = store.shippingFee.toString();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _shippingFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('إعدادات المتجر'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ✅ معاينة المتجر
            _buildPreviewCard(),

            const SizedBox(height: 16),

            // ✅ معلومات المتجر الأساسية
            _buildSectionCard(
              icon: Icons.store_outlined,
              title: 'معلومات المتجر الأساسية',
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'اسم المتجر',
                  required: true,
                  icon: Icons.business,
                ),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'وصف المتجر',
                  maxLines: 3,
                  icon: Icons.description_outlined,
                  hint: 'وصف قصير يظهر للعملاء...',
                ),
                _buildShippingFeeField(),
                const SizedBox(height: 8),
                _buildClothesToggle(),
              ],
            ),

            const SizedBox(height: 16),

            // ✅ معلومات التواصل
            _buildSectionCard(
              icon: Icons.contact_phone_outlined,
              title: 'معلومات التواصل',
              children: [
                _buildTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  keyboardType: TextInputType.phone,
                  icon: Icons.phone,
                ),
                _buildTextField(
                  controller: _whatsappController,
                  label: 'رقم الواتساب',
                  keyboardType: TextInputType.phone,
                  icon: Icons.chat_bubble_outline,
                ),
                _buildTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  keyboardType: TextInputType.emailAddress,
                  icon: Icons.email_outlined,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ✅ الألوان والمظهر
            _buildSectionCard(
              icon: Icons.palette_outlined,
              title: 'الألوان والمظهر',
              children: [
                const Text(
                  'اختر لون المتجر الأساسي:',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                _buildColorPicker(),
              ],
            ),

            const SizedBox(height: 32),

            // ✅ زر الحفظ
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveStore,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  widget.isFromSettings ? 'حفظ التغييرات' : 'حفظ وإنشاء المتجر',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hexToColor(_primaryColor),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────
  // 🎨 معاينة المتجر
  // ───────────────────────────────────────────────
  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _hexToColor(_primaryColor),
            _hexToColor(_primaryColor).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _hexToColor(_primaryColor).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.isEmpty
                          ? 'متجرك'
                          : _nameController.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isClothes == true ? 'متجر ملابس' : 'متجر عام',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  'رسوم الشحن: ${_shippingFeeController.text.isEmpty ? '0' : _shippingFeeController.text} ',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────
  // 📦 بطاقة قسم
  // ───────────────────────────────────────────────
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _hexToColor(_primaryColor), size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────
  // 📝 حقل نصي محسّن
  // ───────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: (value) {
          if (label == 'اسم المتجر') setState(() {});
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _hexToColor(_primaryColor), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: required
            ? (value) =>
                  value?.trim().isEmpty ?? true ? 'هذا الحقل مطلوب' : null
            : null,
      ),
    );
  }

  // ───────────────────────────────────────────────
  // 💰 حقل رسوم الشحن
  // ───────────────────────────────────────────────
  Widget _buildShippingFeeField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _hexToColor(_primaryColor).withOpacity(0.1),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_shipping,
                  color: _hexToColor(_primaryColor),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'رسوم الشحن',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _shippingFeeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '0.00',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                suffixText: '',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────
  // 👕 تبديل متجر الملابس
  // ───────────────────────────────────────────────
  Widget _buildClothesToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.checkroom, color: _hexToColor(_primaryColor), size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'متجر ملابس',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  'تفعيل خيارات المقاسات والألوان',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isClothes ?? false,
            onChanged: (value) {
              setState(() {
                _isClothes = value;
              });
            },
            activeColor: _hexToColor(_primaryColor),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────
  // 🎨 منتقي الألوان
  // ───────────────────────────────────────────────
  Widget _buildColorPicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _colorOptions.map((colorOption) {
        final hex = colorOption['hex'] as String;
        final name = colorOption['name'] as String;
        final isSelected = _primaryColor == hex;
        final color = _hexToColor(hex);

        return Tooltip(
          message: name,
          child: InkWell(
            onTap: () => setState(() => _primaryColor = hex),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: Colors.black87, width: 3)
                    : Border.all(color: Colors.transparent, width: 3),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 24)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ───────────────────────────────────────────────
  // 💾 حفظ المتجر
  // ───────────────────────────────────────────────
  Future<void> _saveStore() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isClothes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تحديد نوع المتجر')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final store = StoreModel(
        id: widget.groupId,
        groupId: widget.groupId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        storeSlug: 'slug',
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        whatsapp: _whatsappController.text.trim().isEmpty
            ? null
            : _whatsappController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        primaryColor: _primaryColor,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        settings: StoreSettings(),
        isClothes: _isClothes ?? false,
        shippingFee: double.tryParse(_shippingFeeController.text) ?? 0.0,
      );

      await _storeService.createOrUpdateStore(store);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: _hexToColor(_primaryColor)),
                const SizedBox(width: 10),
                Text(widget.isFromSettings ? 'تم التحديث!' : 'تم الإنشاء!'),
              ],
            ),
            content: Text(
              widget.isFromSettings
                  ? 'تم تحديث إعدادات متجرك بنجاح.'
                  : 'أصبح متجرك جاهزاً للاستخدام!',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('تم'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
