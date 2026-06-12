import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:maintenance/imageControl/platform_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'store_cart_screen.dart';
import 'package:maintenance/signIn.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎨 PREMIUM COMMERCE DESIGN SYSTEM - PRODUCT DETAIL
/// ═══════════════════════════════════════════════════════════════════════════
/// Design Philosophy: Premium Product Showcase with Smooth Interactions
/// - Elegant image carousel with smooth transitions
/// - Clear pricing hierarchy with discount highlighting
/// - Intuitive quantity selector
/// - Prominent call-to-action button
/// ═══════════════════════════════════════════════════════════════════════════

class AppColors {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF1E40AF); // Deep Blue - Trust
  static const Color secondaryGreen = Color(0xFF10B981); // Green - Success
  static const Color accentOrange = Color(0xFFF97316); // Orange - Offers
  static const Color destructiveRed = Color(0xFFDC2626); // Red - Errors

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF3F4F6); // Background
  static const Color borderGray = Color(0xFFE5E7EB); // Borders
  static const Color mediumGray = Color(0xFF6B7280); // Secondary Text
  static const Color darkGray = Color(0xFF111827); // Primary Text

  // Semantic Colors
  static const Color success = secondaryGreen;
  static const Color warning = accentOrange;
  static const Color error = destructiveRed;
}

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
  bool _isAddingToCart = false;

  String _generateProductLink() {
    const baseUrl = 'https://maintenance-b7282.web.app';
    return '$baseUrl/shop/${widget.groupId}/product/${widget.item.sku}';
  }

  Future<void> _copyLinkToClipboard() async {
    final link = _generateProductLink();
    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ تم نسخ لينك المنتج'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _shareProductLink() async {
    final link = _generateProductLink();

    await Share.share(
      '${widget.item.name}\n'
      'السعر: ${widget.item.effectiveStorePrice.toStringAsFixed(2)} ج.م\n'
      '$link',
      subject: widget.item.name,
    );
  }

  void _showShareOptions() {
    final link = _generateProductLink();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'مشاركة المنتج',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.darkGray,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Product Name
            Text(
              widget.item.name,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Link Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      link,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.darkGray,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    color: AppColors.primaryBlue,
                    onPressed: () {
                      Navigator.pop(context);
                      _copyLinkToClipboard();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Share Button
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
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: AppColors.mediumGray, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image Carousel
          _buildSliverAppBar(item),

          // Product Details
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price Section
                  _buildPriceSection(item),
                  const SizedBox(height: 24),

                  // Product Name
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.darkGray,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (item.storeDescription != null) ...[
                    Text(
                      'الوصف',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.darkGray,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.storeDescription!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mediumGray,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Quantity Selector
                  _buildQuantitySelector(item),
                  const SizedBox(height: 32),

                  // Additional Info
                  _buildAdditionalInfo(item),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(item),
    );
  }

  /// ─── SLIVER APP BAR WITH CAROUSEL ───
  Widget _buildSliverAppBar(InventoryItemModel item) {
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showShareOptions,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.share, color: AppColors.primaryBlue),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: item.imagesList.isNotEmpty
            ? Stack(
                children: [
                  // Carousel
                  CarouselSlider(
                    options: CarouselOptions(
                      height: 400,
                      viewportFraction: 1,
                      enableInfiniteScroll: false,
                      onPageChanged: (index, _) {
                        setState(() => _currentImage = index);
                      },
                    ),
                    items: item.imagesList.map((url) {
                      return WebImage(
                        src: url,
                        width: double.infinity,
                        height: 400,
                        fit: BoxFit.cover,
                      );
                    }).toList(),
                  ),

                  // Image Counter
                  if (item.imagesList.length > 1)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImage + 1}/${item.imagesList.length}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Out of Stock Overlay
                  if (!item.isInStock)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.destructiveRed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'غير متوفر حالياً',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : Container(
                color: AppColors.lightGray,
                child: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 80,
                    color: AppColors.borderGray,
                  ),
                ),
              ),
      ),
    );
  }

  /// ─── PRICE SECTION ───
  Widget _buildPriceSection(InventoryItemModel item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Price
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.effectiveStorePrice.toStringAsFixed(2)} ج.م',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (item.hasDiscount)
              Text(
                'السعر الحالي',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGray),
              ),
          ],
        ),
        const SizedBox(width: 16),

        // Original Price & Discount Badge
        if (item.hasDiscount) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.price.toStringAsFixed(2)} ج.م',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mediumGray,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.destructiveRed,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.destructiveRed.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '-${item.discountPercentage?.toInt()}%',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// ─── QUANTITY SELECTOR ───
  Widget _buildQuantitySelector(InventoryItemModel item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الكمية',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.darkGray,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderGray),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Decrease Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.remove,
                      color: _quantity > 1
                          ? AppColors.primaryBlue
                          : AppColors.borderGray,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // Divider
              Container(width: 1, height: 44, color: AppColors.borderGray),

              // Quantity Display
              Expanded(
                child: Center(
                  child: Text(
                    '$_quantity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.darkGray,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Divider
              Container(width: 1, height: 44, color: AppColors.borderGray),

              // Increase Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _quantity < item.quantity
                      ? () => setState(() => _quantity++)
                      : null,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.add,
                      color: _quantity < item.quantity
                          ? AppColors.primaryBlue
                          : AppColors.borderGray,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'المتوفر: ${item.quantity} ${item.unit}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGray),
        ),
      ],
    );
  }

  /// ─── ADDITIONAL INFO ───
  Widget _buildAdditionalInfo(InventoryItemModel item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('رقم المنتج', item.sku),
          const SizedBox(height: 12),
          _buildInfoRow('الوحدة', item.unit),
          if (item.storeDescription != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow('الحالة', item.isInStock ? '✓ متوفر' : '✗ غير متوفر'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGray),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.darkGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// ─── BOTTOM ACTION BAR ───
  Widget _buildBottomActionBar(InventoryItemModel item) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: (item.isInStock && !_isAddingToCart && !widget.isPreview)
                ? _addToCart
                : null,
            icon: _isAddingToCart
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        item.isInStock ? AppColors.white : AppColors.mediumGray,
                      ),
                    ),
                  )
                : const Icon(Icons.shopping_cart),
            label: Text(
              _isAddingToCart
                  ? 'جاري الإضافة...'
                  : item.isInStock
                  ? 'إضافة للسلة - ${(item.effectiveStorePrice * _quantity).toStringAsFixed(2)} ج.م'
                  : 'نفذت الكمية',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: item.isInStock
                  ? AppColors.primaryBlue
                  : AppColors.mediumGray,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  void _addToCart() async {
    if (FirebaseAuth.instance.currentUser == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Login(fromCheckout: true)),
      );

      if (result == true) {
        _addToCart();
      }
      return;
    }

    setState(() => _isAddingToCart = true);

    try {
      final cart = StoreCartService();
      await cart.loadCart(widget.groupId);
      cart.addToCart(widget.item, quantity: _quantity);
      await cart.saveCart(widget.groupId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ تمت إضافة ${_quantity} من "${widget.item.name}" إلى السلة',
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'عرض السلة',
            textColor: AppColors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreCartScreen(
                    groupId: widget.groupId,
                    makeSetStateOnCartChange: false,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠ حدث خطأ: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
