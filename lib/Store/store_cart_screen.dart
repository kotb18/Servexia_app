import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'store_checkout_screen.dart';
import 'package:maintenance/imageControl/platform_image.dart';

class StoreCartScreen extends StatefulWidget {
  final String groupId;
  final double shippingFee;
  final bool makeSetStateOnCartChange;

  const StoreCartScreen({
    super.key,
    required this.groupId,
    required this.shippingFee,
    required this.makeSetStateOnCartChange,
  });

  @override
  State<StoreCartScreen> createState() => _StoreCartScreenState();
}

class _StoreCartScreenState extends State<StoreCartScreen> {
  final cart = StoreCartService();
  void makeSetStateOnCartChange() async {
    await cart.loadCart(widget.groupId);
    if (widget.makeSetStateOnCartChange) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    makeSetStateOnCartChange();
    print(
      'StoreHomeScreen initialized with groupId: ${widget.groupId}, shippingFee: ${widget.shippingFee}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سلة المشتريات')),
      body: cart.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'السلة فارغة',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Stack(
                        children: [
                          Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // الصورة
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: item.product.imagesList.isNotEmpty
                                          ? WebImage(
                                              src:
                                                  item.product.imagesList.first,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.product.effectiveStorePrice.toStringAsFixed(2)} ',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (item.product.hasDiscount)
                                          Text(
                                            '${item.product.price.toStringAsFixed(2)} ',
                                            style: const TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (item.selectedColor != null ||
                                            item.selectedSize != null)
                                          Text(
                                            'اللون: ${item.selectedColor ?? "غير محدد"} | المقاس: ${item.selectedSize ?? "غير محدد"}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
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
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        onPressed: item.quantity > 1
                                            ? () async {
                                                cart.updateQuantity(
                                                  item.product.sku,
                                                  item.quantity - 1,
                                                  attributes:
                                                      item.selectedAttributes,
                                                );
                                                await cart.saveCart(
                                                  widget.groupId,
                                                );
                                                setState(() {});
                                              }
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
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        onPressed:
                                            item.quantity <
                                                item.product.quantity
                                            ? () async {
                                                cart.updateQuantity(
                                                  item.product.sku,
                                                  item.quantity + 1,
                                                  attributes:
                                                      item.selectedAttributes,
                                                );
                                                await cart.saveCart(
                                                  widget.groupId,
                                                );
                                                setState(() {});
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            top: 0,
                            child: IconButton.filled(
                              style: ButtonStyle(
                                padding: WidgetStateProperty.all(
                                  const EdgeInsets.all(4),
                                ),
                                minimumSize: WidgetStateProperty.all(Size.zero),
                                shape: WidgetStateProperty.all(
                                  const CircleBorder(),
                                ),
                              ),
                              onPressed: () {
                                if (cart.items.length == 1) {
                                  removeCartKey();
                                  Navigator.pop(context);
                                  return;
                                }
                                cart.removeFromCart(
                                  item.product.sku,
                                  attributes: item.selectedAttributes,
                                );
                                cart.saveCart(widget.groupId);
                                setState(() {});
                              },
                              icon: Icon(
                                Icons.close,
                                color: Colors.red.shade400,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // ملخص السلة
                        _buildSummaryRow(
                          context,
                          'المجموع الفرعي',
                          cart.subtotal,
                        ),
                        _buildSummaryRow(
                          context,
                          'مصاريف الشحن',
                          widget.shippingFee,
                        ),
                        const Divider(),
                        _buildSummaryRow(
                          context,
                          'الإجمالي',
                          cart.subtotal + widget.shippingFee,
                          isTotal: true,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StoreCheckoutScreen(
                                    cartService: cart,
                                    groupId: widget.groupId,
                                    shippingFee: widget.shippingFee,
                                  ),
                                ),
                              );
                            },
                            child: const Text('إتمام الشراء'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

  Widget _buildSummaryRow(
    BuildContext context, // <-- أضف هذا
    String label,
    double amount, {
    bool isTotal = false,
  }) {
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
            '${amount.toStringAsFixed(2)} ',
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
