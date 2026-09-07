import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maintenance/imageControl/platform_image.dart';

class StoreCartScreen extends StatefulWidget {
  final String groupId;
  final double shippingFee;
  final bool makeSetStateOnCartChange;
  final String deviceTokrn;

  const StoreCartScreen({
    super.key,
    required this.groupId,
    required this.shippingFee,
    required this.makeSetStateOnCartChange,
    required this.deviceTokrn,
  });

  @override
  State<StoreCartScreen> createState() => _StoreCartScreenState();
}

class _StoreCartScreenState extends State<StoreCartScreen> {
  final cart = StoreCartService();

  // 🆕 حالة التحميل — دي كانت ناقصة!
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCart();

    debugPrint(
      'StoreCartScreen initialized with groupId: ${widget.groupId}, '
      'shippingFee: ${widget.shippingFee}',
    );
  }

  /// 🆕 تحميل السلة + إعادة رسم الواجهة
  Future<void> _loadCart() async {
    try {
      await cart.loadCart(widget.groupId);
    } catch (e) {
      debugPrint('❌ Error loading cart: $e');
    }

    if (!mounted) return;

    setState(() => _isLoading = false);
  }

  /// 🆕 Helper موحد لتحديث السلة والحفظ — بدل التكرار
  Future<void> _updateCart() async {
    await cart.saveCart(widget.groupId);
    if (!mounted) return;
    setState(() {});
  }

  /// 🆕 حذف منتج من السلة
  Future<void> _removeItem(item) async {
    if (cart.items.length == 1) {
      await removeCartKey();
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    cart.removeFromCart(item.product.sku, attributes: item.selectedAttributes);
    await _updateCart();
  }

  /// 🆕 تغيير الكمية
  Future<void> _changeQuantity(item, int newQuantity) async {
    if (newQuantity < 1 || newQuantity > item.product.quantity) return;

    cart.updateQuantity(
      item.product.sku,
      newQuantity,
      attributes: item.selectedAttributes,
    );
    await _updateCart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سلة المشتريات')),
      // 🆕 Loader أثناء التحميل — مش هتشوف شاشة فاضية تاني
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : cart.isEmpty
          ? _buildEmptyState()
          : _buildCartContent(),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 🛒 محتوى السلة
  /// ═══════════════════════════════════════════════════════════════════
  Widget _buildCartContent() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return _buildCartItem(item);
            },
          ),
        ),
        _buildCheckoutSummary(),
      ],
    );
  }

  Widget _buildCartItem(item) {
    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // الصورة
                SizedBox(
                  width: 80,
                  height: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.product.imagesList.isNotEmpty
                        ? WebImage(
                            src: item.product.imagesList.first,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),

                // المعلومات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.product.effectiveStorePrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.product.hasDiscount)
                        Text(
                          '${item.product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      if (item.selectedColor != null ||
                          item.selectedSize != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'اللون: ${item.selectedColor ?? "غير محدد"} | '
                            'المقاس: ${item.selectedSize ?? "غير محدد"}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // التحكم في الكمية
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: item.quantity > 1
                          ? () => _changeQuantity(item, item.quantity - 1)
                          : null,
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: item.quantity < item.product.quantity
                          ? () => _changeQuantity(item, item.quantity + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // زرار الحذف
        Positioned(
          left: 10,
          top: 0,
          child: IconButton.filled(
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
              minimumSize: WidgetStateProperty.all(Size.zero),
              shape: WidgetStateProperty.all(const CircleBorder()),
              backgroundColor: WidgetStateProperty.all(Colors.white),
              elevation: WidgetStateProperty.all(2),
            ),
            onPressed: () => _removeItem(item),
            icon: Icon(Icons.close, color: Colors.red.shade400, size: 20),
          ),
        ),
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 💰 ملخص الطلب + زرار إتمام الشراء
  /// ═══════════════════════════════════════════════════════════════════
  Widget _buildCheckoutSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildSummaryRow('المجموع الفرعي', cart.subtotal),
            _buildSummaryRow('مصاريف الشحن', widget.shippingFee),
            const Divider(),
            _buildSummaryRow(
              'الإجمالي',
              cart.subtotal + widget.shippingFee,
              isTotal: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _goToCheckout,
                icon: const Icon(Icons.payment),
                label: const Text(
                  'إتمام الشراء',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToCheckout() {
    context.push(
      Uri(
        path: '/shop/${Uri.encodeComponent(widget.groupId)}/checkout',
        queryParameters: {
          'shippingFee': widget.shippingFee.toString(),
          'deviceToken': widget.deviceTokrn,
        },
      ).toString(),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 🔔 الحالة الفارغة
  /// ═══════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'السلة فارغة',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف منتجات من المتجر أولاً',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 🔧 HELPERS
  /// ═══════════════════════════════════════════════════════════════════
  Future<void> removeCartKey() async {
    final prefs = await SharedPreferences.getInstance();
    String cartKey = FirebaseAuth.instance.currentUser != null
        ? 'store_cart_${FirebaseAuth.instance.currentUser!.uid}'
        : 'store_cart_guest';
    final key = '${cartKey}_${widget.groupId}';

    await prefs.remove(key);
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image, color: Colors.grey.shade400),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
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
            '${amount.toStringAsFixed(2)}',
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
}
