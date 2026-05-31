import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'store_cart_screen.dart';

class StoreProductDetailScreen extends StatefulWidget {
  final InventoryItemModel item;
  final String groupId; // <-- أضفناه
  final bool isPreview;

  const StoreProductDetailScreen({
    super.key,
    required this.item,
    required this.groupId, // <-- أضفناه
    this.isPreview = false, // <-- افتراضي false
  });

  @override
  State<StoreProductDetailScreen> createState() =>
      _StoreProductDetailScreenState();
}

class _StoreProductDetailScreenState extends State<StoreProductDetailScreen> {
  int _currentImage = 0;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: item.imagesList.isNotEmpty
                  ? CarouselSlider(
                      options: CarouselOptions(
                        height: 400,
                        viewportFraction: 1,
                        onPageChanged: (index, _) {
                          setState(() => _currentImage = index);
                        },
                      ),
                      items: item.imagesList.map((url) {
                        return Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        );
                      }).toList(),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, size: 100),
                    ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: مشاركة المنتج
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // السعر
                  Row(
                    children: [
                      Text(
                        '${item.effectiveStorePrice.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.hasDiscount) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${item.price.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(
                            fontSize: 16,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '-${item.discountPercentage?.toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // اسم المنتج
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // الوصف
                  if (item.storeDescription != null) ...[
                    const Text(
                      'الوصف',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item.storeDescription!),
                    const SizedBox(height: 24),
                  ],

                  // الكمية
                  const Text(
                    'الكمية',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _quantity < item.quantity
                            ? () => setState(() => _quantity++)
                            : null,
                      ),
                      const Spacer(),
                      Text(
                        'المتوفر: ${item.quantity} ${item.unit}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.isPreview
          ? null // <-- مفيش زر شراء في المعاينة
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: item.isInStock ? _addToCart : null,
                    icon: const Icon(Icons.shopping_cart),
                    label: Text(
                      item.isInStock
                          ? 'إضافة للسلة - ${(item.effectiveStorePrice * _quantity).toStringAsFixed(2)} ج.م'
                          : 'نفذت الكمية',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.isInStock ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _addToCart() {
    final cart = StoreCartService();
    cart.addToCart(widget.item, quantity: _quantity);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تمت الإضافة للسلة'),
        action: SnackBarAction(
          label: 'عرض السلة',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoreCartScreen(
                  groupId: widget.groupId, // <-- صححنا الخطأ هنا
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
