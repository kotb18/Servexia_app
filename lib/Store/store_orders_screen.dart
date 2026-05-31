import 'package:flutter/material.dart';
import 'package:maintenance/Store/order_status_badge.dart';
import 'package:maintenance/Store/store_order_model.dart';
import 'package:maintenance/Store/store_order_service.dart';

class StoreOrdersScreen extends StatelessWidget {
  final String storeId;

  const StoreOrdersScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final orderService = StoreOrderService();

    return Scaffold(
      appBar: AppBar(title: const Text('طلبات المتجر')),
      body: StreamBuilder<List<StoreOrderModel>>(
        stream: orderService.getStoreOrders(storeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(child: Text('لا توجد طلبات حالياً'));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
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
                  title: Text(order.customerInfo.name),
                  subtitle: Text(
                    '${order.total.toStringAsFixed(2)} ج.م - ${order.customerInfo.phone}',
                  ),
                  trailing: OrderStatusBadge(status: order.status),
                  onTap: () {
                    // TODO: شاشة تفاصيل الطلب
                  },
                ),
              );
            },
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
