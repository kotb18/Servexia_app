import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maintenance/Store/store_model.dart';

class StoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _stores => _firestore.collection('stores');

  // إنشاء/تحديث متجر
  Future<void> createOrUpdateStore(StoreModel store) async {
    await _stores.doc(store.id).set(store.toMap(), SetOptions(merge: true));
  }

  // جلب متجر بالـ ID
  Future<StoreModel?> getStoreById(String storeId) async {
    final doc = await _stores.doc(storeId).get();
    if (!doc.exists) return null;
    return StoreModel.fromFirestore(doc);
  }

  // جلب متجر بالـ Slug (للرابط المخصص)
  Future<StoreModel?> getStoreBySlug(String slug) async {
    final snapshot = await _stores
        .where('storeSlug', isEqualTo: slug)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return StoreModel.fromFirestore(snapshot.docs.first);
  }

  // جلب متجر التاجر
  Stream<StoreModel?> getMerchantStore(String groupId) {
    return _stores
        .where('groupId', isEqualTo: groupId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return StoreModel.fromFirestore(snapshot.docs.first);
        });
  }

  // التحقق من توفر الـ Slug
  Future<bool> isSlugAvailable(String slug) async {
    final snapshot = await _stores
        .where('storeSlug', isEqualTo: slug)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty;
  }
}
