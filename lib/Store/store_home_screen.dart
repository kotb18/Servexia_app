import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintenance/Store/customer_orders_screen.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'package:maintenance/Store/inventory_store_service.dart';
import 'package:maintenance/Store/store_cart_screen.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:maintenance/Store/store_product_detail_screen.dart';
import 'package:maintenance/imageControl/platform_image.dart';
import 'package:maintenance/signIn.dart';
import 'package:share_plus/share_plus.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎨 PREMIUM COMMERCE DESIGN SYSTEM
/// ═══════════════════════════════════════════════════════════════════════════
/// Design Philosophy: Modern Minimalism with Professional Polish
/// - Deep Blue Primary (#1E40AF) for trust and professionalism
/// - Green Secondary (#10B981) for positive actions
/// - Orange Accent (#F97316) for special offers
/// - Clean typography and ample whitespace
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

class StoreHomeScreen extends StatefulWidget {
  final String groupId;
  final String storeName;
  final bool isPreview;
  final String? customerId;

  const StoreHomeScreen({
    super.key,
    required this.groupId,
    required this.storeName,
    this.isPreview = false,
    this.customerId,
  });

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  final _service = InventoryStoreService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchFocused = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _generateStoreLink() {
    const baseUrl = 'https://maintenance-b7282.web.app';
    return '$baseUrl/shop/${widget.groupId}';
  }

  Future<void> _copyLinkToClipboard() async {
    final link = _generateStoreLink();
    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ تم نسخ اللينك بنجاح'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _shareStoreLink() async {
    final link = _generateStoreLink();
    await Share.share(
      'إليك متجر ${widget.storeName} على Maintenance App\n$link',
      subject: 'متجر ${widget.storeName}',
    );
  }

  void _showShareOptions() {
    final link = _generateStoreLink();

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
              'مشاركة المتجر',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.darkGray,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.storeName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGray),
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
                  _shareStoreLink();
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

  void _goToMyOrders() {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠ يجب تسجيل الدخول أولاً لعرض طلباتك'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyOrdersScreen(
          customerId: FirebaseAuth.instance.currentUser!.uid,
          groupId: widget.groupId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(isMobile),
      body: Column(
        children: [
          // Search Bar Section
          _buildSearchSection(isMobile),

          // Quick Actions (Mobile Only)
          if (!widget.isPreview && isMobile) _buildQuickActionBar(),

          // Products Grid
          Expanded(child: _buildProductsGrid()),
        ],
      ),
    );
  }

  /// ─── APP BAR ───
  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      title: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Store Name
          Expanded(
            child: Text(
              widget.storeName,
              style: const TextStyle(
                color: AppColors.darkGray,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        // My Orders Button (Desktop)
        if (!widget.isPreview && !isMobile)
          _buildAppBarAction(
            icon: Icons.receipt_long_outlined,
            tooltip: 'طلباتي',
            onTap: _goToMyOrders,
          ),

        // Share Button
        _buildAppBarAction(
          icon: Icons.share_outlined,
          tooltip: 'مشاركة المتجر',
          onTap: _showShareOptions,
        ),

        // Cart Button (Desktop)
        if (!widget.isPreview && !isMobile)
          _buildAppBarAction(
            icon: Icons.shopping_cart_outlined,
            tooltip: 'السلة',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreCartScreen(
                    groupId: widget.groupId,
                    makeSetStateOnCartChange: true,
                  ),
                ),
              );
            },
          ),

        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.borderGray, height: 1),
      ),
    );
  }

  /// ─── SEARCH SECTION ───
  Widget _buildSearchSection(bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Focus(
        onFocusChange: (hasFocus) {
          setState(() => _isSearchFocused = hasFocus);
        },
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'ابحث في المنتجات...',
            hintTextDirection: TextDirection.rtl,
            hintStyle: const TextStyle(color: AppColors.mediumGray),
            prefixIcon: const Icon(Icons.search, color: AppColors.mediumGray),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.mediumGray),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.lightGray,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _isSearchFocused
                    ? AppColors.primaryBlue
                    : AppColors.borderGray,
                width: _isSearchFocused ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryBlue,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// ─── QUICK ACTION BAR (MOBILE) ───
  Widget _buildQuickActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.shopping_bag_outlined,
              label: 'السلة',
              color: AppColors.primaryBlue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoreCartScreen(
                      groupId: widget.groupId,
                      makeSetStateOnCartChange: true,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.receipt_long_outlined,
              label: 'طلباتي',
              color: AppColors.secondaryGreen,
              onTap: _goToMyOrders,
            ),
          ),
        ],
      ),
    );
  }

  /// ─── PRODUCTS GRID ───
  Widget _buildProductsGrid() {
    return StreamBuilder<List<InventoryItemModel>>(
      stream: _service.getStoreItems(widget.groupId),
      builder: (context, snapshot) {
        // Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryBlue,
              strokeWidth: 3,
            ),
          );
        }

        // Error State
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final items = snapshot.data ?? [];

        // Filter Products
        final filtered = _searchQuery.isEmpty
            ? items
            : items.where((item) {
                final query = _searchQuery.toLowerCase();
                return item.name.toLowerCase().contains(query) ||
                    item.sku.toLowerCase().contains(query);
              }).toList();

        // Empty State
        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        // Products Grid
        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1200
                ? 5
                : constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 600
                ? 3
                : 2;

            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return _buildProductCard(filtered[index]);
              },
            );
          },
        );
      },
    );
  }

  /// ─── PRODUCT CARD ───
  Widget _buildProductCard(InventoryItemModel item) {
    return GestureDetector(
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
      child: Material(
        color: AppColors.white,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGray),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Section
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: item.imagesList.isNotEmpty
                          ? WebImage(
                              src: item.imagesList.first,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : _buildPlaceholder(),
                    ),

                    // Discount Badge
                    if (item.hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.destructiveRed,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.destructiveRed.withOpacity(
                                  0.3,
                                ),
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
                      ),

                    // Out of Stock Overlay
                    if (!item.isInStock)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'غير متوفر',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product Info Section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.darkGray,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Price and Add to Cart
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.effectiveStorePrice.toStringAsFixed(2)} ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.primaryBlue,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (item.hasDiscount)
                                  Text(
                                    '${item.price.toStringAsFixed(2)} ',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: AppColors.mediumGray,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (item.isInStock && !widget.isPreview)
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: Material(
                                color: AppColors.primaryBlue,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () => _addToCart(item, 1),
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Icon(
                                    Icons.add_shopping_cart,
                                    color: AppColors.white,
                                    size: 18,
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
      ),
    );
  }

  /// ─── HELPER WIDGETS ───

  Widget _buildAppBarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.lightGray,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: AppColors.borderGray,
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.destructiveRed),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.darkGray,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGray),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppColors.borderGray,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد منتجات',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.darkGray,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'لم نتمكن من العثور على منتجات تطابق بحثك'
                : 'لا توجد منتجات متاحة حالياً',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _addToCart(InventoryItemModel product, int quantity) async {
    if (FirebaseAuth.instance.currentUser == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Login(fromCheckout: true)),
      );

      if (result == true) {
        _addToCart(product, quantity);
      }
      return;
    }

    final cart = StoreCartService();
    await cart.loadCart(widget.groupId);
    cart.addToCart(product, quantity: quantity);
    cart.saveCart(widget.groupId);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ تمت إضافة "${product.name}" إلى السلة'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
