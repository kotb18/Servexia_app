import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserDetails extends StatefulWidget {
  const UserDetails({super.key, required this.groupId});
  final String groupId;
  static const String screenroute = 'UserDetails';

  @override
  State<UserDetails> createState() => _UserDetailsState();
}

class _UserDetailsState extends State<UserDetails> {
  late Future<_GroupOverview> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _loadOverview();
  }

  Future<_GroupOverview> _loadOverview() async {
    final firestore = FirebaseFirestore.instance;
    final groupSnapshot = await firestore
        .collection('groups')
        .doc(widget.groupId)
        .get();

    final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      firestore
          .collection('teams')
          .doc(widget.groupId)
          .collection('members')
          .get(),
      firestore
          .collection('faceEmbedding')
          .doc(widget.groupId)
          .collection('users')
          .get(),
      firestore
          .collection('tasks')
          .doc(widget.groupId)
          .collection('items')
          .get(),
      firestore
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .get(),
      firestore
          .collection('inventory')
          .doc(widget.groupId)
          .collection('items')
          .get(),
      firestore
          .collection('attendance')
          .doc(widget.groupId)
          .collection('records')
          .get(),
      firestore
          .collection('invoices')
          .doc(widget.groupId)
          .collection('items')
          .get(),
      firestore
          .collection('customersSuppliers')
          .doc(widget.groupId)
          .collection('persons')
          .get(),
      firestore
          .collection('employees_permissions')
          .doc(widget.groupId)
          .collection('items')
          .get(),
      firestore
          .collection('store_orders')
          .doc(widget.groupId)
          .collection('items')
          .get(),
      firestore
          .collection('stores')
          .doc(widget.groupId)
          .collection('items')
          .get(),
    ]);

    return _GroupOverview(
      group: groupSnapshot.data() ?? <String, dynamic>{},
      sections: {
        'الأعضاء': results[0].docs,
        'بصمات الوجه': results[1].docs,
        'المهام': results[2].docs,
        'الأصول': results[3].docs,
        'المخزون': results[4].docs,
        'سجلات الحضور': results[5].docs,
        'الفواتير': results[6].docs,
        'العملاء والموردون': results[7].docs,
        'صلاحيات الموظفين': results[8].docs,
        'طلبات المتجر': results[9].docs,
        'منتجات المتجر': results[10].docs,
      },
    );
  }

  void _refresh() {
    setState(() {
      _overviewFuture = _loadOverview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('تفاصيل المجموعة'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'تحديث البيانات',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<_GroupOverview>(
          future: _overviewFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                message: 'تعذر تحميل بيانات المجموعة',
                onRetry: _refresh,
              );
            }
            if (!snapshot.hasData || snapshot.data!.group.isEmpty) {
              return _ErrorView(
                message: 'المجموعة غير موجودة أو تم حذفها',
                onRetry: _refresh,
              );
            }

            return _buildContent(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(_GroupOverview overview) {
    final group = overview.group;
    final activeSections = overview.sections.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildGroupHeader(group),
          const SizedBox(height: 16),
          _buildStats(overview.sections),
          const SizedBox(height: 20),
          const Text(
            'بيانات المجموعة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildGroupFields(group),
          const SizedBox(height: 20),
          const Text(
            'المحتوى المرتبط',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (activeSections.isEmpty)
            const _EmptySection(message: 'لا توجد بيانات مرتبطة بهذه المجموعة')
          else
            ...activeSections.map(
              (entry) => _buildSection(entry.key, entry.value),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(Map<String, dynamic> group) {
    final name = _displayValue(group['name'], fallback: 'مجموعة بدون اسم');
    final status = _displayValue(group['status'], fallback: 'غير محدد');
    return Card(
      elevation: 0,
      color: const Color(0xFF172554),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withValues(alpha: .16),
              child: const Icon(
                Icons.groups_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'المعرّف: ${widget.groupId}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .75),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _StatusBadge(status: status),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> sections,
  ) {
    final stats = <MapEntry<String, IconData>>[
      MapEntry('الأعضاء', Icons.people_alt_outlined),
      MapEntry('المهام', Icons.task_alt_outlined),
      MapEntry('الأصول', Icons.inventory_2_outlined),
      MapEntry('الفواتير', Icons.receipt_long_outlined),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(stat.value, color: const Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sections[stat.key]?.length ?? 0}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      stat.key,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupFields(Map<String, dynamic> group) {
    final fields = <String, dynamic>{
      'المسؤول': group['adminName'],
      'منطقة العمل': group['area'],
      'الغرض': group['purpose'],
      'تاريخ الإنشاء': group['createdAt'],
      'موعد الحذف': group['willDeleteAt'],
    };
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Column(
        children: fields.entries
            .where(
              (entry) =>
                  entry.value != null && entry.value.toString().isNotEmpty,
            )
            .map(
              (entry) => ListTile(
                dense: true,
                leading: const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Colors.blueGrey,
                ),
                title: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                subtitle: Text(_displayValue(entry.value)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE0E7FF),
          child: Text(
            '${documents.length}',
            style: const TextStyle(color: Color(0xFF3730A3)),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${documents.length} سجل'),
        children: documents.map(_buildDocumentTile).toList(),
      ),
    );
  }

  Widget _buildDocumentTile(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final visibleFields = data.entries.take(4).toList();
    return ListTile(
      dense: true,
      leading: const Icon(Icons.description_outlined, size: 20),
      title: Text(
        _displayValue(
          data['name'] ?? data['title'] ?? data['employeeName'],
          fallback: document.id,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: visibleFields.isEmpty
          ? Text('المعرّف: ${document.id}')
          : Text(
              visibleFields
                  .map((entry) => '${entry.key}: ${_displayValue(entry.value)}')
                  .join('  |  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }

  String _displayValue(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    if (value is Timestamp) return _formatDate(value.toDate());
    if (value is DateTime) return _formatDate(value);
    if (value is List) return value.join(', ');
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(', ');
    }
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _GroupOverview {
  const _GroupOverview({required this.group, required this.sections});

  final Map<String, dynamic> group;
  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> sections;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active' || status == 'نشط';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isActive ? Colors.green : Colors.orange).withValues(alpha: .18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isActive ? Colors.greenAccent : Colors.orangeAccent,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(message, style: const TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
