import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maintenance/Store/store_order_model.dart';

class StoreOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _orders => _firestore.collection('store_orders');
  CollectionReference get _counters => _firestore.collection('counters');

  // إنشاء طلب جديد
  Future<StoreOrderModel> createOrder(StoreOrderModel order) async {
    // توليد رقم الطلب تلقائياً
    final orderNumber = await _generateOrderNumber(order.storeId);

    final orderWithNumber = StoreOrderModel(
      id: order.id,
      storeId: order.storeId,
      customerId: order.customerId,
      orderNumber: orderNumber,
      items: order.items,
      customerInfo: order.customerInfo,
      shippingAddress: order.shippingAddress,
      status: order.status,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus,
      subtotal: order.subtotal,
      shippingFee: order.shippingFee,
      discount: order.discount,
      couponCode: order.couponCode,
      total: order.total,
      notes: order.notes,
      createdAt: DateTime.now(),
      statusHistory: [
        OrderStatusUpdate(
          status: OrderStatus.pending,
          note: 'تم إنشاء الطلب',
          timestamp: DateTime.now(),
        ),
      ],
    );

    await _orders
        .doc(orderWithNumber.storeId)
        .collection('items')
        .add(orderWithNumber.toMap());

    // TODO: Cloud Function يخصم الكمية من المخزون وينشئ فاتورة في ERP

    return orderWithNumber;
  }

  // توليد رقم طلب فريد
  Future<String> _generateOrderNumber(String storeId) async {
    final counterRef = _counters.doc(storeId);

    return _firestore.runTransaction((transaction) async {
      final counterDoc = await transaction.get(counterRef);
      int currentNumber = 1;

      if (counterDoc.exists) {
        currentNumber =
            (counterDoc.data() as Map<String, dynamic>)['count'] ?? 0;
        currentNumber++;
      }

      transaction.set(counterRef, {'count': currentNumber});
      return '#${currentNumber.toString().padLeft(4, '0')}';
    });
  }

  // جلب طلبات المتجر (للتاجر)
  Stream<List<StoreOrderModel>> getStoreOrders(
    String storeId, {
    OrderStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    Query query = _orders
        .doc(storeId)
        .collection('items')
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => StoreOrderModel.fromFirestore(doc))
          .toList(),
    );
  }

  // جلب طلبات العميل
  Stream<List<StoreOrderModel>> getCustomerOrders(
    String groupId,
    String customerId,
  ) {
    return _orders
        .doc(groupId)
        .collection('items')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StoreOrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  // جلب طلب بالـ ID
  Future<StoreOrderModel?> getOrderById(String storeId, String orderId) async {
    final doc = await _orders
        .doc(storeId)
        .collection('items')
        .doc(orderId)
        .get();
    if (!doc.exists) return null;
    return StoreOrderModel.fromFirestore(doc);
  }

  // تحديث حالة الطلب
  Future<void> updateOrderStatus(
    String storeId,
    String orderId,
    OrderStatus newStatus, {
    String? note,
    String? updatedBy,
    StoreOrderModel? order,
    bool notifyCustomer = true,
    bool? takeOrder,
  }) async {
    if (takeOrder == false) {
      order = await getOrderById(storeId, orderId);
    }

    if (order == null) return;

    final statusUpdate = OrderStatusUpdate(
      status: newStatus,
      note: note,
      timestamp: DateTime.now(),
      updatedBy: updatedBy,
    );

    final updates = <String, dynamic>{
      'status': newStatus.name,
      'statusHistory': FieldValue.arrayUnion([statusUpdate.toMap()]),
    };

    // تحديث التواريخ المحددة
    switch (newStatus) {
      case OrderStatus.confirmed:
        updates['confirmedAt'] = Timestamp.fromDate(DateTime.now());
        break;
      case OrderStatus.shipped:
        updates['shippedAt'] = Timestamp.fromDate(DateTime.now());
        break;
      case OrderStatus.delivered:
        updates['deliveredAt'] = Timestamp.fromDate(DateTime.now());
        break;
      default:
        break;
    }

    await _orders.doc(storeId).collection('items').doc(orderId).update(updates);
  }
}
