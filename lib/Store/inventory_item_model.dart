import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItemModel {
  final String sku;
  final String name;
  final double quantity;
  final String unit;
  final String? location;
  final String? notes;
  final double price; // سعر البيع الأصلي في المخزون
  final double coast; // تكلفة الشراء
  final bool deleted;
  final bool isInStore; // هل ظاهر في المتجر؟
  final double? storePrice; // سعر البيع في المتجر (اختياري)
  final String? storeDescription;
  final List<String> imagesList;
  final DateTime createdAt;

  InventoryItemModel({
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unit,
    this.location,
    this.notes,
    required this.price,
    required this.coast,
    this.deleted = false,
    this.isInStore = false,
    this.storePrice,
    this.storeDescription,
    this.imagesList = const [],
    required this.createdAt,
  });

  factory InventoryItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryItemModel(
      sku: data['sku'] ?? '',
      name: data['name'] ?? '',
      quantity: data['quantity'] ?? 0,
      unit: data['unit'] ?? '',
      location: data['location'],
      notes: data['notes'],
      price: (data['price'] ?? 0).toDouble(),
      coast: (data['coast'] ?? 0).toDouble(),
      deleted: data['deleted'] ?? false,
      isInStore: data['isInStore'] ?? false,
      storePrice: data['storePrice']?.toDouble(),
      storeDescription: data['storeDescription'],
      imagesList: List<String>.from(data['imagesList'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sku': sku,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'location': location,
      'notes': notes,
      'price': price,
      'coast': coast,
      'deleted': deleted,
      'isInStore': isInStore,
      'storePrice': storePrice,
      'storeDescription': storeDescription,
      'imagesList': imagesList,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// السعر الفعلي للمتجر: لو في storePrice يستخدمه، لو لا يستخدم price
  double get effectiveStorePrice => storePrice ?? price;

  /// هل المنتج متاح للشراء؟
  bool get isAvailable => quantity > 0.0 && !deleted && isInStore;

  /// هل في خصم؟ (سعر المتجر أقل من سعر المخزون)
  bool get hasDiscount => storePrice != null && storePrice! < price;

  /// نسبة الخصم
  double? get discountPercentage => hasDiscount
      ? ((price - storePrice!) / price * 100).roundToDouble()
      : null;

  /// هل المنتج متوفر في المخزون؟
  bool get isInStock => quantity > 0.0 && !deleted;
}
