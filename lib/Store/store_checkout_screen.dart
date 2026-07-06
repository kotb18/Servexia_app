import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:maintenance/Store/store_order_model.dart';
import 'package:maintenance/Store/store_order_service.dart';
import 'package:maintenance/Store/store_order_success_screen.dart';
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

  // بيانات العميل
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();

  // عنوان الشحن
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
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.cartService.subtotal;
    final total = subtotal + widget.shippingFee;

    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الطلب')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ملخص الطلب
                    _buildOrderSummary(subtotal),
                    const SizedBox(height: 24),

                    // بيانات العميل
                    _buildSectionTitle('بيانات التواصل'),
                    _buildTextField(
                      _nameController,
                      'الاسم بالكامل',
                      required: true,
                    ),
                    _buildTextField(
                      _phoneController,
                      'رقم الهاتف',
                      required: true,
                      keyboardType: TextInputType.phone,
                    ),
                    _buildTextField(
                      _whatsappController,
                      'رقم الواتساب (اختياري)',
                      keyboardType: TextInputType.phone,
                    ),
                    _buildTextField(
                      _emailController,
                      'البريد الإلكتروني (اختياري)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),

                    // عنوان الشحن
                    _buildSectionTitle('عنوان الشحن'),
                    _buildTextField(
                      _governorateController,
                      'المحافظة',
                      required: true,
                    ),
                    _buildTextField(_cityController, 'المدينة', required: true),
                    _buildTextField(
                      _areaController,
                      'المنطقة/الحي',
                      required: true,
                    ),
                    _buildTextField(
                      _streetController,
                      'الشارع',
                      required: true,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_buildingController, 'عمارة'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(_floorController, 'دور'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(_apartmentController, 'شقة'),
                        ),
                      ],
                    ),
                    _buildTextField(_landmarkController, 'علامة مميزة'),
                    _buildTextField(
                      _notesController,
                      'ملاحظات إضافية',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // طريقة الدفع
                    _buildSectionTitle('طريقة الدفع'),
                    _buildPaymentMethods(),
                  ],
                ),
              ),
            ),

            // زر إتمام الطلب
            _buildSubmitButton(total),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(double subtotal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPriceRow('المجموع الفرعي', subtotal),
            _buildPriceRow('مصاريف الشحن', widget.shippingFee),
            const Divider(),
            _buildPriceRow(
              'الإجمالي',
              subtotal + widget.shippingFee,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: required
            ? (value) => value?.isEmpty ?? true ? 'هذا الحقل مطلوب' : null
            : null,
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final methods = [
      (PaymentMethod.cashOnDelivery, 'الدفع عند الاستلام', Icons.money),
      (PaymentMethod.bankTransfer, 'تحويل بنكي', Icons.account_balance),
      (PaymentMethod.fawry, 'فوري', Icons.payment),
    ];

    return Column(
      children: methods.map((method) {
        return RadioListTile<PaymentMethod>(
          title: Row(
            children: [
              Icon(method.$3),
              const SizedBox(width: 12),
              Text(method.$2),
            ],
          ),
          value: method.$1,
          groupValue: _selectedPayment,
          onChanged: (value) => setState(() => _selectedPayment = value!),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton(double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitOrder,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('تأكيد الطلب - ${total.toStringAsFixed(2)} ج.م'),
          ),
        ),
      ),
    );
  }

  Future<void> removeCartKey() async {
    final prefs = await SharedPreferences.getInstance();
    String cartKey = FirebaseAuth.instance.currentUser != null
        ? 'store_cart_${FirebaseAuth.instance.currentUser!.uid}'
        : 'store_cart_guest';
    final key = '${cartKey}_${widget.groupId}';

    await prefs.remove(key);
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.cartService.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('السلة فارغة')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final order = StoreOrderModel(
        id: const Uuid().v4(),
        storeId: widget.groupId,
        customerId: FirebaseAuth.instance.currentUser!.uid, // زائر
        items: widget.cartService.items
            .map(
              (item) => OrderItem(
                productId: item.product.sku,
                inventoryItemId: item.product.sku,
                name: item.product.name,
                image: item.product.imagesList.isNotEmpty
                    ? item.product.imagesList.first
                    : null,
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
          name: _nameController.text,
          phone: _phoneController.text,
          email: _emailController.text.isEmpty ? null : _emailController.text,
          whatsapp: _whatsappController.text.isEmpty
              ? null
              : _whatsappController.text,
        ),
        shippingAddress: ShippingAddress(
          governorate: _governorateController.text,
          city: _cityController.text,
          area: _areaController.text,
          street: _streetController.text,
          building: _buildingController.text.isEmpty
              ? null
              : _buildingController.text,
          floor: _floorController.text.isEmpty ? null : _floorController.text,
          apartment: _apartmentController.text.isEmpty
              ? null
              : _apartmentController.text,
          landmark: _landmarkController.text.isEmpty
              ? null
              : _landmarkController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        ),
        paymentMethod: _selectedPayment,
        subtotal: widget.cartService.subtotal,
        shippingFee: widget.shippingFee,
        total: widget.cartService.subtotal + widget.shippingFee,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdAt: DateTime.now(),
        orderNumber: '',
      );

      final createdOrder = await _orderService.createOrder(order);
      await FirebaseFirestore.instance
          .collection('store_orders')
          .doc(widget.groupId)
          .set({
            'customerId': order.customerId,
            'orderNumber': createdOrder.orderNumber,
          });
      removeCartKey();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StoreOrderSuccessScreen(order: createdOrder),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
