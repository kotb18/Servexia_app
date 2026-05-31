import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'package:maintenance/Store/inventory_store_service.dart';
import 'package:maintenance/Store/store_cart_screen.dart';
import 'package:maintenance/Store/store_product_detail_screen.dart';
import 'package:share_plus/share_plus.dart';

class StoreHomeScreen extends StatefulWidget {
  final String groupId;
  final String storeName;
  final bool isPreview;

  const StoreHomeScreen({
    super.key,
    required this.groupId,
    required this.storeName,
    this.isPreview = false,
  });

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  final _service = InventoryStoreService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // توليد لينك المتجر
  String _generateStoreLink() {
    // اللينك الأساسي للـ Hosting
    const baseUrl = 'https://maintenance-b7282.web.app';

    // لو عايز لينك مباشر بالـ subdomain (مستقبلاً)
    // return 'https://${widget.groupId}.web.app';

    // دلوقتي بالـ path
    return '$baseUrl/shop/${widget.groupId}';
  }

  // نسخ اللينك للـ Clipboard
  Future<void> _copyLinkToClipboard() async {
    final link = _generateStoreLink();
    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ اللينك'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // مشاركة اللينك
  Future<void> _shareStoreLink() async {
    final link = _generateStoreLink();

    await Share.share(
      'تفضل متجر ${widget.storeName} على Maintenance App\n$link',
      subject: 'متجر ${widget.storeName}',
    );
  }

  // عرض BottomSheet للمشاركة
  void _showShareOptions() {
    final link = _generateStoreLink();

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
              'مشاركة المتجر',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              widget.storeName,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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
                  _shareStoreLink();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName),
        actions: [
          // ✅ زر المشاركة الجديد
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة المتجر',
            onPressed: _showShareOptions,
          ),
          // زر السلة
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoreCartScreen(groupId: widget.groupId),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث في المنتجات...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // المنتجات
          Expanded(
            child: StreamBuilder<List<InventoryItemModel>>(
              stream: _service.getStoreItems(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('خطأ: ${snapshot.error}'));
                }

                final items = snapshot.data ?? [];

                final filtered = _searchQuery.isEmpty
                    ? items
                    : items.where((item) {
                        final query = _searchQuery.toLowerCase();
                        return item.name.toLowerCase().contains(query) ||
                            item.sku.toLowerCase().contains(query);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد منتجات متاحة',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900
                        ? 4
                        : constraints.maxWidth > 600
                        ? 3
                        : 2;

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _buildProductCard(item);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(InventoryItemModel item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreProductDetailScreen(
              item: item,
              groupId: widget.groupId,
              isPreview: widget.isPreview,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: item.imagesList.isNotEmpty
                        ? Image.network(
                            item.imagesList.first,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  if (item.hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
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
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.effectiveStorePrice.toStringAsFixed(2)} ج.م',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              if (item.hasDiscount)
                                Text(
                                  '${item.price.toStringAsFixed(2)} ج.م',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item.isInStock && !widget.isPreview)
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: FittedBox(
                              child: IconButton(
                                onPressed: () {
                                  // إضافة للسلة
                                },
                                icon: const Icon(Icons.add_shopping_cart),
                                style: IconButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image, size: 48, color: Colors.grey),
      ),
    );
  }
}
