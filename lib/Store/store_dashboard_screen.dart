import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maintenance/Store/store_model.dart';
import 'package:maintenance/Store/store_service.dart';
import 'package:maintenance/imageControl/platform_image.dart';
import 'package:share_plus/share_plus.dart';

class StoreDashboardScreen extends StatefulWidget {
  final String groupId;

  const StoreDashboardScreen({super.key, required this.groupId});

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  double totalSales = 0.0;
  int newOrdersCount = 0;
  bool isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final sales = await getTotalSales(widget.groupId);
    final orders = await getNoOfNewOrders(widget.groupId);

    if (mounted) {
      setState(() {
        totalSales = sales;
        newOrdersCount = orders;
        isLoadingStats = false;
      });
    }
  }

  // ========== عدد الطلبات الجديدة ==========
  Future<int> getNoOfNewOrders(String storeId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('store_orders')
          .doc(storeId)
          .collection('items')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      return querySnapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting new orders count: $e');
      return 0;
    }
  }

  // ========== إجمالي المبيعات ==========
  // ========== عدد الطلبات الجديدة ==========

  // ========== إجمالي المبيعات ==========
  Future<double> getTotalSales(String storeId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('store_orders')
          .doc(storeId)
          .collection('items')
          .where('status', isEqualTo: 'delivered')
          .get();

      double total = 0;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        total += (data['total'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('Error getting total sales: $e');
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم المتجر')),
      body: StreamBuilder<StoreModel?>(
        stream: StoreService().getMerchantStore(widget.groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final store = snapshot.data;

          if (store == null) {
            return _buildNoStoreView(context, widget.groupId);
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
            onPressed: () => context.push(
              '/store-dashboard/${Uri.encodeComponent(groupId)}/setup?isFromSettings=false',
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
                            ? WebImage(
                                src: store.logoUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              )
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
                            /*     const SizedBox(height: 4),
                            SelectableText(
                              store.storeSlug.isNotEmpty
                                  ? 'رابط المتجر: ${store.storeSlug}'
                                  : 'لم يتم تعيين رابط المتجر بعد',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                              ),
                            ), */
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () async {
                          await Share.share(
                            'تفضل بزيارة متجر "${store.name}" 🛒\n${store.storeSlug}',
                            subject: store.name,
                          );
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
                isLoadingStats ? '...' : '$newOrdersCount',
                Icons.shopping_bag,
                Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'إجمالي المبيعات',
                isLoadingStats ? '...' : '${totalSales.toStringAsFixed(2)} ',
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
            onTap: () => context.push(
              '/store-dashboard/${Uri.encodeComponent(store.id)}/products',
            ),
          ),
          _buildMenuItem(
            icon: Icons.receipt_long,
            title: 'الطلبات',
            subtitle: 'إدارة طلبات العملاء',
            onTap: () => context.push(
              '/store-dashboard/${Uri.encodeComponent(store.id)}/orders',
            ),
          ),
          _buildMenuItem(
            icon: Icons.settings,
            title: 'إعدادات المتجر',
            subtitle: 'تخصيص المظهر والمعلومات',
            onTap: () {
              // TODO: شاشة الإعدادات
              context.push(
                '/store-dashboard/${Uri.encodeComponent(store.id)}/setup?isFromSettings=true',
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.visibility,
            title: 'معاينة المتجر',
            subtitle: 'شوف متجرك زي ما العميل بيشوفه',
            onTap: () => context.push(
              Uri(
                path:
                    '/store-dashboard/${Uri.encodeComponent(store.id)}/preview',
                queryParameters: {'storeName': store.name},
              ).toString(),
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
