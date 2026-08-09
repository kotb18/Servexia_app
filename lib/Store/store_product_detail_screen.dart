import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:maintenance/imageControl/platform_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'package:maintenance/Store/store_model.dart';
import 'package:maintenance/Store/store_service.dart';
import 'store_cart_screen.dart';
import 'package:maintenance/signIn.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎨 DYNAMIC PRODUCT DETAIL SCREEN - Responsive Mobile & Web
/// ═══════════════════════════════════════════════════════════════════════════

class StoreProductDetailScreen extends StatefulWidget {
  final InventoryItemModel item;
  final String groupId;
  final bool isPreview;
  final double shippingFee;

  const StoreProductDetailScreen({
    super.key,
    required this.item,
    required this.groupId,
    this.isPreview = false,
    required this.shippingFee,
  });

  @override
  State<StoreProductDetailScreen> createState() =>
      _StoreProductDetailScreenState();
}

class _StoreProductDetailScreenState extends State<StoreProductDetailScreen> {
  final _storeService = StoreService();

  StoreModel? _store;
  bool _isLoadingStore = true;

  int _currentImage = 0;
  int _quantity = 1;
  bool _isAddingToCart = false;

  String? _selectedColor;
  String? _selectedSize;

  final List<Map<String, dynamic>> _availableColors = [
    {'name': 'أبيض', 'value': 'white', 'color': Colors.white, 'border': true},
    {'name': 'أسود', 'value': 'black', 'color': Colors.black87},
    {'name': 'رمادي', 'value': 'gray', 'color': Colors.grey},
    {'name': 'أحمر', 'value': 'red', 'color': Colors.red},
    {'name': 'أزرق', 'value': 'blue', 'color': Colors.blue},
    {'name': 'أخضر', 'value': 'green', 'color': Colors.green},
    {'name': 'أصفر', 'value': 'yellow', 'color': Colors.amber},
    {'name': 'برتقالي', 'value': 'orange', 'color': Colors.orange},
    {'name': 'بنفسجي', 'value': 'purple', 'color': Colors.purple},
    {'name': 'وردي', 'value': 'pink', 'color': Colors.pink},
    {'name': 'بني', 'value': 'brown', 'color': Colors.brown},
    {'name': 'بيج', 'value': 'beige', 'color': const Color(0xFFF5F5DC)},
    {'name': 'ذهبي', 'value': 'gold', 'color': const Color(0xFFFFD700)},
    {'name': 'فضي', 'value': 'silver', 'color': const Color(0xFFC0C0C0)},
  ];

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    try {
      final store = await _storeService.getStoreById(widget.groupId);
      if (mounted) {
        setState(() {
          _store = store;
          _isLoadingStore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStore = false);
    }
  }

  /// ─── Dynamic Theme Helpers ───
  Color get primaryColor => _store != null
      ? _hexToColor(_store!.primaryColor)
      : const Color(0xFF2196F3);

  Color get primaryColorLight => primaryColor.withOpacity(0.08);
  Color get primaryColorDark => HSLColor.fromColor(primaryColor)
      .withLightness(
        (HSLColor.fromColor(primaryColor).lightness - 0.15).clamp(0.0, 1.0),
      )
      .toColor();

  String get storeName => _store?.name ?? 'متجر';

  /// ─── Helpers ───
  Map<String, dynamic>? _getColorData(String colorValue) {
    try {
      return _availableColors.firstWhere((c) => c['value'] == colorValue);
    } catch (_) {
      return null;
    }
  }

  String _generateProductLink() {
    const baseUrl = 'https://maintenance-b7282.web.app';
    return '$baseUrl/shop/${widget.groupId}/product/${widget.item.sku}';
  }

  Future<void> _copyLinkToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _generateProductLink()));
    if (!mounted) return;
    _showSnackBar('✓ تم نسخ رابط المنتج', isSuccess: true);
  }

  Future<void> _shareProductLink() async {
    await Share.share(
      '${widget.item.name}\n'
      'السعر: ${widget.item.effectiveStorePrice.toStringAsFixed(2)}\n'
      '${_generateProductLink()}',
      subject: widget.item.name,
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: isSuccess
            ? Colors.green.shade700
            : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showShareBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'مشاركة المنتج',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.name,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _generateProductLink(),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: primaryColor),
                    onPressed: () {
                      Navigator.pop(context);
                      _copyLinkToClipboard();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _shareProductLink();
                },
                icon: const Icon(Icons.share),
                label: const Text(
                  'مشاركة اللينك',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🏗️ MAIN BUILD - Responsive Layout
  /// ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoadingStore) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 800;

    // 🎨 Product data
    final item = widget.item;
    final hasColors = item.colors != null && item.colors!.isNotEmpty;
    final hasSizes = item.sizes != null && item.sizes!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: isMobile
          ? _buildMobileLayout(item, hasColors, hasSizes)
          : _buildWebLayout(item, hasColors, hasSizes),
      bottomNavigationBar: isMobile
          ? _buildMobileBottomBar(item, hasColors, hasSizes)
          : null,
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 📱 MOBILE LAYOUT (Single Column)
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(
    InventoryItemModel item,
    bool hasColors,
    bool hasSizes,
  ) {
    return CustomScrollView(
      slivers: [
        _buildSliverImageAppBar(item),
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            transform: Matrix4.translationValues(0, -20, 0),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductHeader(item),
                  const SizedBox(height: 20),
                  if (hasColors) ...[
                    _buildColorsSection(item.colors!),
                    const SizedBox(height: 20),
                  ],
                  if (hasSizes) ...[
                    _buildSizesSection(item.sizes!),
                    const SizedBox(height: 20),
                  ],
                  _buildQuantitySelector(item),
                  const SizedBox(height: 24),
                  _buildAdditionalInfo(item),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 💻 WEB LAYOUT (Two Columns)
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildWebLayout(
    InventoryItemModel item,
    bool hasColors,
    bool hasSizes,
  ) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🖼️ Left: Image Gallery
                Expanded(flex: 5, child: _buildWebImageGallery(item)),
                const SizedBox(width: 40),
                // 📝 Right: Product Details
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductHeader(item),
                      const SizedBox(height: 24),
                      if (hasColors) ...[
                        _buildColorsSection(item.colors!),
                        const SizedBox(height: 24),
                      ],
                      if (hasSizes) ...[
                        _buildSizesSection(item.sizes!),
                        const SizedBox(height: 24),
                      ],
                      _buildQuantitySelector(item),
                      const SizedBox(height: 32),
                      _buildWebAddToCartButton(item, hasColors, hasSizes),
                      const SizedBox(height: 32),
                      _buildAdditionalInfo(item),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🖼️ IMAGE GALLERY (Mobile SliverAppBar)
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildSliverImageAppBar(InventoryItemModel item) {
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: _buildCircularButton(
        icon: Icons.arrow_back,
        onTap: () => Navigator.pop(context),
      ),
      actions: [
        _buildCircularButton(
          icon: Icons.share_outlined,
          onTap: _showShareBottomSheet,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildImageCarousel(item, height: 380),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🖼️ WEB IMAGE GALLERY
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildWebImageGallery(InventoryItemModel item) {
    return Column(
      children: [
        // Main Image
        Container(
          height: 500,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: item.imagesList.isNotEmpty
                ? WebImage(
                    src: item.imagesList[_currentImage],
                    width: double.infinity,
                    height: 500,
                    fit: BoxFit.contain,
                  )
                : _buildPlaceholder(),
          ),
        ),
        const SizedBox(height: 16),
        // Thumbnails
        if (item.imagesList.length > 1)
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: item.imagesList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final isSelected = _currentImage == index;
                return InkWell(
                  onTap: () => setState(() => _currentImage = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? primaryColor : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: WebImage(
                        src: item.imagesList[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🎠 IMAGE CAROUSEL (Shared)
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildImageCarousel(
    InventoryItemModel item, {
    required double height,
  }) {
    if (item.imagesList.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }

    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: height,
            viewportFraction: 1,
            enableInfiniteScroll: item.imagesList.length > 1,
            onPageChanged: (index, _) {
              setState(() => _currentImage = index);
            },
          ),
          items: item.imagesList.map((url) {
            return WebImage(
              src: url,
              width: double.infinity,
              height: height,
              fit: BoxFit.cover,
            );
          }).toList(),
        ),
        if (item.imagesList.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImage + 1} / ${item.imagesList.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (!item.isInStock)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Text(
                  'غير متوفر حالياً',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🏷️ PRODUCT HEADER (Name + Price)
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildProductHeader(InventoryItemModel item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Store badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: primaryColorLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            storeName,
            style: TextStyle(
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Product Name
        Text(
          item.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 16),

        // Price Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.effectiveStorePrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            if (item.hasDiscount) ...[
              Text(
                '${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'خصم ${item.discountPercentage?.toInt()}%',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),

        // Description
        if (item.storeDescription != null &&
            item.storeDescription!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'الوصف',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.storeDescription!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.7,
            ),
          ),
        ],
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🎨 COLORS SECTION
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildColorsSection(List<String> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'اختر اللون',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(width: 10),
            if (_selectedColor != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primaryColorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getColorData(_selectedColor!)?['name'] ?? _selectedColor!,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((colorValue) {
            final colorData = _getColorData(colorValue);
            if (colorData == null) return const SizedBox.shrink();
            final isSelected = _selectedColor == colorValue;
            final color = colorData['color'] as Color;

            return InkWell(
              onTap: () => setState(() {
                _selectedColor = isSelected ? null : colorValue;
              }),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColorLight : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: colorData['border'] == true
                            ? Border.all(color: Colors.grey.shade400, width: 1)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      colorData['name'] as String,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? primaryColorDark
                            : Colors.grey.shade700,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle, size: 18, color: primaryColor),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 📏 SIZES SECTION
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildSizesSection(List<String> sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'اختر المقاس',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(width: 10),
            if (_selectedSize != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primaryColorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_selectedSize',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: sizes.map((size) {
            final isSelected = _selectedSize == size;
            return InkWell(
              onTap: () => setState(() {
                _selectedSize = isSelected ? null : size;
              }),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  size,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🔢 QUANTITY SELECTOR
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildQuantitySelector(InventoryItemModel item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الكمية',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildQuantityButton(
                    icon: Icons.remove,
                    onTap: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  Container(
                    width: 50,
                    alignment: Alignment.center,
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildQuantityButton(
                    icon: Icons.add,
                    onTap: _quantity < item.quantity
                        ? () => setState(() => _quantity++)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'المتوفر: ${item.quantity} ${item.unit}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityButton({required IconData icon, VoidCallback? onTap}) {
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 20,
            color: isEnabled ? primaryColor : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// ℹ️ ADDITIONAL INFO
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildAdditionalInfo(InventoryItemModel item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلومات إضافية',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('رقم المنتج (SKU)', item.sku),
          const Divider(height: 24),
          _buildInfoRow('الوحدة', item.unit),
          const Divider(height: 24),
          _buildInfoRow(
            'التوفر',
            item.isInStock ? '✓ متوفر في المخزن' : '✗ غير متوفر',
            valueColor: item.isInStock
                ? Colors.green.shade700
                : Colors.red.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.grey.shade900,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 📱 MOBILE BOTTOM BAR
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildMobileBottomBar(
    InventoryItemModel item,
    bool hasColors,
    bool hasSizes,
  ) {
    final canAdd =
        item.isInStock &&
        !widget.isPreview &&
        (!hasColors || _selectedColor != null) &&
        (!hasSizes || _selectedSize != null);

    String btnText;
    if (_isAddingToCart) {
      btnText = 'جاري الإضافة...';
    } else if (!item.isInStock) {
      btnText = 'نفذت الكمية';
    } else if (hasColors && _selectedColor == null) {
      btnText = 'اختر اللون أولاً';
    } else if (hasSizes && _selectedSize == null) {
      btnText = 'اختر المقاس أولاً';
    } else {
      btnText =
          'إضافة للسلة - ${(item.effectiveStorePrice * _quantity).toStringAsFixed(2)} ر.س';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: canAdd ? _addToCart : null,
            icon: _isAddingToCart
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.shopping_bag_outlined),
            label: Text(
              btnText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: item.isInStock
                  ? primaryColor
                  : Colors.grey.shade400,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 💻 WEB ADD TO CART BUTTON
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildWebAddToCartButton(
    InventoryItemModel item,
    bool hasColors,
    bool hasSizes,
  ) {
    final canAdd =
        item.isInStock &&
        !widget.isPreview &&
        (!hasColors || _selectedColor != null) &&
        (!hasSizes || _selectedSize != null);

    String btnText;
    if (_isAddingToCart) {
      btnText = 'جاري الإضافة...';
    } else if (!item.isInStock) {
      btnText = 'نفذت الكمية';
    } else if (hasColors && _selectedColor == null) {
      btnText = 'اختر اللون أولاً';
    } else if (hasSizes && _selectedSize == null) {
      btnText = 'اختر المقاس أولاً';
    } else {
      btnText =
          'إضافة للسلة - ${(item.effectiveStorePrice * _quantity).toStringAsFixed(2)}';
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: canAdd ? _addToCart : null,
        icon: _isAddingToCart
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.shopping_bag_outlined, size: 22),
        label: Text(
          btnText,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: item.isInStock ? primaryColor : Colors.grey.shade400,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: primaryColor.withOpacity(0.4),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🔘 CIRCULAR ICON BUTTON (AppBar)
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.grey.shade800, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 64,
          color: Colors.grey.shade300,
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🛒 ADD TO CART LOGIC
  /// ═══════════════════════════════════════════════════════════════════════
  void _addToCart() async {
    if (FirebaseAuth.instance.currentUser == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Login(fromCheckout: true)),
      );
      if (result == true) _addToCart();
      return;
    }

    setState(() => _isAddingToCart = true);

    try {
      final cart = StoreCartService();
      await cart.loadCart(widget.groupId);
      cart.addToCart(
        widget.item,
        quantity: _quantity,
        selectedColor: _selectedColor,
        selectedSize: _selectedSize,
      );
      await cart.saveCart(widget.groupId);

      if (!mounted) return;

      String snackText = '✓ تمت إضافة ${_quantity}x "${widget.item.name}"';
      if (_selectedColor != null) {
        snackText += ' - اللون: ${_getColorData(_selectedColor!)!['name']}';
      }
      if (_selectedSize != null) snackText += ' - المقاس: $_selectedSize';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackText),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'عرض السلة',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreCartScreen(
                    groupId: widget.groupId,
                    makeSetStateOnCartChange: false,
                    shippingFee: widget.shippingFee,
                  ),
                ),
              );
            },
          ),
        ),
      );

      setState(() => _isAddingToCart = false);
    } catch (e) {
      setState(() => _isAddingToCart = false);
      if (!mounted) return;
      _showSnackBar('⚠ حدث خطأ: $e');
    }
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
