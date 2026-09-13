import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/Store/order_details_screen.dart';
import 'package:maintenance/Store/order_status_badge.dart';
import 'package:maintenance/Store/store_order_model.dart';
import 'package:maintenance/Store/store_order_service.dart';

class StoreOrdersScreen extends StatelessWidget {
  final String storeId;

  const StoreOrdersScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final orderService = StoreOrderService();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('طلبات المتجر')),
      body: FirestorePagination(
        query: orderService.getStoreOrdersQuery(storeId),
        limit: 2,
        viewType: ViewType.list,
        isLive: true,
        padding: const EdgeInsets.symmetric(vertical: 8),

        // التحميل الأولي
        initialLoader: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),

        // التحميل عند الوصول إلى نهاية القائمة
        bottomLoader: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),

        // حالة عدم وجود طلبات
        onEmpty: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'لا توجد طلبات حالياً',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),

        // بناء عنصر الطلب
        itemBuilder: (context, docs, index) {
          final order = StoreOrderModel.fromFirestore(docs[index]);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                tileColor: colorScheme.surface,

                // هذه الخصائص مدعومة في ListTile
                splashColor: colorScheme.primary.withOpacity(0.15),
                focusColor: colorScheme.primary.withOpacity(0.08),
                hoverColor: colorScheme.primary.withOpacity(0.05),

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),

                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: _getStatusColor(order.status),
                  child: Text(
                    order.orderNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                title: Text(
                  order.customerInfo.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${order.total.toStringAsFixed(2)} - '
                    '${order.customerInfo.phone}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),

                trailing: OrderStatusBadge(status: order.status),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(
                        order: order,
                        isFromCustomerOrders: false,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;

      case OrderStatus.confirmed:
        return Colors.blue;

      case OrderStatus.processing:
        return Colors.purple;

      case OrderStatus.shipped:
        return Colors.indigo;

      case OrderStatus.delivered:
        return Colors.green;

      case OrderStatus.cancelled:
        return Colors.red;

      case OrderStatus.refunded:
        return Colors.grey;
    }
  }
}
