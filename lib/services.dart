import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'models.dart';

/// خدمة Firebase للتعامل مع الفواتير مع دعم Pagination
class InvoiceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int pageSize = 5; // عدد الفواتير في كل صفحة

  /// الحصول على جميع الفواتير مع Pagination
  Stream<List<Invoice>> getInvoicesWithPagination(
    String groupId, {
    int pageSize = InvoiceService.pageSize,
  }) {
    return _firestore
        .collection('invoices')
        .doc(groupId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Invoice.fromFirestore(doc))
              .toList();
        });
  }

  /// الحصول على الفواتير بشكل متدرج (Pagination)
  Future<List<Invoice>> getNextPage(
    String groupId,
    DocumentSnapshot? lastDocument, {
    int pageSize = InvoiceService.pageSize,
  }) async {
    try {
      Query query = _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    } catch (e) {
      print('خطأ في جلب الصفحة التالية: $e');
      return [];
    }
  }

  /// الحصول على جميع الفواتير من مجموعة معينة
  Stream<List<Invoice>> getInvoices(String groupId) {
    return _firestore
        .collection('invoices')
        .doc(groupId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Invoice.fromFirestore(doc))
              .toList();
        });
  }

  /// الحصول على فاتورة واحدة بناءً على معرفها
  Future<Invoice?> getInvoice(String groupId, String invoiceId) async {
    try {
      final doc = await _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .doc(invoiceId)
          .get();

      if (doc.exists) {
        return Invoice.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('خطأ في جلب الفاتورة: $e');
      return null;
    }
  }

  /// إضافة فاتورة جديدة
  Future<String?> addInvoice(String groupId, Invoice invoice) async {
    try {
      final docRef = await _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .add(invoice.toJson());
      return docRef.id;
    } catch (e) {
      print('خطأ في إضافة الفاتورة: $e');
      return null;
    }
  }

  /// تحديث فاتورة موجودة
  Future<bool> updateInvoice(
    String groupId,
    String invoiceId,
    Invoice invoice,
  ) async {
    try {
      await _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .doc(invoiceId)
          .update(invoice.toJson());
      return true;
    } catch (e) {
      print('خطأ في تحديث الفاتورة: $e');
      return false;
    }
  }

  /// حذف فاتورة
  Future<bool> deleteInvoice(String groupId, String invoiceId) async {
    try {
      await _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .doc(invoiceId)
          .delete();
      return true;
    } catch (e) {
      print('خطأ في حذف الفاتورة: $e');
      return false;
    }
  }

  /// تحديث حالة القسط
  Future<bool> updateInstallmentStatus(
    String groupId,
    String invoiceId,
    int installmentNumber,
    String newStatus,
  ) async {
    try {
      final invoice = await getInvoice(groupId, invoiceId);
      if (invoice != null) {
        final updatedInstallments = invoice.installments.map((inst) {
          if (inst.number == installmentNumber) {
            return inst.copyWith(status: newStatus);
          }
          return inst;
        }).toList();

        final updatedInvoice = invoice.copyWith(
          installments: updatedInstallments,
        );
        return await updateInvoice(groupId, invoiceId, updatedInvoice);
      }
      return false;
    } catch (e) {
      print('خطأ في تحديث حالة القسط: $e');
      return false;
    }
  }

  /// الحصول على إحصائيات الفواتير
  Future<InvoiceStatistics> getStatistics(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .get();

      final invoices = snapshot.docs
          .map((doc) => Invoice.fromFirestore(doc))
          .toList();

      double totalSales = 0;
      double totalPurchases = 0;
      int salesCount = 0;
      int purchasesCount = 0;
      double totalInstallments = 0;
      int invoicesWithInstallments = 0;
      int paidInstallmentsCount = 0;
      int overdueInstallmentsCount = 0;

      for (final invoice in invoices) {
        if (invoice.isSale) {
          totalSales += invoice.summary.total;
          salesCount++;
        } else if (invoice.isPurchase) {
          totalPurchases += invoice.summary.total;
          purchasesCount++;
        }

        if (invoice.hasInstallments) {
          invoicesWithInstallments++;
          totalInstallments += invoice.installments.fold(
            0.0,
            (sum, inst) => sum + inst.value,
          );
          paidInstallmentsCount += invoice.installments
              .where((inst) => inst.isPaid)
              .length;
          overdueInstallmentsCount += invoice.overdueInstallmentsCount;
        }
      }

      return InvoiceStatistics(
        totalSales: totalSales,
        totalPurchases: totalPurchases,
        salesCount: salesCount,
        purchasesCount: purchasesCount,
        totalInvoices: invoices.length,
        averageSaleAmount: salesCount > 0 ? totalSales / salesCount : 0,
        averagePurchaseAmount: purchasesCount > 0
            ? totalPurchases / purchasesCount
            : 0,
        totalInstallments: totalInstallments,
        invoicesWithInstallments: invoicesWithInstallments,
        paidInstallmentsCount: paidInstallmentsCount,
        overdueInstallmentsCount: overdueInstallmentsCount,
      );
    } catch (e) {
      print('خطأ في جلب الإحصائيات: $e');
      return InvoiceStatistics();
    }
  }

  /// البحث عن فواتير بناءً على الفلتر
  Future<List<Invoice>> searchInvoices(
    String groupId,
    InvoiceFilter filter,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .get();

      final invoices = snapshot.docs
          .map((doc) => Invoice.fromFirestore(doc))
          .toList();

      return invoices.where((invoice) => filter.matches(invoice)).toList();
    } catch (e) {
      print('خطأ في البحث عن الفواتير: $e');
      return [];
    }
  }

  /// الحصول على الفواتير حسب النوع
  Future<List<Invoice>> getInvoicesByType(String groupId, String type) async {
    try {
      final snapshot = await _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    } catch (e) {
      print('خطأ في جلب الفواتير حسب النوع: $e');
      return [];
    }
  }

  /// الحصول على الفواتير في نطاق تاريخي معين
  Future<List<Invoice>> getInvoicesByDateRange(
    String groupId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    } catch (e) {
      print('خطأ في جلب الفواتير حسب التاريخ: $e');
      return [];
    }
  }

  /// الحصول على الفواتير حسب طريقة الدفع
  Future<List<Invoice>> getInvoicesByPaymentMethod(
    String groupId,
    String paymentMethod,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .where('paymentMethod', isEqualTo: paymentMethod)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    } catch (e) {
      print('خطأ في جلب الفواتير حسب طريقة الدفع: $e');
      return [];
    }
  }

  /// الحصول على الفواتير التي تحتوي على أقساط
  Future<List<Invoice>> getInvoicesWithInstallments(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('invoices')
          .doc(groupId)
          .collection('items')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Invoice.fromFirestore(doc))
          .where((invoice) => invoice.hasInstallments)
          .toList();
    } catch (e) {
      print('خطأ في جلب الفواتير التي تحتوي على أقساط: $e');
      return [];
    }
  }

  /// الحصول على الأقساط المتأخرة
  Future<List<Map<String, dynamic>>> getOverdueInstallments(
    String groupId,
  ) async {
    try {
      final invoices = await getInvoicesWithInstallments(groupId);
      final overdueInstallments = <Map<String, dynamic>>[];

      for (final invoice in invoices) {
        for (final installment in invoice.installments) {
          if (installment.isOverdue) {
            overdueInstallments.add({
              'invoiceNumber': invoice.invoiceNumber,
              'customerName': invoice.customerName,
              'installment': installment,
              'invoiceId': invoice.id,
            });
          }
        }
      }

      return overdueInstallments;
    } catch (e) {
      print('خطأ في جلب الأقساط المتأخرة: $e');
      return [];
    }
  }
}

/// نموذج إحصائيات الفواتير (محدث)
class InvoiceStatistics {
  final double totalSales;
  final double totalPurchases;
  final int salesCount;
  final int purchasesCount;
  final int totalInvoices;
  final double averageSaleAmount;
  final double averagePurchaseAmount;
  final double totalInstallments; // إجمالي قيمة الأقساط
  final int invoicesWithInstallments; // عدد الفواتير التي تحتوي على أقساط
  final int paidInstallmentsCount; // عدد الأقساط المدفوعة
  final int overdueInstallmentsCount; // عدد الأقساط المتأخرة

  InvoiceStatistics({
    this.totalSales = 0,
    this.totalPurchases = 0,
    this.salesCount = 0,
    this.purchasesCount = 0,
    this.totalInvoices = 0,
    this.averageSaleAmount = 0,
    this.averagePurchaseAmount = 0,
    this.totalInstallments = 0,
    this.invoicesWithInstallments = 0,
    this.paidInstallmentsCount = 0,
    this.overdueInstallmentsCount = 0,
  });

  /// الربح/الخسارة (المبيعات - المشتريات)
  double get profit => totalSales - totalPurchases;

  /// إجمالي المبلغ (المبيعات + المشتريات)
  double get totalAmount => totalSales + totalPurchases;

  /// نسبة الأقساط المدفوعة
  double get paidInstallmentsPercentage {
    final totalInstallmentsCount =
        paidInstallmentsCount + (totalInstallments > 0 ? 1 : 0);
    if (totalInstallmentsCount == 0) return 0;
    return (paidInstallmentsCount / totalInstallmentsCount) * 100;
  }
}
