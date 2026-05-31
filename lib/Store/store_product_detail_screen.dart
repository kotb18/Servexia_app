import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'store_cart_screen.dart';

class StoreProductDetailScreen extends StatefulWidget {
  final InventoryItemModel item;
  final String groupId;
  final bool isPreview;

  const StoreProductDetailScreen({
    super.key,
    required this.item,
    required this.groupId,
    this.isPreview = false,
  });

  @override
  State<StoreProductDetailScreen> createState() =>
      _StoreProductDetailScreenState();
}

class _StoreProductDetailScreenState extends State<StoreProductDetailScreen> {
  int _currentImage = 0;
  int _quantity = 1;

  // ✅ توليد لينك المنتج
  String _generateProductLink() {
    const baseUrl = 'https://maintenance-b7282.web.app';
    return '$baseUrl/shop/${widget.groupId}/product/${widget.item.sku}';
  }

  // ✅ نسخ اللينك
  Future<void> _copyLinkToClipboard() async {
    final link = _generateProductLink();
    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ لينك المنتج'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ مشاركة اللينك
  Future<void> _shareProductLink() async {
    final link = _generateProductLink();

    await Share.share(
      '${widget.item.name}\n'
      'السعر: ${widget.item.effectiveStorePrice.toStringAsFixed(2)} \n'
      '$link',
      subject: widget.item.name,
    );
  }

  // ✅ عرض BottomSheet للمشاركة
  void _showShareOptions() {
    final link = _generateProductLink();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // شريط السحب
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'مشاركة المنتج',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              widget.item.name,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // عرض اللينك
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      link,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      _copyLinkToClipboard();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // زر المشاركة
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _shareProductLink();
                },
                icon: const Icon(Icons.share),
                label: const Text('مشاركة اللينك'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // زر إلغاء
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              // ✅ زر المشاركة المعدّل
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'مشاركة المنتج',
                onPressed: _showShareOptions,
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
                        '${item.effectiveStorePrice.toStringAsFixed(2)} ',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.hasDiscount) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${item.price.toStringAsFixed(2)} ',
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
          ? null
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
                builder: (_) => StoreCartScreen(groupId: widget.groupId),
              ),
            );
          },
        ),
      ),
    );
  }
}
