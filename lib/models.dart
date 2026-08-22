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
  final double quantity;
  final double price;
  final double total;
  final String? itemId; // معرّف الصنف (اختياري، يستخدم لاستعادة المخزون)

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    required this.itemId,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as double? ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      itemId: '${json['itemId'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'total': total,
      'itemId': itemId,
    };
  }

  InvoiceItem copyWith({
    String? name,
    double? quantity,
    double? price,
    double? total,
  }) {
    return InvoiceItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      total: total ?? this.total,
      itemId: itemId ?? '',
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

class ReturnSummary {
  final double totalBeforeReturn;
  final double totalPaidInstallments;
  final double total;
  final double netTotal;

  ReturnSummary({
    required this.totalBeforeReturn,
    required this.totalPaidInstallments,
    required this.total,
    required this.netTotal,
  });

  factory ReturnSummary.fromJson(Map<String, dynamic> json) {
    return ReturnSummary(
      totalBeforeReturn: (json['totalBeforeReturn'] as num?)?.toDouble() ?? 0.0,
      totalPaidInstallments:
          (json['totalPaidInstallments'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      netTotal: (json['netTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalBeforeReturn': totalBeforeReturn,
      'totalPaidInstallments': totalPaidInstallments,
      'total': total,
      'netTotal': netTotal,
    };
  }

  ReturnSummary copyWith({
    double? totalBeforeReturn,
    double? totalPaidInstallments,
    double? total,
    double? netTotal,
  }) {
    return ReturnSummary(
      totalBeforeReturn: totalBeforeReturn ?? this.totalBeforeReturn,
      totalPaidInstallments:
          totalPaidInstallments ?? this.totalPaidInstallments,
      total: total ?? this.total,
      netTotal: netTotal ?? this.netTotal,
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
  bool get isPending => status == '!';

  /// التحقق من أن القسط متأخر
  bool get isOverdue =>
      (DateTime.now().isAfter(date) && status == '!') || (status == 'متأخر');

  /// الحصول على لون الحالة
  String get statusColor {
    if (isPaid) return '#10B981'; // أخضر
    if (isOverdue) return '#EF4444'; // أحمر
    if (isPending) return '#F59E0B';
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
  final String returnType; // 'مرتجع بيع' أو 'مرتجع شراء' (للفواتير المرتجعة)
  final Customer customer;
  final List<InvoiceItem> items;
  final InvoiceSummary summary;
  final String? notes;
  final DateTime date;
  final String invoiceNumber;
  final String companyName; // اسم الشركة (للفواتير المرتجعة)
  final String companyAddress; // عنوان الشركة (للفواتير المرتجعة)
  final String companyPhone; // هاتف الشركة (للفواتير المرتجعة)
  final String companyEmail; // بريد الشركة (للفواتير المرتجعة)
  final String companyLogoUrl; // رابط شعار الشركة (للفواتير المرتجعة)
  final String companyTaxNumber; // رقم ضريبة الشركة (للفواتير المرتجعة)
  final bool isQuote; // هل الفاتورة عرض سعر
  final bool showLogo; // هل تظهر تفاصيل الشركة في الفاتورة
  final bool showAddress; // هل تظهر عنوان الشركة في الفاتورة
  final bool showPhone; // هل يظهر هاتف الشركة في الفاتورة
  final bool showEmail; // هل يظهر بريد الشركة في الفاتورة
  final bool showNotes;
  final bool showDiscount; // هل يظهر رقم ضريبة الشركة في الفاتورة
  final bool showTax; // هل يظهر ضريبة الفاتورة في الفاتورة
  final DateTime createdAt;
  final String paymentMethod; // 'كاش', 'شيك', 'تحويل بنكي', إلخ
  final String originalInvoiceId;
  final List<Installment> installments; // الأقساط (إذا كانت موجودة)
  final bool
  thereIsReturn; // هل هناك فاتورة مرتجعة مرتبطة بهذه الفاتورة (للفواتير الأصلية)
  final String reInvoiceId; // معرّف الفاتورة الأصلية (للفواتير المرتجعة)
  // معرّف الفاتورة المرتجعة (للفواتير الأصلية)
  final ReturnSummary? returnSummary;

  Invoice({
    this.id,
    required this.type,
    required this.returnType,
    required this.customer,
    required this.items,
    required this.summary,
    this.notes,
    required this.date,
    required this.invoiceNumber,
    required this.createdAt,
    required this.paymentMethod,
    this.installments = const [],
    required this.thereIsReturn,
    required this.reInvoiceId,
    required this.originalInvoiceId,
    required this.returnSummary,
    required this.companyName,
    required this.companyAddress,
    required this.companyPhone,
    required this.companyEmail,
    required this.companyLogoUrl,
    required this.companyTaxNumber,
    required this.isQuote,
    required this.showLogo,
    required this.showAddress,
    required this.showPhone,
    required this.showEmail,
    required this.showNotes,
    required this.showDiscount,
    required this.showTax,
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
      returnType: json['returnType'] as String? ?? '',
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
      thereIsReturn: json['thereIsReturn'] as bool? ?? false,
      reInvoiceId: json['reInvoiceId'] as String,
      originalInvoiceId: json['originalInvoiceId'] as String? ?? '',
      returnSummary: ReturnSummary.fromJson(
        json['returnSummary'] as Map<String, dynamic>? ?? {},
      ),
      companyName: json['companyName'] as String? ?? '',
      companyAddress: json['companyAddress'] as String? ?? '',
      companyPhone: json['companyPhone'] as String? ?? '',
      companyEmail: json['companyEmail'] as String? ?? '',
      companyLogoUrl: json['companyLogoUrl'] as String? ?? '',
      companyTaxNumber: json['companyTaxNumber'] as String? ?? '',
      isQuote: json['isQuote'] as bool? ?? false,
      showLogo: json['showLogo'] as bool? ?? false,
      showAddress: json['showAddress'] as bool? ?? false,
      showPhone: json['showPhone'] as bool? ?? false,
      showEmail: json['showEmail'] as bool? ?? false,
      showNotes: json['showNotes'] as bool? ?? false,
      showDiscount: json['showDiscount'] as bool? ?? false,
      showTax: json['showTax'] as bool? ?? false,
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
      'thereIsReturn': thereIsReturn,
      'reInvoiceId': reInvoiceId,
      'originalInvoiceId': originalInvoiceId,
      'returnType': returnType,
      'returnSummary': returnSummary!.toJson(),
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
    String? returnType,
    String? originalInvoiceId,
    ReturnSummary? returnSummary,
  }) {
    return Invoice(
      id: id ?? this.id,
      type: type ?? this.type,
      returnType: returnType ?? this.returnType,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      summary: summary ?? this.summary,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdAt: createdAt ?? this.createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      installments: installments ?? this.installments,
      thereIsReturn: thereIsReturn,
      reInvoiceId: reInvoiceId,
      originalInvoiceId: originalInvoiceId ?? this.originalInvoiceId,
      returnSummary: returnSummary ?? this.returnSummary,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      companyLogoUrl: companyLogoUrl,
      companyTaxNumber: companyTaxNumber,
      isQuote: isQuote,
      showLogo: showLogo,
      showAddress: showAddress,
      showPhone: showPhone,
      showEmail: showEmail,
      showNotes: showNotes,
      showDiscount: showDiscount,
      showTax: showTax,
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

  String get customerId => customer.id ?? 'عميل غير محدد';

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
