import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending, // قيد الانتظار
  confirmed, // تم التأكيد
  processing, // قيد التجهيز
  shipped, // تم الشحن
  delivered, // تم التوصيل
  cancelled, // ملغي
  refunded, // مسترد
}

enum PaymentMethod {
  cashOnDelivery, // الدفع عند الاستلام
  bankTransfer, // تحويل بنكي
  fawry, // فوري
  card, // بطاقة ائتمان
}

enum PaymentStatus { pending, paid, failed, refunded }

class StoreOrderModel {
  final String id;
  final String storeId;
  final String? customerId; // null للزائر
  final String orderNumber; // رقم طلب قابل للقراءة #1001
  final List<OrderItem> items;
  final CustomerInfo customerInfo;
  final ShippingAddress shippingAddress;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final double subtotal;
  final double shippingFee;
  final double? discount;
  final String? couponCode;
  final double total;
  final String? notes;
  final String? linkedInvoiceId; // ربط بفاتورة الـ ERP
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final List<OrderStatusUpdate> statusHistory;

  StoreOrderModel({
    required this.id,
    required this.storeId,
    this.customerId,
    required this.orderNumber,
    required this.items,
    required this.customerInfo,
    required this.shippingAddress,
    this.status = OrderStatus.pending,
    required this.paymentMethod,
    this.paymentStatus = PaymentStatus.pending,
    required this.subtotal,
    this.shippingFee = 0,
    this.discount,
    this.couponCode,
    required this.total,
    this.notes,
    this.linkedInvoiceId,
    required this.createdAt,
    this.confirmedAt,
    this.shippedAt,
    this.deliveredAt,
    this.statusHistory = const [],
  });

  factory StoreOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreOrderModel(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      customerId: data['customerId'],
      orderNumber: data['orderNumber'] ?? '',
      items:
          (data['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromMap(e))
              .toList() ??
          [],
      customerInfo: CustomerInfo.fromMap(data['customerInfo'] ?? {}),
      shippingAddress: ShippingAddress.fromMap(data['shippingAddress'] ?? {}),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == data['paymentMethod'],
        orElse: () => PaymentMethod.cashOnDelivery,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == data['paymentStatus'],
        orElse: () => PaymentStatus.pending,
      ),
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      shippingFee: (data['shippingFee'] ?? 0).toDouble(),
      discount: data['discount']?.toDouble(),
      couponCode: data['couponCode'],
      total: (data['total'] ?? 0).toDouble(),
      notes: data['notes'],
      linkedInvoiceId: data['linkedInvoiceId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      shippedAt: (data['shippedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      statusHistory:
          (data['statusHistory'] as List<dynamic>?)
              ?.map((e) => OrderStatusUpdate.fromMap(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'customerId': customerId,
      'orderNumber': orderNumber,
      'items': items.map((e) => e.toMap()).toList(),
      'customerInfo': customerInfo.toMap(),
      'shippingAddress': shippingAddress.toMap(),
      'status': status.name,
      'paymentMethod': paymentMethod.name,
      'paymentStatus': paymentStatus.name,
      'subtotal': subtotal,
      'shippingFee': shippingFee,
      'discount': discount,
      'couponCode': couponCode,
      'total': total,
      'notes': notes,
      'linkedInvoiceId': linkedInvoiceId,
      'createdAt': Timestamp.fromDate(createdAt),
      'confirmedAt': confirmedAt != null
          ? Timestamp.fromDate(confirmedAt!)
          : null,
      'shippedAt': shippedAt != null ? Timestamp.fromDate(shippedAt!) : null,
      'deliveredAt': deliveredAt != null
          ? Timestamp.fromDate(deliveredAt!)
          : null,
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
    };
  }
}

class OrderItem {
  final String productId;
  final String inventoryItemId;
  final String name;
  final String? image;
  final double price;
  final int quantity;
  final String? selectedColor;
  final String? selectedSize;
  final double total;
  final Map<String, dynamic>? selectedAttributes;

  OrderItem({
    required this.productId,
    required this.inventoryItemId,
    required this.name,
    this.image,
    required this.price,
    required this.quantity,
    required this.total,
    this.selectedAttributes,
    this.selectedColor,
    this.selectedSize,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      inventoryItemId: map['inventoryItemId'] ?? '',
      name: map['name'] ?? '',
      image: map['image'],
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      total: (map['total'] ?? 0).toDouble(),
      selectedAttributes: map['selectedAttributes'],
      selectedColor: map['selectedColor'] as String?,
      selectedSize: map['selectedSize'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'inventoryItemId': inventoryItemId,
      'name': name,
      'image': image,
      'price': price,
      'quantity': quantity,
      'total': total,
      'selectedAttributes': selectedAttributes,
      'selectedColor': selectedColor,
      'selectedSize': selectedSize,
    };
  }
}

class CustomerInfo {
  final String name;
  final String phone;
  final String? email;
  final String? whatsapp;

  CustomerInfo({
    required this.name,
    required this.phone,
    this.email,
    this.whatsapp,
  });

  factory CustomerInfo.fromMap(Map<String, dynamic> map) {
    return CustomerInfo(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      whatsapp: map['whatsapp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'phone': phone, 'email': email, 'whatsapp': whatsapp};
  }
}

class ShippingAddress {
  final String governorate;
  final String city;
  final String area;
  final String street;
  final String? building;
  final String? floor;
  final String? apartment;
  final String? landmark;
  final String? notes;

  ShippingAddress({
    required this.governorate,
    required this.city,
    required this.area,
    required this.street,
    this.building,
    this.floor,
    this.apartment,
    this.landmark,
    this.notes,
  });

  factory ShippingAddress.fromMap(Map<String, dynamic> map) {
    return ShippingAddress(
      governorate: map['governorate'] ?? '',
      city: map['city'] ?? '',
      area: map['area'] ?? '',
      street: map['street'] ?? '',
      building: map['building'],
      floor: map['floor'],
      apartment: map['apartment'],
      landmark: map['landmark'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'governorate': governorate,
      'city': city,
      'area': area,
      'street': street,
      'building': building,
      'floor': floor,
      'apartment': apartment,
      'landmark': landmark,
      'notes': notes,
    };
  }

  String get formattedAddress {
    final parts = [
      street,
      if (building != null) 'عمارة $building',
      if (floor != null) 'دور $floor',
      if (apartment != null) 'شقة $apartment',
      area,
      city,
      governorate,
    ];
    return parts.join('، ');
  }
}

class OrderStatusUpdate {
  final OrderStatus status;
  final String? note;
  final DateTime timestamp;
  final String? updatedBy;

  OrderStatusUpdate({
    required this.status,
    this.note,
    required this.timestamp,
    this.updatedBy,
  });

  factory OrderStatusUpdate.fromMap(Map<String, dynamic> map) {
    return OrderStatusUpdate(
      status: OrderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      note: map['note'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'note': note,
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedBy': updatedBy,
    };
  }
}
