import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:maintenance/Store/store_order_model.dart';
import 'package:maintenance/Store/store_order_service.dart';
import 'package:maintenance/Store/store_order_success_screen.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class StoreCheckoutScreen extends StatefulWidget {
  final StoreCartService cartService;
  final String groupId;
  final double shippingFee;

  const StoreCheckoutScreen({
    super.key,
    required this.cartService,
    required this.groupId,
    required this.shippingFee,
  });

  @override
  State<StoreCheckoutScreen> createState() => _StoreCheckoutScreenState();
}

class _StoreCheckoutScreenState extends State<StoreCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderService = StoreOrderService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _governorateController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentMethod _selectedPayment = PaymentMethod.cashOnDelivery;
  String _fullPhone = '';
  String _fullWhatsapp = '';
  String _countryValue = '';
  String _stateValue = '';
  String _cityValue = '';
  bool _isLoading = false;

  List<TextEditingController> get _controllers => [
    _nameController,
    _phoneController,
    _emailController,
    _whatsappController,
    _governorateController,
    _cityController,
    _areaController,
    _streetController,
    _buildingController,
    _floorController,
    _apartmentController,
    _landmarkController,
    _notesController,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.cartService.subtotal;
    final total = subtotal + widget.shippingFee;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'إتمام الطلب',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _buildOrderSummary(subtotal, total),
                    const SizedBox(height: 18),
                    _buildSection('بيانات التواصل', Icons.person_outline, [
                      _buildTextField(
                        _nameController,
                        'الاسم بالكامل',
                        required: true,
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: _buildPhoneField(
                          controller: _phoneController,
                          label: 'رقم الهاتف',
                          required: true,
                          onChanged: (value) =>
                              _fullPhone = value.completeNumber,
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: _buildPhoneField(
                          controller: _whatsappController,
                          label: 'رقم الواتساب (اختياري)',
                          onChanged: (value) =>
                              _fullWhatsapp = value.completeNumber,
                        ),
                      ),
                      _buildTextField(
                        _emailController,
                        'البريد الإلكتروني (اختياري)',
                        keyboardType: TextInputType.emailAddress,
                        validator: _emailValidator,
                      ),
                    ]),
                    const SizedBox(height: 18),
                    _buildSection('عنوان الشحن', Icons.location_on_outlined, [
                      _buildAddressPicker(),
                      _buildTextField(
                        _streetController,
                        'الشارع',
                        required: true,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _buildingController,
                              'العمارة',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(_floorController, 'الدور'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              _apartmentController,
                              'الشقة',
                            ),
                          ),
                        ],
                      ),
                      _buildTextField(_landmarkController, 'علامة مميزة'),
                      _buildTextField(
                        _notesController,
                        'ملاحظات إضافية',
                        maxLines: 3,
                      ),
                    ]),
                    const SizedBox(height: 18),
                    _buildSection(
                      'طريقة الدفع',
                      Icons.account_balance_wallet_outlined,
                      [_buildPaymentMethods()],
                    ),
                  ],
                ),
              ),
              _buildSubmitButton(total),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(double subtotal, double total) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _buildPriceRow('المجموع الفرعي', subtotal),
            _buildPriceRow('مصاريف الشحن', widget.shippingFee),
            const Divider(color: Colors.white38, height: 24),
            _buildPriceRow('الإجمالي', total, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    final style = TextStyle(
      color: Colors.white,
      fontSize: isTotal ? 19 : 14,
      fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${amount.toStringAsFixed(2)} ج.م', style: style),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          prefixIcon: required
              ? const Icon(Icons.star_outline, size: 18)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
        ),
        validator: validator ?? (required ? _requiredValidator : null),
      ),
    );
  }

  Widget _buildPhoneField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<PhoneNumber> onChanged,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntlPhoneField(
        controller: controller,
        initialCountryCode: 'EG',
        languageCode: 'ar',
        disableLengthCheck: false,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
        ),
        validator: required
            ? (phone) {
                return phone == null || phone.number.trim().isEmpty
                    ? 'هذا الحقل مطلوب'
                    : null;
              }
            : null,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildAddressPicker() {
    final decoration = BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE4E7EC)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CSCPickerPlus(
          layout: Layout.vertical,
          // defaultCountry: CscCountry.Egypt,
          showStates: true,
          showCities: true,
          flagState: CountryFlag.ENABLE,
          countryStateLanguage: CountryStateLanguage.arabic,
          cityLanguage: CityLanguage.native,
          countryDropdownLabel: 'البلد',
          stateDropdownLabel: 'المحافظة',
          cityDropdownLabel: 'المدينة',
          countrySearchPlaceholder: 'ابحث عن البلد',
          stateSearchPlaceholder: 'ابحث عن المحافظة',
          citySearchPlaceholder: 'ابحث عن المدينة',
          dropdownDecoration: decoration,
          disabledDropdownDecoration: decoration.copyWith(
            color: const Color(0xFFEFF1F4),
          ),
          selectedItemStyle: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
          dropdownHeadingStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
          dropdownItemStyle: const TextStyle(fontSize: 14),
          dropdownDialogRadius: 14,
          searchBarRadius: 12,
          onCountryChanged: (value) => setState(() {
            _countryValue = value;
            _stateValue = '';
            _cityValue = '';
            _governorateController.clear();
            _cityController.clear();
          }),
          onStateChanged: (value) => setState(() {
            _stateValue = value ?? '';
            _cityValue = '';
            _governorateController.text = _stateValue;
            _cityController.clear();
          }),
          onCityChanged: (value) => setState(() {
            _cityValue = value ?? '';
            _cityController.text = _cityValue;
          }),
        ),
        const SizedBox(height: 12),
        _buildTextField(_areaController, 'المنطقة أو الحي', required: true),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    final methods = <(PaymentMethod, String, IconData)>[
      (
        PaymentMethod.cashOnDelivery,
        'الدفع عند الاستلام',
        Icons.money_outlined,
      ),
      (
        PaymentMethod.bankTransfer,
        'تحويل بنكي',
        Icons.account_balance_outlined,
      ),
      (PaymentMethod.fawry, 'فوري', Icons.payment_outlined),
    ];

    return Column(
      children: methods
          .map(
            (method) => Card(
              elevation: 0,
              color: _selectedPayment == method.$1
                  ? Theme.of(context).colorScheme.primary.withOpacity(.08)
                  : const Color(0xFFF9FAFB),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: RadioListTile<PaymentMethod>(
                value: method.$1,
                groupValue: _selectedPayment,
                onChanged: (value) => setState(() => _selectedPayment = value!),
                title: Text(
                  method.$2,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                secondary: Icon(method.$3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSubmitButton(double total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _submitOrder,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _isLoading
                  ? 'جارٍ تنفيذ الطلب...'
                  : 'تأكيد الطلب • ${total.toStringAsFixed(2)} ج.م',
            ),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
        ? null
        : 'أدخل بريدًا إلكترونيًا صحيحًا';
  }

  Future<void> _removeCartKey() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final cartKey = user == null
        ? 'store_cart_guest'
        : 'store_cart_${user.uid}';
    await prefs.remove('${cartKey}_${widget.groupId}');
  }

  void _showError(String msg) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      title: "خطأ",
      desc: msg,
      btnOkOnPress: () {},
    ).show();
  }

  Future<void> _submitOrder() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.cartService.isEmpty) {
      _showMessage('السلة فارغة');
      return;
    }
    if (_phoneController.text.startsWith('0')) {
      _showError('لا تبدأ الرقم بـ 0 بعد كود الدولة');
      return;
    }
    if (_whatsappController.text.startsWith('0')) {
      _showError('لا تبدأ رقم الواتس بـ 0 بعد كود الدولة');
      return;
    }
    if (_countryValue.isEmpty || _stateValue.isEmpty || _cityValue.isEmpty) {
      _showMessage('يرجى اختيار البلد والمحافظة والمدينة');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('يرجى تسجيل الدخول أولًا لإتمام الطلب');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final subtotal = widget.cartService.subtotal;
      final order = StoreOrderModel(
        id: const Uuid().v4(),
        storeId: widget.groupId,
        customerId: user.uid,
        items: widget.cartService.items
            .map(
              (item) => OrderItem(
                productId: item.product.sku,
                inventoryItemId: item.product.sku,
                name: item.product.name,
                image: item.product.imagesList.isEmpty
                    ? null
                    : item.product.imagesList.first,
                price: item.product.effectiveStorePrice,
                quantity: item.quantity,
                selectedColor: item.selectedColor,
                selectedSize: item.selectedSize,
                total: item.total,
                selectedAttributes: item.selectedAttributes,
              ),
            )
            .toList(),
        customerInfo: CustomerInfo(
          name: _nameController.text.trim(),
          phone: _fullPhone.isEmpty ? _phoneController.text.trim() : _fullPhone,
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          whatsapp: _whatsappController.text.trim().isEmpty
              ? null
              : (_fullWhatsapp.isEmpty
                    ? _whatsappController.text.trim()
                    : _fullWhatsapp),
        ),
        shippingAddress: ShippingAddress(
          governorate: _governorateController.text.trim(),
          city: _cityController.text.trim(),
          area: _areaController.text.trim(),
          street: _streetController.text.trim(),
          building: _optional(_buildingController),
          floor: _optional(_floorController),
          apartment: _optional(_apartmentController),
          landmark: _optional(_landmarkController),
          notes: _optional(_notesController),
        ),
        paymentMethod: _selectedPayment,
        subtotal: subtotal,
        shippingFee: widget.shippingFee,
        total: subtotal + widget.shippingFee,
        notes: _optional(_notesController),
        createdAt: DateTime.now(),
        orderNumber: '',
      );

      final createdOrder = await _orderService.createOrder(order);
      await FirebaseFirestore.instance
          .collection('store_orders')
          .doc(createdOrder.id)
          .set({
            'customerId': order.customerId,
            'orderNumber': createdOrder.orderNumber,
          }, SetOptions(merge: true));
      await _removeCartKey();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StoreOrderSuccessScreen(order: createdOrder),
        ),
      );
    } catch (_) {
      if (mounted) _showMessage('تعذر تنفيذ الطلب. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}
