import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:maintenance/homePage.dart';

class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  ProductDetails? monthlyProduct;

  Future<void> init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('Google Billing غير متاح');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (error) {
        debugPrint('Billing error: $error');
      },
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    const ids = {'servexia_monthly'};
    final response = await _iap.queryProductDetails(ids);

    if (response.productDetails.isEmpty) {
      debugPrint('الاشتراك غير متاح حاليًا');
      return;
    }

    monthlyProduct = response.productDetails.first;
    debugPrint('تم تحميل الاشتراك: ${monthlyProduct!.title}');
  }

  void buySubscription() {
    if (monthlyProduct == null) return;

    final param = PurchaseParam(productDetails: monthlyProduct!);
    _iap.buyNonConsumable(purchaseParam: param);
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        debugPrint('عملية الشراء قيد الانتظار...');
      }

      if (purchase.status == PurchaseStatus.purchased) {
        try {
          final now = DateTime.now();
          final expiredAt = now.add(const Duration(days: 30));
          final willDeleteAt = now.add(const Duration(days: 100));

          final firestore = FirebaseFirestore.instance;
          final batch = firestore.batch();

          final userRef = firestore.collection('users').doc(uid);

          batch.update(userRef, {'expiredAt': expiredAt, 'status': '1'});

          final groupsQuery = await firestore
              .collection('groups')
              .where('adminId', isEqualTo: uid)
              .get();

          for (final doc in groupsQuery.docs) {
            batch.update(doc.reference, {'willDeleteAt': willDeleteAt});
          }

          await batch.commit();

          debugPrint('تم الاشتراك بنجاح');

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        } catch (e) {
          debugPrint('خطأ أثناء تحديث البيانات: $e');
        }
      }

      if (purchase.status == PurchaseStatus.error) {
        debugPrint('خطأ في الشراء: ${purchase.error}');
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
