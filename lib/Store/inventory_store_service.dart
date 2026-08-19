import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory_item_model.dart';

class InventoryStoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _itemsCollection(String groupId) {
    return _firestore.collection('inventory').doc(groupId).collection('items');
  }

  /// الاستعلام الأساسي المستخدم مع FirestorePagination.
  ///
  /// الترتيب حسب isInStore يجعل المنتجات الموجودة في المتجر تظهر أولًا،
  /// ثم يتم ترتيب كل مجموعة حسب الاسم.
  Query<Map<String, dynamic>> getAllItemsQuery(String groupId) {
    return _itemsCollection(
      groupId,
    ).orderBy('isInStore', descending: true).orderBy('name');
  }

  /// جلب صنف واحد عند الحاجة.
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

  /// جلب الأصناف المُفعلة في المتجر فقط (للعملاء).
  Query<Map<String, dynamic>> getStoreItemsQuery(
    String groupId, {
    String? searchQuery,
  }) {
    Query<Map<String, dynamic>> query = _itemsCollection(groupId)
        .where('isInStore', isEqualTo: true)
        .where('quantity', isGreaterThan: 0.0);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.where(
        'name',
        isGreaterThanOrEqualTo: searchQuery,
        isLessThan: '${searchQuery}\uf8ff',
      );
    }

    query = query.orderBy('name');

    return query;
  }

  Future<void> addToStore({
    required String groupId,
    required String sku,
    required double storePrice,
    String? storeDescription,
    List<String>? colors,
    List<String>? sizes,
    List<String>? images,
  }) async {
    final updates = <String, dynamic>{
      'isInStore': true,
      'storePrice': storePrice,
    };

    if (storeDescription != null) {
      updates['storeDescription'] = storeDescription;
    }
    if (images != null && images.isNotEmpty) {
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

  Future<void> removeFromStore(String groupId, String sku) async {
    await _itemsCollection(groupId).doc(sku).update({
      'isInStore': false,
      'storePrice': FieldValue.delete(),
      'storeDescription': FieldValue.delete(),
      'imagesList': [],
      'colors': [],
      'sizes': [],
    });
  }

  Future<void> updateStorePrice(
    String groupId,
    String sku,
    double newPrice,
  ) async {
    await _itemsCollection(groupId).doc(sku).update({'storePrice': newPrice});
  }

  Future<InventoryItemModel?> getItemBySku(String groupId, String sku) async {
    final doc = await _itemsCollection(groupId).doc(sku).get();
    if (!doc.exists) return null;
    return InventoryItemModel.fromFirestore(doc);
  }
}
