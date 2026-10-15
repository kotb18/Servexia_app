import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:maintenance/Subscruption/plan_service.dart';

class BillingService extends ChangeNotifier {
  BillingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    InAppPurchase? inAppPurchase,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _iap = inAppPurchase ?? InAppPurchase.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final Map<String, ProductDetails> _products = {};

  bool isAvailable = false;
  bool isLoading = false;
  bool isPurchasePending = false;
  String? errorMessage;

  List<ProductDetails> get products => _products.values.toList(growable: false);

  ProductDetails? productFor(String productId) => _products[productId];

  Future<void> init() async {
    if (_purchaseSubscription != null) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      isAvailable = await _iap.isAvailable();

      if (!isAvailable) {
        errorMessage = 'Google Play Billing غير متاح حاليًا.';
        return;
      }

      _purchaseSubscription = _iap.purchaseStream.listen(
        _onPurchaseUpdated,
        onError: (Object error) {
          errorMessage = 'حدث خطأ في خدمة الدفع.';
          debugPrint('Billing stream error: $error');
          notifyListeners();
        },
      );
    } catch (error, stackTrace) {
      errorMessage = 'تعذر تهيئة الاشتراك.';
      debugPrint('Billing init error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProducts(Iterable<String> productIds) async {
    final ids = productIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (ids.isEmpty || !isAvailable) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _iap.queryProductDetails(ids);

      _products
        ..clear()
        ..addEntries(
          response.productDetails.map(
            (product) => MapEntry(product.id, product),
          ),
        );

      if (response.error != null) {
        errorMessage = response.error!.message;
        debugPrint('Product query error: ${response.error}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }
    } catch (error, stackTrace) {
      errorMessage = 'تعذر تحميل أسعار الاشتراكات.';
      debugPrint('Load products error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> buySubscription(String productId) async {
    final product = productFor(productId);

    if (product == null) {
      errorMessage = 'هذا الاشتراك غير متاح حاليًا.';
      notifyListeners();
      return false;
    }

    if (_auth.currentUser == null) {
      errorMessage = 'يجب تسجيل الدخول قبل شراء الاشتراك.';
      notifyListeners();
      return false;
    }

    isPurchasePending = true;
    errorMessage = null;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (error) {
      isPurchasePending = false;
      errorMessage = 'تعذر بدء عملية الشراء.';
      debugPrint('Buy error: $error');
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!isAvailable) return;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      var canCompletePurchase =
          purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled;

      try {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            isPurchasePending = true;
            debugPrint('عملية الشراء قيد الانتظار...');
            break;

          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await _handleSuccessfulPurchase(purchase);
            isPurchasePending = false;
            canCompletePurchase = true;
            break;

          case PurchaseStatus.error:
            isPurchasePending = false;
            errorMessage = purchase.error?.message ?? 'فشل إتمام الشراء.';
            debugPrint('Purchase error: ${purchase.error}');
            break;

          case PurchaseStatus.canceled:
            isPurchasePending = false;
            debugPrint('تم إلغاء عملية الشراء.');
            break;
        }
      } catch (error, stackTrace) {
        isPurchasePending = false;
        errorMessage = 'تعذر تفعيل الاشتراك بعد الشراء.';
        debugPrint('Purchase handling error: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        if (canCompletePurchase && purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        notifyListeners();
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('لا يوجد مستخدم مسجل الدخول.');
    }

    // للإنتاج: تحقق من purchase.verificationData.serverVerificationData
    // عبر Backend/Cloud Functions قبل منح الصلاحيات.
    await _activateSubscriptionForTesting(user.uid, purchase.productID);
  }

  Future<void> _activateSubscriptionForTesting(
    String uid,
    String productId,
  ) async {
    final now = DateTime.now().toUtc();
    final expiredAt = now.add(const Duration(days: 30));
    final willDeleteAt = now.add(const Duration(days: 100));

    final userRef = _firestore.collection('users').doc(uid);
    final groupsSnapshot = await _firestore
        .collection('groups')
        .where('adminId', isEqualTo: uid)
        .get();

    final groupRefs = groupsSnapshot.docs.map((doc) => doc.reference).toList();

    await _commitUserAndGroups(
      userRef: userRef,
      groupRefs: groupRefs,
      productId: productId,
      expiredAt: expiredAt,
      willDeleteAt: willDeleteAt,
    );
  }

  Future<void> _commitUserAndGroups({
    required DocumentReference<Map<String, dynamic>> userRef,
    required List<DocumentReference<Map<String, dynamic>>> groupRefs,
    required String productId,
    required DateTime expiredAt,
    required DateTime willDeleteAt,
  }) async {
    for (var start = 0; start < groupRefs.length || start == 0; start += 450) {
      final end = (start + 450 < groupRefs.length)
          ? start + 450
          : groupRefs.length;
      final batch = _firestore.batch();
      PlanService planService = PlanService();
      planService.getActiveIDPlans(productId).then((plans) {
        if (plans.isNotEmpty) {
          final plan = plans.first;
          batch.set(userRef, {
            'expiredAt': Timestamp.fromDate(expiredAt),
            'status': '1',
            'subscriptionProductId': productId,
            'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
            'maxGroups': plan.maxGroups,
            'maxInventoryItems': plan.maxInventoryItems,
            'maxInvoicesPerMonth': plan.maxInvoicesPerMonth,
            'maxAssets': plan.maxAssets,
            'maxMembers': plan.maxMembers,
          }, SetOptions(merge: true));
        }
      });
      for (final ref in groupRefs.sublist(start, end)) {
        batch.set(ref, {
          'willDeleteAt': Timestamp.fromDate(willDeleteAt),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      if (end == groupRefs.length) break;
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    super.dispose();
  }
}
