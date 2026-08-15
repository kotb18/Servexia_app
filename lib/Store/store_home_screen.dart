import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintenance/Store/customer_orders_screen.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'package:maintenance/Store/inventory_store_service.dart';
import 'package:maintenance/Store/store_cart_screen.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:maintenance/Store/store_model.dart';
import 'package:maintenance/Store/store_product_detail_screen.dart';
import 'package:maintenance/Store/store_service.dart';
import 'package:maintenance/imageControl/platform_image.dart';
import 'package:maintenance/signIn.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🏪 DYNAMIC STORE HOME SCREEN
/// ═══════════════════════════════════════════════════════════════════════════
/// - يقرأ إعدادات المتجر من Firestore (لون، اسم، وصف، تواصل، شحن)
/// - يطبّق اللون الأساسي ديناميكياً على كل الواجهة
/// ═══════════════════════════════════════════════════════════════════════════

class StoreHomeScreen extends StatefulWidget {
  final String groupId;
  final bool isPreview;
  final String? customerId;

  const StoreHomeScreen({
    super.key,
    required this.groupId,
    this.isPreview = false,
    this.customerId,
  });

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  final _service = InventoryStoreService();
  final _storeService = StoreService();
  final _searchController = TextEditingController();

  StoreModel? _store;
  bool _isLoadingStore = true;
  String _searchQuery = '';
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ─── جلب بيانات المتجر الكاملة ───
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

  /// ─── Helpers ───
  Color get primaryColor => _store != null
      ? _hexToColor(_store!.primaryColor)
      : const Color(0xFF2196F3);

  Color get primaryColorLight => primaryColor.withOpacity(0.1);
  Color get primaryColorDark => HSLColor.fromColor(primaryColor)
      .withLightness(
        (HSLColor.fromColor(primaryColor).lightness - 0.15).clamp(0.0, 1.0),
      )
      .toColor();

  String get storeName => _store?.name ?? 'متجر';
  String? get storeDescription => _store?.description;
  String? get phone => _store?.phone;
  String? get whatsapp => _store?.whatsapp;
  String? get email => _store?.email;
  double get shippingFee => _store?.shippingFee ?? 0.0;
  bool get isClothes => _store?.isClothes ?? false;

  String _generateStoreLink() {
    const baseUrl = 'https://maintenance-b7282.web.app';
    return '$baseUrl/shop/${widget.groupId}';
  }

  Future<void> _copyLinkToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _generateStoreLink()));
    if (!mounted) return;
    _showSnackBar('✓ تم نسخ رابط المتجر', isSuccess: true);
  }

  Future<void> _shareStoreLink() async {
    await Share.share(
      'تفضل بزيارة متجر "$storeName" 🛒\n${_generateStoreLink()}',
      subject: storeName,
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

  void _goToMyOrders() {
    if (FirebaseAuth.instance.currentUser == null) {
      _showSnackBar('⚠ يجب تسجيل الدخول أولاً لعرض طلباتك');
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    if (_isLoadingStore) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
        ),
      );
    }

    if (_store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطأ')),
        body: const Center(child: Text('تعذر تحميل بيانات المتجر')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isMobile),
          SliverToBoxAdapter(child: _buildStoreHeader(isMobile)),
          SliverToBoxAdapter(child: _buildSearchSection(isMobile)),
          if (!widget.isPreview && isMobile)
            SliverToBoxAdapter(child: _buildQuickActionBar()),
          _buildProductsGrid(),
          SliverToBoxAdapter(child: SizedBox(height: isMobile ? 120 : 40)),
        ],
      ),
      floatingActionButton: (!widget.isPreview && isMobile)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreCartScreen(
                    groupId: widget.groupId,
                    shippingFee: shippingFee,
                    makeSetStateOnCartChange: true,
                  ),
                ),
              ),
              backgroundColor: primaryColor,
              icon: const Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
              ),
              label: const Text('السلة', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🎯 SLIVER APP BAR
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildSliverAppBar(bool isMobile) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      expandedHeight: isMobile ? 0 : 80,
      title: Row(
        children: [
          Hero(
            tag: 'store_logo_${widget.groupId}',
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColorDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  storeName.isNotEmpty ? storeName[0] : 'M',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (storeDescription != null && storeDescription!.isNotEmpty)
                  Text(
                    storeDescription!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (!widget.isPreview && !isMobile)
          _buildAppBarAction(
            icon: Icons.receipt_long_outlined,
            tooltip: 'طلباتي',
            onTap: _goToMyOrders,
          ),
        _buildAppBarAction(
          icon: Icons.share_outlined,
          tooltip: 'مشاركة المتجر',
          onTap: () => _showShareBottomSheet(),
        ),
        if (!widget.isPreview && !isMobile)
          _buildAppBarAction(
            icon: Icons.shopping_cart_outlined,
            tooltip: 'السلة',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoreCartScreen(
                  groupId: widget.groupId,
                  shippingFee: shippingFee,
                  makeSetStateOnCartChange: true,
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey.shade200, height: 1),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🏪 STORE HEADER (Banner)
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildStoreHeader(bool isMobile) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColorDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              left: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -20,
              bottom: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isClothes ? '👕 متجر ملابس' : '🛍️ متجر عام',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (storeDescription != null && storeDescription!.isNotEmpty)
                    Text(
                      storeDescription!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      if (phone != null && phone!.isNotEmpty)
                        _buildContactChip(
                          icon: Icons.phone,
                          label: phone!,
                          onTap: () => _launchUrl('tel:$phone'),
                        ),
                      if (whatsapp != null && whatsapp!.isNotEmpty)
                        _buildContactChip(
                          icon: Icons.chat_bubble_outline,
                          label: 'واتساب',
                          onTap: () => _launchUrl(
                            'https://wa.me/${whatsapp!.replaceAll(RegExp(r'[^0-9]'), '')}',
                          ),
                        ),
                      if (email != null && email!.isNotEmpty)
                        _buildContactChip(
                          icon: Icons.email_outlined,
                          label: email!,
                          onTap: () => _launchUrl('mailto:$email'),
                        ),
                      _buildContactChip(
                        icon: Icons.local_shipping_outlined,
                        label: 'شحن: ${shippingFee.toStringAsFixed(0)}',
                        onTap: null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🔍 SEARCH SECTION
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildSearchSection(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 16,
        vertical: 8,
      ),
      child: Focus(
        onFocusChange: (hasFocus) =>
            setState(() => _isSearchFocused = hasFocus),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'ابحث في منتجات $storeName...',
            hintTextDirection: TextDirection.rtl,
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade500),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _isSearchFocused ? primaryColor : Colors.grey.shade200,
                width: _isSearchFocused ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// ⚡ QUICK ACTIONS (Mobile)
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildQuickActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.shopping_bag_outlined,
              label: 'السلة',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreCartScreen(
                    groupId: widget.groupId,
                    shippingFee: shippingFee,
                    makeSetStateOnCartChange: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.receipt_long_outlined,
              label: 'طلباتي',
              onTap: _goToMyOrders,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.share_outlined,
              label: 'مشاركة',
              onTap: _shareStoreLink,
            ),
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🛍️ PRODUCTS GRID
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildProductsGrid() {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.crossAxisExtent > 1200
            ? 5
            : constraints.crossAxisExtent > 900
            ? 4
            : constraints.crossAxisExtent > 600
            ? 3
            : 2;

        return SliverToBoxAdapter(
          // ❌ أزل SizedBox(height: ...) تماماً
          // GridView مع shrinkWrap يحسب ارتفاعه ذاتياً
          child: FirestorePagination(
            // 🔑 مفتاح لإعادة البناء عند تغير البحث
            key: ValueKey(_searchQuery),

            query: _service.getStoreItemsQuery(
              widget.groupId,
              searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
            ),

            limit: 2, // ✅ دفعة منطقية (صفين إلى ثلاثة)
            viewType: ViewType.grid,
            isLive: true,
            padding: const EdgeInsets.all(16),

            // ✅ اترك shrinkWrap ليحسب الارتفاع ذاتياً
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),

            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.60,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),

            initialLoader: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),

            bottomLoader: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),

            onEmpty: _buildEmptyState(),

            itemBuilder: (context, docs, index) {
              debugPrint(
                'Pagination: loaded ${docs.length} items, current index: $index',
              );
              final doc = docs[index];
              final item = InventoryItemModel.fromFirestore(doc);
              return _buildProductCard(item);
            },
          ),
        );
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🃏 PRODUCT CARD
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildProductCard(InventoryItemModel item) {
    final hasDesc = item.storeDescription?.trim().isNotEmpty == true;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoreProductDetailScreen(
            item: item,
            groupId: widget.groupId,
            isPreview: widget.isPreview,
            shippingFee: shippingFee,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════ IMAGE ═══════════════
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
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
                  if (item.hasDiscount)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade600, Colors.red.shade400],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                  if (!item.isInStock)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hide_image,
                              color: Colors.white70,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'غير متوفر',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ═══════════════ INFO ═══════════════
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1F2937),
                        height: 1.3,
                      ),
                    ),

                    // ✅ Description (only if exists)
                    if (hasDesc) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.storeDescription!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Price + Cart
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.effectiveStorePrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: primaryColor,
                                ),
                              ),
                              if (item.hasDiscount)
                                Text(
                                  '${item.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item.isInStock) _buildAddToCartButton(item),
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

  Widget _buildAddToCartButton(InventoryItemModel item) {
    return Material(
      color: primaryColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _addToCart(item, 1),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [primaryColor, primaryColorDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.add_shopping_cart,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// 📤 SHARE BOTTOM SHEET
  /// ═══════════════════════════════════════════════════════════════════════
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
              'مشاركة "$storeName"',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'شارك المتجر مع عملائك وأصدقائك',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
                      _generateStoreLink(),
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
                  _shareStoreLink();
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
  /// 🔧 HELPERS
  /// ═══════════════════════════════════════════════════════════════════════
  Widget _buildAppBarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(icon, color: primaryColor, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: primaryColorLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w700,
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
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            'حدث خطأ في تحميل المنتجات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
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
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty
                ? 'لا توجد نتائج لـ "$_searchQuery"'
                : 'لا توجد منتجات متاحة',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'جرب البحث بكلمات مختلفة'
                : 'سيتم عرض المنتجات هنا بمجرد إضافتها',
            style: TextStyle(color: Colors.grey.shade600),
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

      if (result == true && product.sizes!.isEmpty && product.colors!.isEmpty) {
        _addToCart(product, quantity);
      } else if (result == true &&
          (product.sizes!.isNotEmpty || product.colors!.isNotEmpty)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreProductDetailScreen(
              item: product,
              groupId: widget.groupId,
              isPreview: widget.isPreview,
              shippingFee: shippingFee,
            ),
          ),
        );
      }
      return;
    }

    if (product.sizes!.isNotEmpty && product.colors!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoreProductDetailScreen(
            item: product,
            groupId: widget.groupId,
            isPreview: widget.isPreview,
            shippingFee: shippingFee,
          ),
        ),
      );
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
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
