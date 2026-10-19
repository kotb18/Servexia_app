import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:maintenance/Subscruption/plan_service.dart';
import 'package:maintenance/homePage.dart';

class BillingService extends ChangeNotifier {
  BillingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    InAppPurchase? inAppPurchase,
    PlanService? planService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _iap = inAppPurchase ?? InAppPurchase.instance,
       _planService = planService ?? PlanService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final InAppPurchase _iap;
  final PlanService _planService;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final Map<String, ProductDetails> _products = {};
  final Map<String, bool> _pendingPurchasePeriods = {};

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

  Future<bool> buySubscription(String productId, bool isYearly) async {
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
    _pendingPurchasePeriods[productId] = isYearly;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!started) {
        _pendingPurchasePeriods.remove(productId);
        isPurchasePending = false;
        notifyListeners();
      }

      return started;
    } catch (error) {
      _pendingPurchasePeriods.remove(productId);
      isPurchasePending = false;
      errorMessage = 'تعذر بدء عملية الشراء.';
      debugPrint('Buy error: $error');
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!isAvailable) return;

    try {
      await _iap.restorePurchases();
    } catch (error, stackTrace) {
      errorMessage = 'تعذر استعادة المشتريات.';
      debugPrint('Restore purchases error: $error');
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
    }
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
            _pendingPurchasePeriods.remove(purchase.productID);
            canCompletePurchase = true;
            break;

          case PurchaseStatus.error:
            isPurchasePending = false;
            _pendingPurchasePeriods.remove(purchase.productID);
            errorMessage = purchase.error?.message ?? 'فشل إتمام الشراء.';
            debugPrint('Purchase error: ${purchase.error}');
            break;

          case PurchaseStatus.canceled:
            isPurchasePending = false;
            _pendingPurchasePeriods.remove(purchase.productID);
            debugPrint('تم إلغاء عملية الشراء.');
            break;
        }
      } catch (error, stackTrace) {
        isPurchasePending = false;
        _pendingPurchasePeriods.remove(purchase.productID);
        errorMessage = 'تعذر تفعيل الاشتراك بعد الشراء.';
        debugPrint('Purchase handling error: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        if (canCompletePurchase && purchase.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchase);
          } catch (error, stackTrace) {
            debugPrint('Complete purchase error: $error');
            debugPrintStack(stackTrace: stackTrace);
          }
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

    // هذا مسار محلي تجريبي فقط. في الإنتاج يجب التحقق من purchaseToken
    // على خادم موثوق قبل تعديل بيانات صلاحيات المستخدم.
    await _activateSubscriptionForTesting(user.uid, purchase.productID);
  }

  Future<void> _activateSubscriptionForTesting(
    String uid,
    String productId,
  ) async {
    // لا نفترض أن عملية الشراء بدأت من التطبيق؛ قد تكون عملية استعادة،
    // لذا نبحث عن المنتج في الباقات الشهرية والسنوية معًا.
    final results = await Future.wait([
      _planService.getActiveIDPlansYearly(productId),
      _planService.getActiveIDPlansMonthly(productId),
    ]);

    final plans = [...results[0], ...results[1]];
    final normalizedProductId = productId.trim();
    final matchingPlans = plans.where((plan) {
      return plan.yearlyProductId.trim() == normalizedProductId ||
          plan.monthlyProductId.trim() == normalizedProductId;
    }).toList();

    if (matchingPlans.isEmpty) {
      throw StateError('لا توجد باقة نشطة مرتبطة بمعرّف المنتج $productId.');
    }

    final plan = matchingPlans.first;
    final isYearly = plan.yearlyProductId.trim() == normalizedProductId;
    final isMonthly = plan.monthlyProductId.trim() == normalizedProductId;

    if (isYearly == isMonthly) {
      throw StateError('معرّف المنتج غير فريد أو لا يطابق مدة اشتراك واضحة.');
    }

    final requestedPeriod = _pendingPurchasePeriods[productId];
    if (requestedPeriod != null && requestedPeriod != isYearly) {
      throw StateError('مدة الاشتراك لا تطابق معرّف المنتج المحدد.');
    }

    final now = DateTime.now().toUtc();
    final expiredAt = _subscriptionExpiry(now, isYearly);
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
      planFields: {
        'maxGroups': plan.maxGroups,
        'maxInventoryItems': plan.maxInventoryItems,
        'maxInvoicesPerMonth': plan.maxInvoicesPerMonth,
        'maxAssets': plan.maxAssets,
        'maxMembers': plan.maxMembers,
        'id': plan.id,
      },
      expiredAt: expiredAt,
      willDeleteAt: willDeleteAt,
    );
  }

  DateTime _subscriptionExpiry(DateTime start, bool isYearly) {
    final firstOfTargetMonth = isYearly
        ? DateTime.utc(start.year + 1, start.month, 1)
        : DateTime.utc(start.year, start.month + 1, 1);
    final lastDay = DateTime.utc(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month + 1,
      0,
    ).day;
    final day = start.day > lastDay ? lastDay : start.day;

    return DateTime.utc(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month,
      day,
      start.hour,
      start.minute,
      start.second,
      start.millisecond,
      start.microsecond,
    );
  }

  Future<void> _commitUserAndGroups({
    required DocumentReference<Map<String, dynamic>> userRef,
    required List<DocumentReference<Map<String, dynamic>>> groupRefs,
    required String productId,
    required Map<String, dynamic> planFields,
    required DateTime expiredAt,
    required DateTime willDeleteAt,
  }) async {
    for (var start = 0; start < groupRefs.length || start == 0; start += 450) {
      final end = (start + 450 < groupRefs.length)
          ? start + 450
          : groupRefs.length;
      final batch = _firestore.batch();

      batch.set(userRef, {
        ...planFields,
        'expiredAt': Timestamp.fromDate(expiredAt),
        'status': '1',
        'subscriptionProductId': productId,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final ref in groupRefs.sublist(start, end)) {
        batch.set(ref, {
          'willDeleteAt': Timestamp.fromDate(willDeleteAt),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      final doc2 = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc2.exists) {
        return;
      }
      final data2 = doc2.data();
      planId = data2!['id'];
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
