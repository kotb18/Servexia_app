import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintenance/Store/store_model.dart';
import 'package:maintenance/Store/store_service.dart';

class StoreSetupScreen extends StatefulWidget {
  final String groupId;
  const StoreSetupScreen({super.key, required this.groupId});

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeService = StoreService();

  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();

  String _primaryColor = '#2196F3';
  bool _isLoading = false;

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
              _buildTextField(
                _slugController,
                'رابط المتجر (slug)',
                required: true,
                hint: 'مثال: my-store',
                prefix: const Text('https://'),
                suffix: const Text('.web.app'),
              ),
              _buildTextField(
                _descriptionController,
                'وصف المتجر',
                maxLines: 3,
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
                      : const Text('حفظ وإنشاء المتجر'),
                ),
              ),
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

    // التحقق من توفر الـ slug
    final slug = _slugController.text.trim().toLowerCase().replaceAll(' ', '-');
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
    }

    setState(() => _isLoading = true);

    try {
      final store = StoreModel(
        id: widget.groupId,
        groupId: widget.groupId, // TODO: من Firebase Auth
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        storeSlug: slug,
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
      );

      await _storeService.createOrUpdateStore(store);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('تم إنشاء المتجر!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('متجرك جاهز الآن. يمكنك مشاركته عبر الرابط:'),
                const SizedBox(height: 8),
                SelectableText(
                  store.storeUrl,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
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

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
