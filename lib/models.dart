import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج العميل
class Customer {
  final String? id;
  final String? name;
  final String? phone;
  final String? address;

  Customer({this.id, this.name, this.phone, this.address});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'phone': phone, 'address': address};
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
    );
  }
}

/// نموذج صنف الفاتورة
class InvoiceItem {
  final String name;
  final int quantity;
  final double price;
  final double total;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'quantity': quantity, 'price': price, 'total': total};
  }

  InvoiceItem copyWith({
    String? name,
    int? quantity,
    double? price,
    double? total,
  }) {
    return InvoiceItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      total: total ?? this.total,
    );
  }
}

/// نموذج ملخص الفاتورة
class InvoiceSummary {
  final double subTotal;
  final double discountPercent;
  final double discountValue;
  final double taxPercent;
  final double taxValue;
  final double total;

  InvoiceSummary({
    required this.subTotal,
    required this.discountPercent,
    required this.discountValue,
    required this.taxPercent,
    required this.taxValue,
    required this.total,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceSummary(
      subTotal: (json['subTotal'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0.0,
      taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0.0,
      taxValue: (json['taxValue'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subTotal': subTotal,
      'discountPercent': discountPercent,
      'discountValue': discountValue,
      'taxPercent': taxPercent,
      'taxValue': taxValue,
      'total': total,
    };
  }

  InvoiceSummary copyWith({
    double? subTotal,
    double? discountPercent,
    double? discountValue,
    double? taxPercent,
    double? taxValue,
    double? total,
  }) {
    return InvoiceSummary(
      subTotal: subTotal ?? this.subTotal,
      discountPercent: discountPercent ?? this.discountPercent,
      discountValue: discountValue ?? this.discountValue,
      taxPercent: taxPercent ?? this.taxPercent,
      taxValue: taxValue ?? this.taxValue,
      total: total ?? this.total,
    );
  }
}

/// نموذج القسط (Installment)
class Installment {
  final int number; // رقم القسط (1, 2, 3...)
  final String type; // نوع الدفع (شيك، تحويل بنكي، إلخ)
  final double value; // قيمة القسط
  final DateTime date; // تاريخ الاستحقاق
  final String status; // حالة الدفع (معلق، مدفوع، متأخر)

  Installment({
    required this.number,
    required this.type,
    required this.value,
    required this.date,
    required this.status,
  });

  factory Installment.fromJson(Map<String, dynamic> json, {int? index}) {
    return Installment(
      number: index ?? (json['number'] as int? ?? 0),
      type: json['type'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'معلق',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'type': type,
      'value': value,
      'date': date.toIso8601String(),
      'status': status,
    };
  }

  Installment copyWith({
    int? number,
    String? type,
    double? value,
    DateTime? date,
    String? status,
  }) {
    return Installment(
      number: number ?? this.number,
      type: type ?? this.type,
      value: value ?? this.value,
      date: date ?? this.date,
      status: status ?? this.status,
    );
  }

  /// التحقق من أن القسط مدفوع
  bool get isPaid => status == 'تم';

  /// التحقق من أن القسط متأخر
  bool get isOverdue =>
      (DateTime.now().isAfter(date) && status == '!') || (status == 'متأخر');

  /// الحصول على لون الحالة
  String get statusColor {
    if (isPaid) return '#10B981'; // أخضر
    if (isOverdue) return '#EF4444'; // أحمر
    return '#F59E0B'; // برتقالي (معلق)
  }

  /// الحصول على نص الحالة بالعربية
  String get statusLabel {
    if (isPaid) return 'مدفوع';
    if (isOverdue) return 'متأخر';
    return 'معلق';
  }
}

/// نموذج الفاتورة الرئيسي (محدث)
class Invoice {
  final String? id; // معرّف Firestore
  final String type; // 'بيع' أو 'شراء'
  final Customer customer;
  final List<InvoiceItem> items;
  final InvoiceSummary summary;
  final String? notes;
  final DateTime date;
  final String invoiceNumber;
  final DateTime createdAt;
  final String paymentMethod; // 'كاش', 'شيك', 'تحويل بنكي', إلخ
  final List<Installment> installments; // الأقساط (إذا كانت موجودة)

  Invoice({
    this.id,
    required this.type,
    required this.customer,
    required this.items,
    required this.summary,
    this.notes,
    required this.date,
    required this.invoiceNumber,
    required this.createdAt,
    required this.paymentMethod,
    this.installments = const [],
  });

  factory Invoice.fromJson(Map<String, dynamic> json, {String? docId}) {
    // استخراج الأقساط من البيانات
    final installments = <Installment>[];
    int installmentCount = 1;
    while (json.containsKey('payment$installmentCount')) {
      final paymentData =
          json['payment$installmentCount'] as Map<String, dynamic>;
      installments.add(
        Installment.fromJson(paymentData, index: installmentCount),
      );
      installmentCount++;
    }

    return Invoice(
      id: docId,
      type: json['type'] as String? ?? '',
      customer: Customer.fromJson(
        json['customer'] as Map<String, dynamic>? ?? {},
      ),
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (item) => InvoiceItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      summary: InvoiceSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      notes: json['notes'] as String?,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      paymentMethod: json['paymentMethod'] as String? ?? 'كاش',
      installments: installments,
    );
  }

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Invoice.fromJson(data, docId: doc.id);
  }

  Map<String, dynamic> toJson() {
    final json = {
      'type': type,
      'customer': customer.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'summary': summary.toJson(),
      'notes': notes,
      'date': date.toIso8601String(),
      'invoiceNumber': invoiceNumber,
      'createdAt': createdAt.toIso8601String(),
      'paymentMethod': paymentMethod,
    };

    // إضافة الأقساط إلى JSON
    for (int i = 0; i < installments.length; i++) {
      json['payment${i + 1}'] = installments[i].toJson();
    }

    return json;
  }

  Invoice copyWith({
    String? id,
    String? type,
    Customer? customer,
    List<InvoiceItem>? items,
    InvoiceSummary? summary,
    String? notes,
    DateTime? date,
    String? invoiceNumber,
    DateTime? createdAt,
    String? paymentMethod,
    List<Installment>? installments,
  }) {
    return Invoice(
      id: id ?? this.id,
      type: type ?? this.type,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      summary: summary ?? this.summary,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdAt: createdAt ?? this.createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      installments: installments ?? this.installments,
    );
  }

  /// التحقق من أن الفاتورة فاتورة بيع
  bool get isSale => type == 'بيع';

  /// التحقق من أن الفاتورة فاتورة شراء
  bool get isPurchase => type == 'شراء';

  /// التحقق من وجود أقساط
  bool get hasInstallments => installments.isNotEmpty;

  /// الحصول على اسم العميل أو النص الافتراضي
  String get customerName => customer.name ?? 'عميل غير محدد';

  /// الحصول على رقم الهاتف أو النص الافتراضي
  String get customerPhone => customer.phone ?? 'لا يوجد';

  /// الحصول على العنوان أو النص الافتراضي
  String get customerAddress => customer.address ?? 'لا يوجد';

  /// حساب إجمالي الأقساط المدفوعة
  double get totalPaidInstallments {
    return installments
        .where((inst) => inst.isPaid)
        .fold(0.0, (sum, inst) => sum + inst.value);
  }

  /// حساب إجمالي الأقساط المعلقة
  double get totalPendingInstallments {
    return installments
        .where((inst) => !inst.isPaid)
        .fold(0.0, (sum, inst) => sum + inst.value);
  }

  /// حساب عدد الأقساط المتأخرة
  int get overdueInstallmentsCount {
    return installments.where((inst) => inst.isOverdue).length;
  }

  /// التحقق من أن جميع الأقساط مدفوعة
  bool get allInstallmentsPaid {
    if (!hasInstallments) return false;
    return installments.every((inst) => inst.isPaid);
  }
}

/// نموذج لتصفية الفواتير
class InvoiceFilter {
  final String? type; // 'بيع' أو 'شراء' أو null (الكل)
  final String? searchQuery; // البحث عن رقم الفاتورة أو اسم العميل
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final String? paymentMethod; // فلترة حسب طريقة الدفع
  final String?
  installmentStatus; // فلترة حسب حالة الأقساط (معلق، مدفوع، متأخر)

  InvoiceFilter({
    this.type,
    this.searchQuery,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.paymentMethod,
    this.installmentStatus,
  });

  bool matches(Invoice invoice) {
    // فلترة النوع
    if (type != null && invoice.type != type) {
      return false;
    }

    // فلترة البحث
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      final invoiceNumberMatches = invoice.invoiceNumber.toLowerCase().contains(
        query,
      );
      final customerNameMatches = invoice.customerName.toLowerCase().contains(
        query,
      );
      if (!invoiceNumberMatches && !customerNameMatches) {
        return false;
      }
    }

    // فلترة التاريخ
    if (startDate != null && invoice.date.isBefore(startDate!)) {
      return false;
    }
    if (endDate != null && invoice.date.isAfter(endDate!)) {
      return false;
    }

    // فلترة المبلغ
    if (minAmount != null && invoice.summary.total < minAmount!) {
      return false;
    }
    if (maxAmount != null && invoice.summary.total > maxAmount!) {
      return false;
    }

    // فلترة طريقة الدفع
    if (paymentMethod != null && invoice.paymentMethod != paymentMethod) {
      return false;
    }

    // فلترة حالة الأقساط
    if (installmentStatus != null && invoice.hasInstallments) {
      if (installmentStatus == 'مدفوع' && !invoice.allInstallmentsPaid) {
        return false;
      }
      if (installmentStatus == 'معلق' && invoice.allInstallmentsPaid) {
        return false;
      }
      if (installmentStatus == 'متأخر' &&
          invoice.overdueInstallmentsCount == 0) {
        return false;
      }
    }

    return true;
  }

  InvoiceFilter copyWith({
    String? type,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    String? paymentMethod,
    String? installmentStatus,
  }) {
    return InvoiceFilter(
      type: type ?? this.type,
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      installmentStatus: installmentStatus ?? this.installmentStatus,
    );
  }

  InvoiceFilter reset() {
    return InvoiceFilter();
  }
}
