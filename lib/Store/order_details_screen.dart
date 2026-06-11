import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maintenance/Store/order_status_badge.dart';
import 'package:maintenance/Store/store_order_model.dart';
import 'package:maintenance/Store/store_order_service.dart';
import 'package:maintenance/imageControl/platform_image.dart';
import 'package:maintenance/invoicePage.dart';
import 'package:maintenance/models.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsScreen extends StatefulWidget {
  final StoreOrderModel order;
  final bool isFromCustomerOrders;

  const OrderDetailsScreen({
    super.key,
    required this.order,
    required this.isFromCustomerOrders,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('طلب ${widget.order.orderNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── رأس الطلب ───
            _buildOrderHeader(),
            const SizedBox(height: 20),

            // ─── شريط الحالة ───
            _buildStatusTimeline(),
            const SizedBox(height: 20),

            // ─── معلومات العميل ───
            _buildSectionTitle('معلومات العميل'),
            _buildCustomerInfo(),
            const SizedBox(height: 20),

            // ─── عنوان التوصيل ───
            _buildSectionTitle('عنوان التوصيل'),
            _buildShippingAddress(),
            const SizedBox(height: 20),

            // ─── عناصر الطلب ───
            _buildSectionTitle('عناصر الطلب'),
            _buildOrderItems(),
            const SizedBox(height: 20),

            // ─── ملخص المبالغ ───
            _buildSectionTitle('ملخص الطلب'),
            _buildOrderSummary(),
            const SizedBox(height: 20),

            // ─── تاريخ الحالة ───
            _buildSectionTitle('سجل التحديثات'),
            _buildStatusHistory(),
            const SizedBox(height: 20),

            // ─── ملاحظات ───
            if (widget.order.notes != null) ...[
              _buildSectionTitle('ملاحظات'),
              _buildNotes(),
              const SizedBox(height: 20),
            ],

            // ─── أزرار التحكم ───
            if (!widget.isFromCustomerOrders) _buildActionButtons(context),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── رأس الطلب ───
  Widget _buildOrderHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.order.orderNumber,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تاريخ الطلب: ${_formatDate(widget.order.createdAt)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                OrderStatusBadge(status: widget.order.status),
              ],
            ),
            const Divider(height: 24),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  Icons.payment,
                  _getPaymentMethodText(widget.order.paymentMethod),
                  _getPaymentStatusColor(widget.order.paymentStatus),
                ),
                if (widget.order.linkedInvoiceId == null &&
                    widget.order.status != OrderStatus.pending)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('إنشاء فاتورة بيع على الطلب'),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoicePage(
                            groupId: widget.order.storeId,
                            // InvoicePage expects a List<Map> for itemsSale. Convert each order item to the required map.
                            itemsSale: widget.order.items
                                .map(
                                  (item) => {
                                    'itemId': item.inventoryItemId,
                                    'name': item.name,
                                    'price': (item.price as num).toDouble(),
                                    'quantity': item.quantity,
                                    'total': (item.total as num).toDouble(),
                                  },
                                )
                                .toList(),
                            itemsPurchase: [],
                            name: widget.order.customerInfo.name,
                            phone: widget.order.customerInfo.phone,
                            address:
                                widget.order.shippingAddress.formattedAddress,
                            customerId: '${widget.order.customerId}',
                            isFromConstCustomers: false,
                            isFromWorkSpace: false,
                            type: 'بيع',
                          ),
                        ),
                      );
                      // TODO: فتح الفاتورة المرتبطة في ERP
                    },
                  ),
                if (widget.order.linkedInvoiceId != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('الفاتورة المرتبطة'),
                    onPressed: () {
                      // TODO: فتح الفاتورة المرتبطة في ERP
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── شريط الحالة التفاعلي ───
  Widget _buildStatusTimeline() {
    final statuses = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.processing,
      OrderStatus.shipped,
      OrderStatus.delivered,
    ];

    final currentIndex = statuses.indexOf(widget.order.status);
    final isCancelled = widget.order.status == OrderStatus.cancelled;
    final isRefunded = widget.order.status == OrderStatus.refunded;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حالة الطلب',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (isCancelled || isRefunded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCancelled ? Colors.red[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCancelled ? Colors.red : Colors.grey,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCancelled ? Icons.cancel : Icons.money_off,
                      color: isCancelled ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCancelled ? 'تم إلغاء الطلب' : 'تم استرداد المبلغ',
                      style: TextStyle(
                        color: isCancelled ? Colors.red[800] : Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: List.generate(statuses.length * 2 - 1, (index) {
                  if (index.isOdd) {
                    // خط الواصل
                    final stepIndex = index ~/ 2;
                    final isActive = stepIndex < currentIndex;
                    return Expanded(
                      child: Container(
                        height: 2,
                        color: isActive ? Colors.green : Colors.grey[300],
                      ),
                    );
                  } else {
                    // الدائرة
                    final stepIndex = index ~/ 2;
                    final isActive = stepIndex <= currentIndex;
                    final isCurrent = stepIndex == currentIndex;

                    return Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? Colors.green : Colors.grey[300],
                            border: isCurrent
                                ? Border.all(color: Colors.green, width: 3)
                                : null,
                          ),
                          child: isActive
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusLabel(statuses[stepIndex]),
                          style: TextStyle(
                            fontSize: 10,
                            color: isActive ? Colors.green : Colors.grey,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  }
                }),
              ),
          ],
        ),
      ),
    );
  }

  // ─── معلومات العميل ───
  Widget _buildCustomerInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(
              Icons.person,
              'الاسم',
              widget.order.customerInfo.name,
            ),
            const Divider(),
            // رقم الهاتف - قابل للاتصال
            _buildPhoneRow(
              Icons.phone,
              'الهاتف',
              widget.order.customerInfo.phone,
            ),
            if (widget.order.customerInfo.email != null) ...[
              const Divider(),
              _buildInfoRow(
                Icons.email,
                'البريد',
                widget.order.customerInfo.email!,
              ),
            ],
            if (widget.order.customerInfo.whatsapp != null) ...[
              const Divider(),
              // رقم الواتساب - قابل لفتح واتساب برسالة
              _buildWhatsAppRow(
                Icons.message,
                'واتساب',
                '+2${widget.order.customerInfo.whatsapp!}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── عنوان التوصيل ───
  Widget _buildShippingAddress() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.order.shippingAddress.formattedAddress,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ],
            ),
            if (widget.order.shippingAddress.landmark != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'علامة مميزة: ${widget.order.shippingAddress.landmark}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── عناصر الطلب ───
  Widget _buildOrderItems() {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.order.items.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final item = widget.order.items[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.image != null
                  ? WebImage(
                      src: item.image!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.shopping_bag),
                    ),
            ),
            title: Text(item.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.price.toStringAsFixed(2)} × ${item.quantity}'),
                if (item.selectedAttributes != null)
                  Text(
                    _formatAttributes(item.selectedAttributes!),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
            trailing: Text(
              '${item.total.toStringAsFixed(2)} ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          );
        },
      ),
    );
  }

  // ─── ملخص المبالغ ───
  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('المجموع الفرعي', widget.order.subtotal),
            if (widget.order.shippingFee > 0)
              _buildSummaryRow('مصاريف الشحن', widget.order.shippingFee),
            if (widget.order.discount != null &&
                widget.order.discount! > 0) ...[
              _buildSummaryRow(
                'الخصم ${widget.order.couponCode != null ? "(${widget.order.couponCode})" : ""}',
                -widget.order.discount!,
                isDiscount: true,
              ),
            ],
            const Divider(thickness: 1),
            _buildSummaryRow('الإجمالي', widget.order.total, isTotal: true),
          ],
        ),
      ),
    );
  }

  // ─── سجل التحديثات ───
  Widget _buildStatusHistory() {
    if (widget.order.statusHistory.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا يوجد سجل تحديثات'),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.order.statusHistory.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final update = widget.order.statusHistory[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(update.status).withOpacity(0.2),
              child: Icon(
                _getStatusIcon(update.status),
                color: _getStatusColor(update.status),
                size: 18,
              ),
            ),
            title: Text(_getStatusLabel(update.status)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (update.note != null)
                  Text(update.note!, style: const TextStyle(fontSize: 13)),
                Text(
                  _formatDate(update.timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            trailing: update.updatedBy != null
                ? Tooltip(
                    message: 'تم التحديث بواسطة: ${update.updatedBy}',
                    child: const Icon(Icons.person_outline, size: 18),
                  )
                : null,
          );
        },
      ),
    );
  }

  // ─── الملاحظات ───
  Widget _buildNotes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.notes, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.order.notes!,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── أزرار التحكم ───
  Widget _buildActionButtons(BuildContext context) {
    // تحديد الأزرار المتاحة حسب الحالة الحالية
    final List<Widget> buttons = [];

    if (widget.order.status == OrderStatus.pending) {
      buttons.add(
        _buildActionButton(
          context,
          'تأكيد الطلب',
          Icons.check_circle,
          Colors.blue,
          () => _updateStatus(context, OrderStatus.confirmed, 'تم تأكيد الطلب'),
        ),
      );
      buttons.add(
        _buildActionButton(
          context,
          'إلغاء الطلب',
          Icons.cancel,
          Colors.red,
          () => _showCancelDialog(context),
        ),
      );
    } else if (widget.order.status == OrderStatus.confirmed) {
      buttons.add(
        _buildActionButton(
          context,
          'بدء التجهيز',
          Icons.inventory,
          Colors.purple,
          () => _updateStatus(context, OrderStatus.processing, 'جاري التجهيز'),
        ),
      );
    } else if (widget.order.status == OrderStatus.processing) {
      buttons.add(
        _buildActionButton(
          context,
          'تم الشحن',
          Icons.local_shipping,
          Colors.indigo,
          () => _updateStatus(context, OrderStatus.shipped, 'تم الشحن'),
        ),
      );
    } else if (widget.order.status == OrderStatus.shipped) {
      buttons.add(
        _buildActionButton(
          context,
          'تم التوصيل',
          Icons.done_all,
          Colors.green,
          () => _updateStatus(context, OrderStatus.delivered, 'تم التوصيل'),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'إجراءات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: buttons,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─── مساعدات ───
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // صف المعلومات العادي (غير قابل للضغط)
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // صف الهاتف - قابل للاتصال
  Widget _buildPhoneRow(IconData icon, String label, String phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green[700]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _makePhoneCall(phone),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.call, size: 16, color: Colors.green[700]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // صف الواتساب - قابل لفتح واتساب برسالة
  Widget _buildWhatsAppRow(IconData icon, String label, String whatsapp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _openWhatsApp(whatsapp),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      whatsapp,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.open_in_new, size: 16, color: Colors.green[600]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== دوال المساعدة ==========
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('لا يمكن فتح تطبيق الاتصال');
    }
  }

  // فتح واتساب برسالة من التاجر للمستخدم
  Future<void> _openWhatsApp(String phoneNumber) async {
    // تنظيف الرقم من أي مسافات أو رموز
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // رسالة جاهزة من التاجر للمستخدم
    final String message =
        // 'مرحباً ${order.customerInfo.name}،\n'
        'أهلاً ${widget.order.customerInfo.name} أود التواصل معك بخصوص طلبك رقم${widget.order.orderNumber}.\n'
        'شكراً لك!';

    final Uri launchUri = Uri.parse(
      'https://wa.me/$cleanNumber?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('لا يمكن فتح واتساب');
    }
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : Colors.black87,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isDiscount
                  ? Colors.green
                  : isTotal
                  ? Colors.blue
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd - HH:mm', 'ar').format(date);
  }

  String _formatAttributes(Map<String, dynamic> attrs) {
    return attrs.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'قيد الانتظار';
      case OrderStatus.confirmed:
        return 'تم التأكيد';
      case OrderStatus.processing:
        return 'قيد التجهيز';
      case OrderStatus.shipped:
        return 'تم الشحن';
      case OrderStatus.delivered:
        return 'تم التوصيل';
      case OrderStatus.cancelled:
        return 'ملغي';
      case OrderStatus.refunded:
        return 'مسترد';
    }
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

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.hourglass_empty;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.processing:
        return Icons.inventory;
      case OrderStatus.shipped:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.money_off;
    }
  }

  String _getPaymentMethodText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cashOnDelivery:
        return 'الدفع عند الاستلام';
      case PaymentMethod.bankTransfer:
        return 'تحويل بنكي';
      case PaymentMethod.fawry:
        return 'فوري';
      case PaymentMethod.card:
        return 'بطاقة ائتمان';
    }
  }

  String _getPaymentStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'معلق';
      case PaymentStatus.paid:
        return 'تم الدفع';
      case PaymentStatus.failed:
        return 'فشل';
      case PaymentStatus.refunded:
        return 'مسترد';
    }
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.failed:
        return Colors.red;
      case PaymentStatus.refunded:
        return Colors.grey;
    }
  }

  // ─── تحديث الحالة ───
  Future<void> _updateStatus(
    BuildContext context,
    OrderStatus newStatus,
    String note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإجراء'),
        content: Text('هل تريد ${_getStatusLabel(newStatus)}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              print('تم تأكيد تغيير الحالة إلى: ${widget.order.id}');
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await StoreOrderService().updateOrderStatus(
          widget.order.storeId,
          widget.order.id,
          newStatus,
          note: note,
          order: widget.order,
          takeOrder: true,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث الحالة بنجاح')),
          );
          Navigator.pop(context); // الرجوع للقائمة
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        }
      }
    }
  }

  // ─── حوار الإلغاء ───
  Future<void> _showCancelDialog(BuildContext context) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('هل تريد إلغاء هذا الطلب؟'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'إلغاء الطلب',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus(
        context,
        OrderStatus.cancelled,
        reasonController.text.isNotEmpty
            ? 'تم الإلغاء: ${reasonController.text}'
            : 'تم إلغاء الطلب',
      );
    }
  }
}
