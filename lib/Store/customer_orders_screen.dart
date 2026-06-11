import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maintenance/Store/order_status_badge.dart';
import 'package:maintenance/Store/store_order_model.dart';
import 'package:maintenance/Store/store_order_service.dart';
import 'package:maintenance/Store/order_details_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  final String customerId;
  final String groupId;

  const MyOrdersScreen({
    super.key,
    required this.customerId,
    required this.groupId,
  });

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  @override
  Widget build(BuildContext context) {
    final orderService = StoreOrderService();

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي'), centerTitle: true),
      body: StreamBuilder<List<StoreOrderModel>>(
        stream: orderService.getCustomerOrders(
          widget.groupId,
          widget.customerId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('حدث خطأ: ${snapshot.error}'),
                ],
              ),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(context, order);
            },
          );
        },
      ),
    );
  }

  // ─── حالة فارغة ───
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد طلبات حالياً',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ التسوق واطلب الآن!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: الانتقال للمتجر
              Navigator.pop(context);
            },
            icon: const Icon(Icons.store),
            label: const Text('تصفح المتجر'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ─── كارت الطلب ───
  Widget _buildOrderCard(BuildContext context, StoreOrderModel order) {
    final bool canCancel = order.status == OrderStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  OrderDetailsScreen(order: order, isFromCustomerOrders: true),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── الصف العلوي: الرقم + الحالة ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.orderNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(order.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const Divider(height: 20),

              // ─── عناصر الطلب المختصرة ───
              Row(
                children: [
                  // صورة أول منتج أو أيقونة
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        order.items.isNotEmpty &&
                            order.items.first.image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              order.items.first.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.shopping_bag,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : const Icon(Icons.shopping_bag, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.items.isNotEmpty
                              ? order.items.first.name
                              : 'لا توجد عناصر',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (order.items.length > 1)
                          Text(
                            'و ${order.items.length - 1} منتجات أخرى',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ─── الصف السفلي: السعر + زر الإلغاء ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإجمالي',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        '${order.total.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // زر التفاصيل
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailsScreen(
                                order: order,
                                isFromCustomerOrders: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('التفاصيل'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // زر الإلغاء (يظهر فقط لو pending)
                      if (canCancel)
                        ElevatedButton.icon(
                          onPressed: () => _showCancelDialog(context, order),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('إلغاء'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── حوار إلغاء الطلب ───
  Future<void> _showCancelDialog(
    BuildContext context,
    StoreOrderModel order,
  ) async {
    final reasonController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.cancel, color: Colors.red),
                const SizedBox(width: 8),
                const Text('إلغاء الطلب'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هل تريد إلغاء الطلب ${order.orderNumber}؟',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'سبب الإلغاء (اختياري)',
                    hintText: 'مثال: غيرت رأيي',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.amber[800], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'يمكن الإلغاء فقط للطلبات قيد الانتظار',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('تراجع'),
              ),
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);
                        try {
                          await StoreOrderService().updateOrderStatus(
                            widget.groupId,
                            order.id,
                            OrderStatus.cancelled,
                            note: reasonController.text.isNotEmpty
                                ? 'إلغاء من العميل: ${reasonController.text}'
                                : 'تم الإلغاء بواسطة العميل',
                            order: order,
                          );
                          print(
                            'Order ${order.id} cancelled by customer. Reason: ${reasonController.text}',
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إلغاء الطلب بنجاح'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('خطأ: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cancel),
                label: const Text('تأكيد الإلغاء'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'ar').format(date);
  }
}
