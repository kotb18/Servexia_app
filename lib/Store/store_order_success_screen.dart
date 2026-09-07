import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maintenance/Store/store_order_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreOrderSuccessScreen extends StatelessWidget {
  final StoreOrderModel order;

  const StoreOrderSuccessScreen({super.key, required this.order});

  /// ═══════════════════════════════════════════════════════════════════
  /// 📱 نص المشاركة المُنسّق
  /// ═══════════════════════════════════════════════════════════════════
  String get _shareText {
    final buffer = StringBuffer();
    buffer.writeln('🛒 طلب جديد من المتجر');
    buffer.writeln('━━━━━━━━━━━━━━');
    buffer.writeln('📋 رقم الطلب: #${order.orderNumber}');
    buffer.writeln('👤 الاسم: ${order.customerInfo.name}');
    buffer.writeln('📱 الهاتف: ${order.customerInfo.phone}');
    buffer.writeln('📍 العنوان: ${order.shippingAddress.formattedAddress}');
    buffer.writeln(
      '💳 طريقة الدفع: ${_getPaymentMethodText(order.paymentMethod)}',
    );
    buffer.writeln('━━━━━━━━━━━━━━');

    // 🛍️ المنتجات — ⚠️ عدّل أسماء الحقول دي حسب الـ StoreOrderModel بتاعك
    // if (order.items != null) {
    //   buffer.writeln('🛍️ المنتجات:');
    //   for (final item in order.items) {
    //     buffer.writeln('• ${item.name} ×${item.quantity} — ${item.price.toStringAsFixed(2)}');
    //   }
    //   buffer.writeln('━━━━━━━━━━━━━━');
    // }

    buffer.writeln('💰 الإجمالي: ${order.total.toStringAsFixed(2)}');
    return buffer.toString();
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 💬 مشاركة عبر واتساب
  /// ═══════════════════════════════════════════════════════════════════
  Future<void> _shareOnWhatsApp(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_shareText)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // واتساب مش متسطب — نستخدم المشاركة العادية
      _shareGeneric();
    }
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 📤 مشاركة عامة (أي تطبيق)
  /// ═══════════════════════════════════════════════════════════════════
  void _shareGeneric() {
    Share.share(_shareText, subject: 'طلب #${order.orderNumber}');
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 🏠 العودة للمتجر (بتنضف السلة قبل الرجوع)
  /// ═══════════════════════════════════════════════════════════════════
  void _backToStore(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ═══════════════════════════════════════
                // ✅ أيقونة النجاح مع أنيميشن
                // ═══════════════════════════════════════
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 80,
                          color: Colors.green.shade600,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // عنوان
                const Text(
                  'تم تأكيد طلبك بنجاح! 🎉',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // رقم الطلب
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    'رقم الطلب: #${order.orderNumber}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ═══════════════════════════════════════
                // 📋 تفاصيل الطلب
                // ═══════════════════════════════════════
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('الاسم', order.customerInfo.name),
                        _buildDetailRow('الهاتف', order.customerInfo.phone),
                        _buildDetailRow(
                          'العنوان',
                          order.shippingAddress.formattedAddress,
                        ),
                        _buildDetailRow(
                          'طريقة الدفع',
                          _getPaymentMethodText(order.paymentMethod),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'الإجمالي',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${order.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ═══════════════════════════════════════
                // ℹ️ ملاحظة
                // ═══════════════════════════════════════
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'سنقوم بالتواصل معك قريباً لتأكيد الطلب وترتيب التوصيل.',
                          style: TextStyle(color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ═══════════════════════════════════════
                // 💬 زر واتساب
                // ═══════════════════════════════════════
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareOnWhatsApp(context),
                    icon: const Icon(Icons.chat),
                    label: const Text(
                      'مشاركة عبر واتساب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ═══════════════════════════════════════
                // 📤 زر المشاركة العامة
                // ═══════════════════════════════════════
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _shareGeneric,
                    icon: const Icon(Icons.share),
                    label: const Text(
                      'مشاركة الطلب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ═══════════════════════════════════════
                // 🏪 زر العودة للمتجر
                // ═══════════════════════════════════════
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () => _backToStore(context),
                    child: Text(
                      'العودة للمتجر',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 🔧 HELPERS
  /// ═══════════════════════════════════════════════════════════════════
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
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
}
