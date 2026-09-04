import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final InventoryItemModel product;
  int quantity;
  Map<String, dynamic>? selectedAttributes;
  String? selectedColor;
  String? selectedSize;
  CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedAttributes,
    this.selectedColor,
    this.selectedSize,
  });

  double get total => product.effectiveStorePrice * quantity;

  Map<String, dynamic> toMap() {
    return {
      'sku': product.sku,
      'quantity': quantity,
      'selectedAttributes': selectedAttributes,
      'selectedColor': selectedColor,
      'selectedSize': selectedSize,
    };
  }

  factory CartItem.fromMap(
    Map<String, dynamic> map,
    InventoryItemModel product,
  ) {
    return CartItem(
      product: product,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      selectedAttributes: map['selectedAttributes'] != null
          ? Map<String, dynamic>.from(map['selectedAttributes'])
          : null,
    );
  }
}

class StoreCartService {
  // ✅ Cart key يعتمد على المستخدم الحالي
  String get _cartKey => FirebaseAuth.instance.currentUser != null
      ? 'store_cart_${FirebaseAuth.instance.currentUser!.uid}'
      : 'store_cart_guest';

  final List<CartItem> _items = [];

  // Singleton
  static final StoreCartService _instance = StoreCartService._internal();
  factory StoreCartService() => _instance;
  StoreCartService._internal();

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.total);

  bool get isEmpty => _items.isEmpty;

  // ================= GET ITEM =================

  CartItem? getItem(String sku, {Map<String, dynamic>? attributes}) {
    try {
      return _items.firstWhere(
        (item) =>
            item.product.sku == sku &&
            _mapsEqual(item.selectedAttributes, attributes),
      );
    } catch (_) {
      return null;
    }
  }

  // ================= ADD TO CART =================

  void addToCart(
    InventoryItemModel product, {
    int quantity = 1,
    Map<String, dynamic>? attributes,
    String? selectedColor,
    String? selectedSize,
  }) {
    final index = _items.indexWhere(
      (item) =>
          item.product.sku == product.sku &&
          _mapsEqual(item.selectedAttributes, attributes),
    );

    if (index != -1) {
      _items[index].quantity += quantity;
    } else {
      _items.add(
        CartItem(
          product: product,
          quantity: quantity,
          selectedAttributes: attributes,
          selectedColor: selectedColor,
          selectedSize: selectedSize,
        ),
      );
    }
  }

  // ================= UPDATE QUANTITY =================

  void updateQuantity(
    String sku,
    int quantity, {
    Map<String, dynamic>? attributes,
  }) {
    final index = _items.indexWhere(
      (item) =>
          item.product.sku == sku &&
          _mapsEqual(item.selectedAttributes, attributes),
    );

    if (index != -1) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
    }
  }

  // ================= REMOVE =================

  void removeFromCart(String sku, {Map<String, dynamic>? attributes}) {
    _items.removeWhere(
      (item) =>
          item.product.sku == sku &&
          _mapsEqual(item.selectedAttributes, attributes),
    );
  }

  void removeItem(CartItem item) {
    _items.remove(item);
  }

  // ================= CLEAR =================

  void clearCart() {
    _items.clear();
  }

  // ================= SAVE CART (FIXED) =================

  Future<void> saveCart(String groupId) async {
    final prefs = await SharedPreferences.getInstance();

    final key = '${_cartKey}_$groupId';

    final data = _items.map((item) => item.toMap()).toList();

    await prefs.setString(key, jsonEncode(data));
  }

  // ================= LOAD CART =================

  Future<void> loadCart(String groupId) async {
    final prefs = await SharedPreferences.getInstance();

    final key = '${_cartKey}_$groupId';

    final cartJson = await prefs.getString(key);

    // 🧠 لو مفيش بيانات = سلة فاضية
    if (cartJson == null || cartJson.isEmpty) {
      _items.clear();
      return;
    }

    try {
      // تحويل JSON إلى List
      final List<dynamic> cartData = jsonDecode(cartJson);

      // 🧹 نبني السلة من جديد (ده صح هنا لأن المستخدم logged-in)
      _items.clear();

      // 🔥 جلب بيانات المنتجات من Firestore
      final products = await _fetchProductsFromFirestore(groupId, cartData);

      bool hasChanges = false;

      for (var itemData in cartData) {
        final sku = itemData['sku'] as String?;
        if (sku == null) continue;

        final product = products[sku];
        print(
          '🔍 Loading cart item: SKU=$sku, Product found: ${product != null}',
        );
        // ❌ المنتج غير موجود أو غير متاح
        if (product == null || !product.isInStore || product.quantity <= 0) {
          hasChanges = true;
          continue;
        }

        // 📦 الكمية المحفوظة
        final savedQty = (itemData['quantity'] as num?)?.toInt() ?? 1;

        // 📊 الكمية المتاحة حاليًا
        final availableQty = product.quantity.toInt();

        // ⚖️ نختار أقل كمية
        final finalQty = savedQty > availableQty ? availableQty : savedQty;

        if (finalQty != savedQty) {
          hasChanges = true;
        }

        // 🛒 إضافة العنصر للسلة
        _items.add(
          CartItem(
            product: product,
            quantity: finalQty,
            selectedAttributes: itemData['selectedAttributes'] != null
                ? Map<String, dynamic>.from(itemData['selectedAttributes'])
                : null,
            selectedColor: itemData['selectedColor'] as String?,
            selectedSize: itemData['selectedSize'] as String?,
          ),
        );
      }

      // 💾 نحفظ التعديلات فقط لو حصل تغيير فعلي
      if (hasChanges) {
        await saveCart(groupId);
      }
    } catch (e) {
      print('❌ Error loading cart: $e');
      _items.clear();
    }
  }
  // ================= FIRESTORE FETCH =================

  Future<Map<String, InventoryItemModel>> _fetchProductsFromFirestore(
    String groupId,
    List<dynamic> cartData,
  ) async {
    final skus = cartData
        .map((item) => item['sku'] as String?)
        .whereType<String>()
        .toList();

    if (skus.isEmpty) return {};

    try {
      final snapshots = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(groupId)
          .collection('items')
          .where(FieldPath.documentId, whereIn: skus)
          .get();
      print(
        '✅ Fetched ${snapshots.docs.length} products from Firestore for cart',
      );
      return {
        for (var doc in snapshots.docs)
          doc.id: InventoryItemModel.fromFirestore(doc),
      };
    } catch (e) {
      print('❌ Error fetching products: $e');
      return {};
    }
  }

  // ================= MAP COMPARISON =================

  bool _mapsEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    return a.entries.every((e) => b[e.key] == e.value);
  }
}
