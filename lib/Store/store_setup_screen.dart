import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintenance/Store/store_model.dart';
import 'package:maintenance/Store/store_service.dart';

class StoreSetupScreen extends StatefulWidget {
  final String groupId;
  const StoreSetupScreen({
    super.key,
    required this.groupId,
    required this.isFromSettings,
  });
  final bool isFromSettings;
  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeService = StoreService();
  bool? _isClothes;

  final _nameController = TextEditingController();
  // final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _shippingFeeController = TextEditingController();

  getStoreData() async {
    final store = await _storeService.getStoreById(widget.groupId);
    if (store != null) {
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

  String _primaryColor = '#2196F3';
  bool _isLoading = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getStoreData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعداد المتجر الإلكتروني')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'معلومات المتجر الأساسية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _buildTextField(_nameController, 'اسم المتجر', required: true),
              /*  _buildTextField(
                _slugController,
                'رابط المتجر (slug)',
                required: true,
                hint: 'مثال: my-store',
                prefix: const Text('https://'),
                suffix: const Text('.web.app'),
              ), */
              _buildTextField(
                _descriptionController,
                'وصف المتجر',
                maxLines: 3,
              ),
              SizedBox(height: 12),
              _buildPriceField(),
              SizedBox(height: 12),
              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'هل هو متجر ملابس؟',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SegmentedButton<bool>(
                      emptySelectionAllowed: true,
                      segments: const [
                        ButtonSegment(value: true, label: Text('نعم')),
                        ButtonSegment(value: false, label: Text('لا')),
                      ],
                      selected: _isClothes == null ? {} : {_isClothes!},
                      onSelectionChanged: (value) {
                        setState(() {
                          _isClothes = value.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'معلومات التواصل',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                _phoneController,
                'رقم الهاتف',
                keyboardType: TextInputType.phone,
              ),
              _buildTextField(
                _whatsappController,
                'رقم الواتساب',
                keyboardType: TextInputType.phone,
              ),
              _buildTextField(
                _emailController,
                'البريد الإلكتروني',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 24),
              const Text(
                'الألوان والمظهر',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // اختيار اللون
              Wrap(
                spacing: 12,
                children:
                    [
                      '#2196F3',
                      '#F44336',
                      '#4CAF50',
                      '#FF9800',
                      '#9C27B0',
                      '#00BCD4',
                      '#E91E63',
                      '#795548',
                    ].map((color) {
                      final isSelected = _primaryColor == color;
                      return InkWell(
                        onTap: () => setState(() => _primaryColor = color),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _hexToColor(color),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveStore,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.isFromSettings
                              ? 'حفظ التغييرات'
                              : 'حفظ وإنشاء المتجر',
                        ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefix != null
              ? Padding(padding: const EdgeInsets.all(12), child: prefix)
              : null,
          suffixIcon: suffix != null
              ? Padding(padding: const EdgeInsets.all(12), child: suffix)
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: required
            ? (value) =>
                  value?.trim().isEmpty ?? true ? 'هذا الحقل مطلوب' : null
            : null,
      ),
    );
  }

  Future<void> _saveStore() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isClothes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار هل هو متجر ملابس أم لا')),
      );
      return;
    }

    // التحقق من توفر الـ slug
    /*     final slug = _slugController.text.trim().toLowerCase().replaceAll(' ', '-');
    final isAvailable = await _storeService.isSlugAvailable(slug);

    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذا الرابط مستخدم بالفعل، اختر رابطاً آخر'),
          ),
        );
      }
      return;
    } */

    setState(() => _isLoading = true);

    try {
      final store = StoreModel(
        id: widget.groupId,
        groupId: widget.groupId, // TODO: من Firebase Auth
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
        shippingFee: double.parse(
          _shippingFeeController.text,
        ), // <-- تعيين رسوم الشحن الافتراضية
      );

      await _storeService.createOrUpdateStore(store);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(
              widget.isFromSettings
                  ? 'تم تحديث الإعدادات!'
                  : 'تم إنشاء المتجر!',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isFromSettings
                      ? 'تم تحديث إعدادات متجرك بنجاح.'
                      : 'أصبح متجرك جاهز، يمكنك مشاركته الآن.',
                ),
                const SizedBox(height: 8),
                /* SelectableText(
                  store.storeUrl,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ), */
              ],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPriceField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
            ),
            child: const Text(
              'رسوم الشحن:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _shippingFeeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: _shippingFeeController.text,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
