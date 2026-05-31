import 'package:flutter/material.dart';
import 'package:maintenance/Store/store_model.dart';
import 'package:maintenance/Store/store_preview_screen.dart';
import 'package:maintenance/Store/store_service.dart';
import 'package:maintenance/Store/store_setup_screen.dart';

import 'select_products_screen.dart';
import 'store_orders_screen.dart';

class StoreDashboardScreen extends StatelessWidget {
  final String groupId;
  const StoreDashboardScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    // TODO: جلب merchantId من Firebase Auth

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم المتجر')),
      body: StreamBuilder<StoreModel?>(
        stream: StoreService().getMerchantStore(groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final store = snapshot.data;

          if (store == null) {
            return _buildNoStoreView(context, groupId);
          }

          return _buildDashboardView(context, store);
        },
      ),
    );
  }

  Widget _buildNoStoreView(BuildContext context, String groupId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'لم تقم بإنشاء متجر بعد',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoreSetupScreen(groupId: groupId),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('إنشاء متجر جديد'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView(BuildContext context, StoreModel store) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بطاقة معلومات المتجر
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: _hexToColor(store.primaryColor),
                        child: store.logoUrl != null
                            ? null
                            : Text(
                                store.name[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              store.storeUrl,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {
                          // TODO: مشاركة الرابط
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // الإحصائيات
          Row(
            children: [
              _buildStatCard(
                'الطلبات الجديدة',
                '0',
                Icons.shopping_bag,
                Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'إجمالي المبيعات',
                '0 ج.م',
                Icons.attach_money,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // الخيارات
          const Text(
            'إدارة المتجر',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildMenuItem(
            icon: Icons.inventory_2,
            title: 'اختيار المنتجات من المخزون',
            subtitle: 'اختر الأصناف التي تريد عرضها في المتجر',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SelectProductsScreen(groupId: store.id),
              ),
            ),
          ),
          _buildMenuItem(
            icon: Icons.receipt_long,
            title: 'الطلبات',
            subtitle: 'إدارة طلبات العملاء',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoreOrdersScreen(storeId: store.id),
              ),
            ),
          ),
          _buildMenuItem(
            icon: Icons.settings,
            title: 'إعدادات المتجر',
            subtitle: 'تخصيص المظهر والمعلومات',
            onTap: () {
              // TODO: شاشة الإعدادات
            },
          ),
          // في StoreDashboardScreen
          _buildMenuItem(
            icon: Icons.visibility,
            title: 'معاينة المتجر',
            subtitle: 'شوف متجرك زي ما العميل بيشوفه',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StorePreviewScreen(
                  groupId: store.id, // أو groupId
                  storeName: store.name,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
