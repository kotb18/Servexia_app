import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory_item_model.dart';

class InventoryStoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _itemsCollection(String groupId) {
    return _firestore.collection('inventory').doc(groupId).collection('items');
  }

  /// جلب كل الأصناف (للتاجر)
  Stream<List<InventoryItemModel>> getAllItems(String groupId) {
    return _itemsCollection(groupId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InventoryItemModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<InventoryItemModel?> getItemById(String groupId, String itemId) async {
    try {
      final doc = await _itemsCollection(groupId).doc(itemId).get();
      if (!doc.exists || doc.data() == null) return null;
      return InventoryItemModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting item: $e');
      return null;
    }
  }

  /// جلب الأصناف المُفعلة في المتجر فقط (للعملاء)
  Query getStoreItemsQuery(String groupId, {String? searchQuery}) {
    Query query = _itemsCollection(groupId)
        .where('isInStore', isEqualTo: true)
        .where('quantity', isGreaterThan: 0.0)
        .orderBy('name');

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lower = searchQuery.toLowerCase();
      query = query
          .where('name', isGreaterThanOrEqualTo: lower)
          .where('name', isLessThanOrEqualTo: '$lower\uf8ff');
    }

    return query;
  }

  /// تفعيل صنف في المتجر
  Future<void> addToStore({
    required String groupId,
    required String sku,
    required double storePrice,
    String? storeDescription,
    List<String>? colors,
    List<String>? sizes,
    List<String>? images, // <-- صور المتجر
  }) async {
    final updates = <String, dynamic>{
      'isInStore': true,
      'storePrice': storePrice,
    };

    if (storeDescription != null)
      updates['storeDescription'] = storeDescription;
    if (images != null && images.isNotEmpty) updates['imagesList'] = images;
    if (colors != null && colors.isNotEmpty) updates['colors'] = colors;
    if (sizes != null && sizes.isNotEmpty) updates['sizes'] = sizes;

    await _itemsCollection(groupId).doc(sku).update(updates);
  }

  Future<void> updateStoreProduct({
    required String groupId,
    required String sku,
    required double storePrice,
    String? storeDescription,
    List<String>? images,
    List<String>? colors,
    List<String>? sizes,
  }) async {
    final updates = <String, dynamic>{'storePrice': storePrice};

    if (storeDescription != null) {
      updates['storeDescription'] = storeDescription;
    } else {
      updates['storeDescription'] = FieldValue.delete();
    }

    if (images != null) {
      updates['imagesList'] = images;
    }

    if (colors != null && colors.isNotEmpty) {
      updates['colors'] = colors;
    }

    if (sizes != null && sizes.isNotEmpty) {
      updates['sizes'] = sizes;
    }

    await _itemsCollection(groupId).doc(sku).update(updates);
  }

  /// إلغاء تفعيل صنف من المتجر
  Future<void> removeFromStore(String groupId, String sku) async {
    await _itemsCollection(groupId).doc(sku).update({
      'isInStore': false,
      'storePrice': FieldValue.delete(),
      'storeDescription': FieldValue.delete(),
      'imagesList': [],
      'colors': [],
      'sizes': [],
      // <-- تفريغ الصور
    });
  }

  /// تحديث سعر المتجر
  Future<void> updateStorePrice(
    String groupId,
    String sku,
    double newPrice,
  ) async {
    await _itemsCollection(groupId).doc(sku).update({'storePrice': newPrice});
  }

  /// جلب صنف بالـ SKU
  Future<InventoryItemModel?> getItemBySku(String groupId, String sku) async {
    final doc = await _itemsCollection(groupId).doc(sku).get();
    if (!doc.exists) return null;
    return InventoryItemModel.fromFirestore(doc);
  }
}
