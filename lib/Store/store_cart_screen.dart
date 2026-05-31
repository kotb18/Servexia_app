import 'package:flutter/material.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'store_checkout_screen.dart';

class StoreCartScreen extends StatelessWidget {
  final String groupId;
  final double shippingFee;

  const StoreCartScreen({
    super.key,
    required this.groupId,
    this.shippingFee = 50,
  });

  @override
  Widget build(BuildContext context) {
    final cart = StoreCartService();

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
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // الصورة
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.product.imagesList.isNotEmpty
                                    ? Image.network(
                                        item.product.imagesList.first,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _buildPlaceholder(),
                                      )
                                    : _buildPlaceholder(),
                              ),
                              const SizedBox(width: 12),

                              // المعلومات
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      '${item.product.effectiveStorePrice.toStringAsFixed(2)} ج.م',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (item.product.hasDiscount)
                                      Text(
                                        '${item.product.price.toStringAsFixed(2)} ج.م',
                                        style: const TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
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
                                        ? () {
                                            cart.updateQuantity(
                                              item.product.sku,
                                              item.quantity - 1,
                                              attributes:
                                                  item.selectedAttributes,
                                            );
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
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed:
                                        item.quantity < item.product.quantity
                                        ? () {
                                            cart.updateQuantity(
                                              item.product.sku,
                                              item.quantity + 1,
                                              attributes:
                                                  item.selectedAttributes,
                                            );
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
                        _buildSummaryRow(context, 'مصاريف الشحن', shippingFee),
                        const Divider(),
                        _buildSummaryRow(
                          context,
                          'الإجمالي',
                          cart.subtotal + shippingFee,
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
                                    groupId: groupId,
                                    shippingFee: shippingFee,
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
}
