import 'dart:convert';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final InventoryItemModel product;
  int quantity;
  Map<String, dynamic>? selectedAttributes;

  CartItem({required this.product, this.quantity = 1, this.selectedAttributes});

  double get total => product.effectiveStorePrice * quantity;

  Map<String, dynamic> toMap() {
    return {
      'sku': product.sku,
      'quantity': quantity,
      'selectedAttributes': selectedAttributes,
    };
  }
}

class StoreCartService {
  static const String _cartKey = 'store_cart';
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.total);

  bool get isEmpty => _items.isEmpty;

  // إضافة للسلة
  void addToCart(
    InventoryItemModel product, {
    int quantity = 1,
    Map<String, dynamic>? attributes,
  }) {
    final existingIndex = _items.indexWhere(
      (item) =>
          item.product.sku == product.sku &&
          _mapsEqual(item.selectedAttributes, attributes),
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(
        CartItem(
          product: product,
          quantity: quantity,
          selectedAttributes: attributes,
        ),
      );
    }
  }

  // تعديل الكمية
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

    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
    }
  }

  // حذف من السلة
  void removeFromCart(String sku, {Map<String, dynamic>? attributes}) {
    _items.removeWhere(
      (item) =>
          item.product.sku == sku &&
          _mapsEqual(item.selectedAttributes, attributes),
    );
  }

  // تفريغ السلة
  void clearCart() {
    _items.clear();
  }

  // حفظ في SharedPreferences (للزوار)
  Future<void> saveCart(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final cartData = _items.map((item) => item.toMap()).toList();
    await prefs.setString('${_cartKey}_$groupId', jsonEncode(cartData));
  }

  // استرجاع من SharedPreferences
  Future<void> loadCart(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('${_cartKey}_$groupId');
    // TODO: استرجاع المنتجات من Firestore باستخدام الـ SKUs المحفوظة
  }

  bool _mapsEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.entries.every((e) => b[e.key] == e.value);
  }
}
