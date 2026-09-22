import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AssetsScreen extends StatefulWidget {
  final String groupId;

  const AssetsScreen({super.key, required this.groupId});

  static const String screenroute = 'assets';

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen>
    with SingleTickerProviderStateMixin {
  String? selectedSite;
  String? selectedLocation;
  String? selectedAssetName;
  String? selectedAssetId;
  late AnimationController _animationController;

  /// ⬇️ الشهر المحدد للفلتر — null يعني عرض كل الأعمال
  DateTime? selectedMonth;
  Future<List<Map<String, dynamic>>>? _scopedWorksFuture;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildFiltersCard(),
              const SizedBox(height: 16),

              if (selectedAssetId != null) ...[
                _buildActionButtons(),
                const SizedBox(height: 16),
                _buildAssetWorks(), // ← أعمال الأصل مع فلتر الشهر
              ] else if (selectedSite != null) ...[
                _buildScopedWorks(), // ← أعمال الموقع/المكان مع فلتر الشهر
              ] else ...[
                _buildEmptyState(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 🔷 AppBar المحسّن
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'الأصول والمعدات',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1E88E5),
      foregroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      shadowColor: const Color(0xFF1E88E5).withOpacity(0.3),
    );
  }

  /// 🧱 Card الفلاتر المحسّن
  Widget _buildFiltersCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Color(0xFF1E88E5),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'الفلاتر',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSiteDropdown(),
            const SizedBox(height: 14),
            if (selectedSite != null) _buildLocationDropdown(),
            if (selectedLocation != null) _buildAssetNameDropdown(),
            if (selectedAssetName != null) _buildAssetNumberDropdown(),
          ],
        ),
      ),
    );
  }

  /// 🔽 الموقع
  Widget _buildSiteDropdown() {
    return _buildDropdownWrapper(
      icon: Icons.location_city,
      label: 'الموقع',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('assets')
            .doc(widget.groupId)
            .collection('items')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final sites = snap.data!.docs
              .map((e) => e['site'] as String)
              .toSet()
              .toList();
          final safeSelectedSite = sites.contains(selectedSite)
              ? selectedSite
              : null;

          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1E88E5),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            initialValue: safeSelectedSite,
            hint: const Text('اختر الموقع'),
            items: sites
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              setState(() {
                selectedSite = v;
                selectedLocation = null;
                selectedAssetName = null;
                selectedAssetId = null;
                selectedMonth = null;
                _scopedWorksFuture = null; // إعادة تعيين الشهر
              });
            },
          );
        },
      ),
    );
  }

  /// 🔽 المكان
  Widget _buildLocationDropdown() {
    return _buildDropdownWrapper(
      icon: Icons.place,
      label: 'المكان',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('assets')
            .doc(widget.groupId)
            .collection('items')
            .where('site', isEqualTo: selectedSite)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final locations = snap.data!.docs
              .map((e) => e['location'] as String)
              .toSet()
              .toList();
          final safeSelectedLocation = locations.contains(selectedLocation)
              ? selectedLocation
              : null;

          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1E88E5),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            initialValue: safeSelectedLocation,
            hint: const Text('اختر المكان'),
            items: locations
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) {
              setState(() {
                selectedLocation = v;
                selectedAssetName = null;
                selectedAssetId = null;
                selectedMonth = null;
                _scopedWorksFuture = null;
              });
            },
          );
        },
      ),
    );
  }

  /// 🔽 اسم الأصل
  Widget _buildAssetNameDropdown() {
    return _buildDropdownWrapper(
      icon: Icons.precision_manufacturing,
      label: 'اسم المعدة',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('assets')
            .doc(widget.groupId)
            .collection('items')
            .where('site', isEqualTo: selectedSite)
            .where('location', isEqualTo: selectedLocation)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final names = snap.data!.docs
              .map((e) => e['name'] as String)
              .toSet()
              .toList();
          // قد تصل لقطة Firestore القديمة لحظيًا بعد تعديل الاسم.
          final safeSelectedAssetName = names.contains(selectedAssetName)
              ? selectedAssetName
              : null;

          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1E88E5),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            initialValue: safeSelectedAssetName,
            hint: const Text('اختر اسم المعدة'),
            items: names
                .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                .toList(),
            onChanged: (v) {
              setState(() {
                selectedAssetName = v;
                selectedAssetId = null;
                selectedMonth = null;
                _scopedWorksFuture = null;
              });
            },
          );
        },
      ),
    );
  }

  /// 🔽 رقم المعدة
  Widget _buildAssetNumberDropdown() {
    return _buildDropdownWrapper(
      icon: Icons.numbers,
      label: 'رقم المعدة',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('assets')
            .doc(widget.groupId)
            .collection('items')
            .where('site', isEqualTo: selectedSite)
            .where('location', isEqualTo: selectedLocation)
            .where('name', isEqualTo: selectedAssetName)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final assetDocs = snap.data!.docs;
          final safeSelectedAssetId =
              assetDocs.any((doc) => doc.id == selectedAssetId)
              ? selectedAssetId
              : null;

          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1E88E5),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            initialValue: safeSelectedAssetId,
            hint: const Text('اختر رقم المعدة'),
            items: snap.data!.docs
                .map(
                  (doc) => DropdownMenuItem(
                    value: doc.id,
                    child: Text(doc['number'] ?? 'بدون رقم'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              selectedAssetId = v;
              selectedMonth = null;
              _scopedWorksFuture = null; // إعادة تعيين الشهر عند تغيير الأصل
            }),
          );
        },
      ),
    );
  }

  /// 🎯 أزرار الإجراءات
  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.picture_as_pdf,
                //   label: 'تقرير PDF',
                color: Colors.blueGrey,
                onPressed: _generateAssetPdf,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.edit,
                // label: 'تعديل الأصل',
                color: const Color.fromARGB(255, 69, 47, 157),
                onPressed: _editSelectedAsset,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.delete_outline,
                // label: 'حذف الأصل',
                color: Colors.red,
                onPressed: _showDeleteConfirmation,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 🔘 زر الإجراء
  Widget _buildActionButton({
    required IconData icon,
    // required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      //  label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color, width: 1.5),
        ),
        elevation: 0,
      ),
    );
  }

  /// 📅 اختيار الشهر
  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'اختر شهر للفلترة',
    );
    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month);
        _scopedWorksFuture = null;
      });
    }
  }

  /// 🧹 مسح فلتر الشهر
  void _clearMonthFilter() {
    setState(() {
      selectedMonth = null;
      _scopedWorksFuture = null;
    });
  }

  /// 📋 شريط فلتر الشهر
  Widget _buildMonthFilterBar({String? scopeLabel}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: Color(0xFF1E88E5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              selectedMonth == null
                  ? (scopeLabel == null
                        ? 'عرض كل الأعمال'
                        : 'عرض كل الأعمال — $scopeLabel')
                  : '${scopeLabel == null ? '' : '$scopeLabel — '}شهر: ${DateFormat('MMMM - yyyy', 'ar').format(selectedMonth!)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E88E5),
              ),
            ),
          ),
          IconButton(
            onPressed: _pickMonth,
            icon: const Icon(Icons.edit_calendar, size: 20),
            tooltip: 'اختر شهر',
          ),
          if (selectedMonth != null)
            IconButton(
              onPressed: _clearMonthFilter,
              icon: const Icon(Icons.close, size: 20, color: Colors.red),
              tooltip: 'عرض الكل',
            ),
        ],
      ),
    );
  }

  /// 📋 الأعمال المحسّنة — مع فلتر الشهر
  Widget _buildAssetWorks() {
    // ⬇️ بناء الاستعلام: لو فيه شهر محدد، نفلتر بيه (قراءات أقل)
    Query query = FirebaseFirestore.instance
        .collection('assets')
        .doc(widget.groupId)
        .collection('items')
        .doc(selectedAssetId)
        .collection('works')
        .orderBy('taskDateTime', descending: true);

    if (selectedMonth != null) {
      final start = DateTime(selectedMonth!.year, selectedMonth!.month, 1);
      final end = DateTime(selectedMonth!.year, selectedMonth!.month + 1, 1);
      query = query
          .where(
            'taskDateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          )
          .where('taskDateTime', isLessThan: Timestamp.fromDate(end));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ⬇️ شريط الفلتر دايمًا ظاهر فوق النتائج
        if (snap.data!.docs.isEmpty) {
          return Column(
            children: [
              _buildMonthFilterBar(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      selectedMonth == null
                          ? 'لا توجد أعمال لهذا الأصل'
                          : 'لا توجد أعمال في هذا الشهر',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        double total = 0;
        final works = snap.data!.docs;

        for (var doc in works) {
          final d = doc.data() as Map<String, dynamic>;
          total += (d['cost'] as num?)?.toDouble() ?? 0;
        }

        return Column(
          children: [
            _buildMonthFilterBar(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: works.length + 1,
              itemBuilder: (context, index) {
                if (index == works.length) {
                  return _buildTotalCard(total);
                }

                final doc = works[index];
                final d = doc.data() as Map<String, dynamic>;
                final date = d['taskDateTime'] != null
                    ? (d['taskDateTime'] as Timestamp).toDate()
                    : DateTime.now();

                return _buildWorkCard(
                  title: d['title'] ?? 'بدون عنوان',
                  description: d['description'] ?? '',
                  date: DateFormat('yyyy/MM/dd').format(date),
                  cost: (d['cost'] as num?)?.toDouble() ?? 0,
                  note: d['note'] ?? '',
                  index: index,
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// 📋 الأعمال على مستوى الموقع أو المكان — لا يتم الاستعلام إلا عند الطلب
  Widget _buildScopedWorks() {
    final scopeLabel = selectedLocation != null
        ? 'المكان: $selectedLocation'
        : 'الموقع: $selectedSite';

    if (_scopedWorksFuture == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildMonthFilterBar(scopeLabel: scopeLabel),
              const Icon(
                Icons.manage_search,
                size: 48,
                color: Color(0xFF1E88E5),
              ),
              const SizedBox(height: 12),
              Text(
                'جاهز للاستعلام عن $scopeLabel',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اضغط استعلام لتحميل الأعمال حسب النطاق والشهر المحدد.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _scopedWorksFuture = _loadScopedWorks();
                  });
                },
                icon: const Icon(Icons.search),
                label: const Text('استعلام'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _scopedWorksFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _buildScopeError(scopeLabel, snap.error.toString());
        }

        final works = snap.data ?? <Map<String, dynamic>>[];
        double total = 0;
        for (final work in works) {
          total += (work['cost'] as num?)?.toDouble() ?? 0;
        }

        return Column(
          children: [
            _buildMonthFilterBar(scopeLabel: scopeLabel),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generateScopedPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('تقرير PDF'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _scopedWorksFuture = _loadScopedWorks();
                    }),
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة الاستعلام'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (works.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      selectedMonth == null
                          ? 'لا توجد أعمال لهذا النطاق'
                          : 'لا توجد أعمال في هذا الشهر',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: works.length + 1,
                itemBuilder: (context, index) {
                  if (index == works.length) {
                    return _buildTotalCard(total);
                  }

                  final work = works[index];
                  final date =
                      (work['taskDateTime'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final assetLabel =
                      '${work['assetName'] ?? ''} - ${work['assetNumber'] ?? ''}'
                          .replaceAll(RegExp(r'(^ - | - $)'), '');

                  return _buildWorkCard(
                    title: work['title'] ?? 'بدون عنوان',
                    description: work['description'] ?? '',
                    date: DateFormat('yyyy/MM/dd').format(date),
                    cost: (work['cost'] as num?)?.toDouble() ?? 0,
                    note: work['note'] ?? '',
                    index: index,
                    assetLabel: assetLabel,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildScopeError(String scopeLabel, String error) {
    return Column(
      children: [
        Text('تعذر الاستعلام عن $scopeLabel'),
        const SizedBox(height: 8),
        Text(
          error,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () => setState(() {
            _scopedWorksFuture = _loadScopedWorks();
          }),
          child: const Text('إعادة المحاولة'),
        ),
      ],
    );
  }

  /// تحميل أعمال كل أصول الموقع أو المكان المحدد عند طلب الاستعلام
  Future<List<Map<String, dynamic>>> _loadScopedWorks() async {
    Query itemsQuery = FirebaseFirestore.instance
        .collection('assets')
        .doc(widget.groupId)
        .collection('items')
        .where('site', isEqualTo: selectedSite);

    if (selectedLocation != null) {
      itemsQuery = itemsQuery.where('location', isEqualTo: selectedLocation);
    }

    final itemsSnap = await itemsQuery.get();
    final result = <Map<String, dynamic>>[];
    final start = selectedMonth == null
        ? null
        : DateTime(selectedMonth!.year, selectedMonth!.month, 1);
    final end = selectedMonth == null
        ? null
        : DateTime(selectedMonth!.year, selectedMonth!.month + 1, 1);

    for (final item in itemsSnap.docs) {
      final itemData = item.data() as Map<String, dynamic>;
      final worksSnap = await item.reference
          .collection('works')
          .orderBy('taskDateTime', descending: true)
          .get();

      for (final work in worksSnap.docs) {
        final data = Map<String, dynamic>.from(work.data());
        final timestamp = data['taskDateTime'];
        final date = timestamp is Timestamp ? timestamp.toDate() : null;

        if (start != null &&
            end != null &&
            (date == null || !date.isBefore(end) || date.isBefore(start))) {
          continue;
        }

        result.add({
          ...data,
          'assetName': itemData['name'] ?? '',
          'assetNumber': itemData['number'] ?? '',
        });
      }
    }

    result.sort((a, b) {
      final aDate = (a['taskDateTime'] as Timestamp?)?.toDate();
      final bDate = (b['taskDateTime'] as Timestamp?)?.toDate();
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return result;
  }

  /// 💳 بطاقة العمل الواحد
  Widget _buildWorkCard({
    required String title,
    required String description,
    required String date,
    required double cost,
    required String note,
    required int index,
    String? assetLabel,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.build,
                      color: Color(0xFF1E88E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (assetLabel != null && assetLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'الأصل: $assetLabel',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      cost.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'الوصف: $description',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 💰 بطاقة الإجمالي
  Widget _buildTotalCard(double total) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 3,
      shadowColor: Colors.green.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade50, Colors.green.shade100],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedMonth == null
                      ? 'إجمالي التكلفة (كل الأعمال)'
                      : 'إجمالي تكلفة الشهر',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${total.toStringAsFixed(2)} ',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.attach_money,
                size: 32,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📭 حالة فارغة
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            'اختر أصل لعرض الأعمال',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بملء جميع الفلاتر لعرض سجل الأعمال',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// 🎨 Wrapper موحد للـ Dropdowns
  Widget _buildDropdownWrapper({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF1E88E5), size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  /// تحميل الأصل المحدد ثم فتح نافذة التعديل
  Future<void> _editSelectedAsset() async {
    // ثبّت المعرّف قبل أي عملية async حتى لا يتغير أثناء فتح نافذة التعديل.
    final assetId = selectedAssetId;
    if (assetId == null || assetId.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .doc(assetId)
          .get();

      if (!mounted) return;
      if (snapshot.exists) {
        await _editAssetNameAndStatus(snapshot.data()!, assetId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحميل الأصل للتعديل: $e')));
    }
  }

  /// تعديل الأصل
  Future<void> _editAssetNameAndStatus(
    Map<String, dynamic> asset,
    String assetId,
  ) async {
    final nameController = TextEditingController(
      text: asset['name']?.toString() ?? '',
    );

    String selectedStatus = asset['status']?.toString() ?? 'active';
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تعديل الأصل'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المعدة',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value:
                            const [
                              'active',
                              'inactive',
                              'maintenance',
                            ].contains(selectedStatus)
                            ? selectedStatus
                            : 'active',
                        decoration: const InputDecoration(
                          labelText: 'الحالة',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('نشط')),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('غير نشط'),
                          ),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('تحت الصيانة'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedStatus = value;
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('من فضلك أدخل اسم المعدة'),
                        ),
                      );
                      return;
                    }

                    try {
                      setDialogState(() {
                        isSaving = true;
                      });
                      // نفّذ التحديث مباشرة؛ التأخير السابق كان يجعل الزر يبدو معطّلًا.
                      await FirebaseFirestore.instance
                          .collection('assets')
                          .doc(widget.groupId)
                          .collection('items')
                          .doc(assetId)
                          .update({'name': name, 'status': selectedStatus});

                      if (!mounted) return;
                      setState(() {
                        selectedAssetName = name;
                      });
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('تم تعديل الأصل بنجاح')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('حدث خطأ أثناء التعديل: $e')),
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    // انتظر انتهاء انتقال إغلاق الحوار قبل التخلص من الكنترولر؛
    // التخلص المبكر كان يسبب: TextEditingController was used after disposed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    nameController.dispose();
  }

  /// 🗑️ تأكيد الحذف
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'تأكيد الحذف',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'هل أنت متأكد من حذف هذا الأصل نهائياً؟\nسيتم حذف جميع الأعمال المرتبطة به أيضاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAsset();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 🗑️ حذف الأصل
  Future<void> _deleteAsset() async {
    try {
      await deleteAllWorks(widget.groupId, selectedAssetId!);
      await FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .doc(selectedAssetId)
          .delete();

      setState(() {
        selectedAssetId = null;
        selectedMonth = null;
        _scopedWorksFuture = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حذف الأصل بنجاح'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحذف: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  /// 📄 تحميل الخط العربي
  Future<pw.Font> _loadArabicFont() async {
    final fontData = await rootBundle.load('assets/fonts/ElMessiri-Bold.ttf');
    return pw.Font.ttf(fontData);
  }

  /// 📄 إنشاء تقرير PDF للموقع أو المكان المستعلم عنه
  Future<void> _generateScopedPdf() async {
    if (_scopedWorksFuture == null) return;

    try {
      final works = await _scopedWorksFuture!;
      final arabicFont = await _loadArabicFont();
      const PdfColor primaryColor = PdfColor.fromInt(0xFF1E88E5);
      const PdfColor accentColor = PdfColor.fromInt(0xFFE3F2FD);
      const PdfColor successColor = PdfColor.fromInt(0xFF4CAF50);
      final scopeTitle = selectedLocation != null
          ? 'تقرير أعمال المكان'
          : 'تقرير أعمال الموقع';
      final scopeValue = selectedLocation != null
          ? '$selectedLocation'
          : '$selectedSite';
      final period = selectedMonth == null
          ? 'كل الأعمال'
          : DateFormat('MMMM - yyyy', 'ar').format(selectedMonth!);
      final pdf = pw.Document();
      double total = 0;
      final rows = <List<String>>[];

      for (final work in works) {
        final cost = (work['cost'] as num?)?.toDouble() ?? 0;
        total += cost;
        final timestamp = work['taskDateTime'];
        final date = timestamp is Timestamp
            ? timestamp.toDate()
            : DateTime.now();
        final asset =
            '${work['assetName'] ?? ''} - ${work['assetNumber'] ?? ''}'
                .replaceAll(RegExp(r'(^ - | - $)'), '');
        rows.add([
          work['note'] ?? 'لا توجد',
          DateFormat('yyyy/MM/dd').format(date),
          cost.toStringAsFixed(2),
          asset,
          work['title'] ?? 'بدون عنوان',
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            textDirection: pw.TextDirection.rtl,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
          ),
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                scopeTitle,
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: accentColor,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: primaryColor, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'النطاق: $scopeValue',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'الفترة: $period',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'تاريخ التقرير: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'سجل الأعمال والصيانة',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 10),
            if (rows.isEmpty)
              pw.Center(
                child: pw.Text(
                  'لا توجد أعمال في هذه الفترة',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
              )
            else
              pw.Table.fromTextArray(
                headers: ['ملاحظات', 'التاريخ', 'التكلفة', 'الأصل', 'العنوان'],
                data: rows,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  font: arabicFont,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(color: primaryColor),
                cellStyle: pw.TextStyle(font: arabicFont, fontSize: 9),
                cellAlignment: pw.Alignment.centerRight,
              ),
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerLeft,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 15,
              ),
              decoration: pw.BoxDecoration(
                color: accentColor,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: successColor, width: 2),
              ),
              child: pw.Text(
                'إجمالي التكلفة: ${total.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: successColor,
                ),
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (_) => pdf.save());
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: selectedLocation != null
            ? 'location_report.pdf'
            : 'site_report.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء تقرير النطاق: $e')),
        );
      }
    }
  }

  /// 📄 إنشاء تقرير PDF احترافي — بيحترم فلتر الشهر المحدد
  Future<void> _generateAssetPdf() async {
    try {
      final arabicFont = await _loadArabicFont();

      const PdfColor primaryColor = PdfColor.fromInt(0xFF1E88E5);
      const PdfColor accentColor = PdfColor.fromInt(0xFFE3F2FD);
      const PdfColor successColor = PdfColor.fromInt(0xFF4CAF50);

      final baseTextStyle = pw.TextStyle(font: arabicFont, fontSize: 10);
      final boldTextStyle = pw.TextStyle(
        font: arabicFont,
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
      );
      final headerTextStyle = pw.TextStyle(
        font: arabicFont,
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: primaryColor,
      );
      final subHeaderTextStyle = pw.TextStyle(
        font: arabicFont,
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: primaryColor,
      );
      final totalTextStyle = pw.TextStyle(
        font: arabicFont,
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: successColor,
      );

      final assetRef = FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .doc(selectedAssetId);

      final assetSnap = await assetRef.get();

      // ⬇️ الـ PDF نفسه بيحترم فلتر الشهر
      Query worksQuery = assetRef.collection('works').orderBy('taskDateTime');

      String reportPeriod = 'كل الأعمال';
      if (selectedMonth != null) {
        final start = DateTime(selectedMonth!.year, selectedMonth!.month, 1);
        final end = DateTime(selectedMonth!.year, selectedMonth!.month + 1, 1);
        worksQuery = worksQuery
            .where(
              'taskDateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('taskDateTime', isLessThan: Timestamp.fromDate(end));
        reportPeriod = DateFormat('MMMM - yyyy', 'ar').format(selectedMonth!);
      }

      final worksSnap = await worksQuery.get();

      final asset = assetSnap.data() ?? {};
      final pdf = pw.Document();
      double total = 0;

      final List<List<String>> worksData = [];
      for (final w in worksSnap.docs) {
        final rawData = w.data();

        final Map<String, dynamic> d = rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : <String, dynamic>{};

        final taskDateTime = d['taskDateTime'];

        final date = taskDateTime is Timestamp
            ? taskDateTime.toDate()
            : DateTime.now();

        final cost = (d['cost'] as num?)?.toDouble() ?? 0.0;

        total += cost;

        worksData.add([
          d['note'] ?? 'لا توجد',
          DateFormat('yyyy/MM/dd').format(date),
          '$cost',
          d['description'] ?? 'لا يوجد',
          d['title'] ?? 'بدون عنوان',
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            textDirection: pw.TextDirection.rtl,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ),
          build: (context) => [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'تقرير تفصيلي للأصل',
                    style: headerTextStyle.copyWith(color: PdfColors.white),
                  ),
                  pw.Text(
                    DateFormat('yyyy/MM/dd').format(DateTime.now()),
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 11,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // بيانات الأصل
            pw.Text('معلومات الأصل', style: subHeaderTextStyle),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: accentColor,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: primaryColor, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      pw.Text(
                        'الموقع: ${asset['site'] ?? ''}',
                        style: boldTextStyle,
                      ),
                      //  pw.SizedBox(width: 80),
                      pw.Text(
                        'المكان: ${asset['location'] ?? ''}',
                        style: boldTextStyle,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      pw.Text(
                        'اسم المعدة: ${asset['name'] ?? ''}',
                        style: boldTextStyle,
                      ),
                      //  pw.SizedBox(width: 80),
                      pw.Text(
                        'رقم المعدة: ${asset['number'] ?? ''}',
                        style: boldTextStyle,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      pw.Text(
                        'الحالة: ${asset['status'] == 'active'
                            ? 'نشط'
                            : asset['status'] == 'inactive'
                            ? 'غير نشط'
                            : 'تحت الصيانة'}',
                        style: boldTextStyle,
                      ),
                      //  pw.SizedBox(width: 80),
                      pw.Text('الفترة: $reportPeriod', style: boldTextStyle),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // جدول الأعمال
            pw.Text('سجل الأعمال والصيانة', style: subHeaderTextStyle),
            pw.SizedBox(height: 10),
            if (worksData.isEmpty)
              pw.Center(
                child: pw.Text(
                  'لا توجد أعمال في هذه الفترة',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
              )
            else
              pw.Table.fromTextArray(
                headers: ['ملاحظات', 'التاريخ', 'التكلفة', 'الوصف', 'العنوان'],
                data: worksData,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  font: arabicFont,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(color: primaryColor),
                cellStyle: baseTextStyle,
                cellAlignment: pw.Alignment.centerRight,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(1.5),
                },
              ),
            pw.SizedBox(height: 20),

            // الإجمالي
            pw.Container(
              alignment: pw.Alignment.centerLeft,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 15,
              ),
              decoration: pw.BoxDecoration(
                color: accentColor,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: successColor, width: 2),
              ),
              child: pw.Text(
                'إجمالي التكلفة: ${total.toStringAsFixed(2)} ',
                style: totalTextStyle,
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (_) => pdf.save());
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'asset_report.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء التقرير: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

/// 🗑️ حذف جميع الأعمال
Future<void> deleteAllWorks(String groupId, String assetId) async {
  final worksRef = FirebaseFirestore.instance
      .collection('assets')
      .doc(groupId)
      .collection('items')
      .doc(assetId)
      .collection('works');

  final snapshot = await worksRef.get();

  for (final doc in snapshot.docs) {
    await doc.reference.delete();
  }
}
