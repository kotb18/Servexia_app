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
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1E88E5),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'عرض الأصول حسب الموقع',
          icon: const Icon(Icons.view_agenda_outlined),
          onPressed: _showSitesSheet,
        ),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      shadowColor: const Color(0xFF1E88E5).withValues(alpha: 0.3),
    );
  }

  /// فتح قائمة المواقع من أيقونة الـ AppBar ثم الانتقال لشاشة العرض.
  Future<void> _showSitesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'اختر الموقع لعرض الأصول',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('assets')
                      .doc(widget.groupId)
                      .collection('items')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildSheetMessage(
                        Icons.error_outline,
                        'تعذر تحميل المواقع',
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final sites =
                        snapshot.data!.docs
                            .map((doc) => doc.data()['site'])
                            .whereType<String>()
                            .where((site) => site.trim().isNotEmpty)
                            .toSet()
                            .toList()
                          ..sort();

                    if (sites.isEmpty) {
                      return _buildSheetMessage(
                        Icons.location_off_outlined,
                        'لا توجد مواقع مسجلة',
                      );
                    }

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: sites.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final site = sites[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE3F2FD),
                              child: Icon(
                                Icons.location_city,
                                color: Color(0xFF1E88E5),
                              ),
                            ),
                            title: Text(site),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              setState(() {
                                selectedSite = site;
                                selectedLocation = null;
                                selectedAssetName = null;
                                selectedAssetId = null;
                                selectedMonth = null;
                                _scopedWorksFuture = null; // إعادة تعيين الشهر
                              });

                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ViewAssets(
                                    groupId: widget.groupId,
                                    siteName: site,
                                  ),
                                ),
                              );

                              // بعد await تكون result هي القيمة نفسها وليست Future،
                              // لذلك لا نستخدم result.then هنا.
                              if (!mounted) return;
                              if (result is Map) {
                                setState(() {
                                  selectedSite =
                                      result['site']?.toString() ?? site;
                                  selectedLocation = result['location']
                                      ?.toString();
                                  selectedAssetName = result['name']
                                      ?.toString();
                                  selectedAssetId = result['id']?.toString();
                                });
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetMessage(IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  /// 🧱 Card الفلاتر المحسّن
  Widget _buildFiltersCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
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
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
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
        backgroundColor: color.withValues(alpha: 0.1),
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
      shadowColor: Colors.black.withValues(alpha: 0.08),
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
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
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
                      color: Colors.green.withValues(alpha: 0.1),
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
                    color: Colors.amber.withValues(alpha: 0.1),
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
      shadowColor: Colors.green.withValues(alpha: 0.2),
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
                color: Colors.green.withValues(alpha: 0.2),
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
    // ⬇️ كنترولر الموديل الجديد
    final modelController = TextEditingController(
      text: asset['model']?.toString() ?? '',
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

                      // ⬇️ حقل الموديل الجديد
                      TextField(
                        controller: modelController,
                        decoration: const InputDecoration(
                          labelText: 'الموديل',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue:
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
                    // ⬇️ قراءة قيمة الموديل
                    final model = modelController.text.trim();

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
                      // ⬇️ حفظ الموديل مع الاسم والحالة
                      await FirebaseFirestore.instance
                          .collection('assets')
                          .doc(widget.groupId)
                          .collection('items')
                          .doc(assetId)
                          .update({
                            'name': name,
                            'model': model,
                            'status': selectedStatus,
                          });

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

    // انتظر انتهاء انتقال إغلاق الحوار قبل التخلص من الكنترولرات
    await Future<void>.delayed(const Duration(milliseconds: 300));
    nameController.dispose();
    modelController.dispose(); // ⬇️ لا تنسَ التخلص من الكنترولر الجديد
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

/// شاشة عرض الأصول فقط.
///
/// مسار البيانات:
/// assets/{groupId}/items
/// مع تصفية العناصر حسب الحقل site = siteName.
class ViewAssets extends StatelessWidget {
  const ViewAssets({super.key, required this.siteName, required this.groupId});

  final String groupId;
  final String siteName;

  CollectionReference<Map<String, dynamic>> get _itemsRef => FirebaseFirestore
      .instance
      .collection('assets')
      .doc(groupId)
      .collection('items');

  Query<Map<String, dynamic>> get _siteQuery =>
      _itemsRef.where('site', isEqualTo: siteName);

  String _text(
    Map<String, dynamic> data,
    String key, {
    String fallback = 'غير محدد',
  }) {
    final value = data[key];
    if (value == null || value.toString().trim().isEmpty) return fallback;
    if (key == 'status') {
      switch (value.toString()) {
        case 'active':
          return 'نشط';
        case 'inactive':
          return 'غير نشط';
        case 'maintenance':
          return 'تحت الصيانة';
        default:
          return fallback;
      }
    }
    return value.toString();
  }

  /// ترتيب الأصول بعد جلبها من Firestore:
  /// 1) تجميع الأصول التي في نفس المكان معًا.
  /// 2) ترتيب اسم الأصل داخل المكان.
  /// 3) عند تشابه اسم الأصل، ترتيب الرقم من الأصغر إلى الأكبر.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortAssets(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sortedDocs = docs.toList();

    String textValue(Map<String, dynamic> data, String key) {
      final value = data[key];
      return value?.toString().trim().toLowerCase() ?? '';
    }

    int? numericAssetNumber(dynamic value) {
      if (value is num) return value.toInt();
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) return null;

      final directNumber = int.tryParse(text);
      if (directNumber != null) return directNumber;

      // يدعم أرقامًا مثل: AST-002 أو أصل 12.
      final match = RegExp(r'\d+').firstMatch(text);
      return match == null ? null : int.tryParse(match.group(0)!);
    }

    sortedDocs.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      // المكان أولًا حتى تكون كل أصول المكان الواحد متجاورة.
      final locationCompare = textValue(
        aData,
        'location',
      ).compareTo(textValue(bData, 'location'));
      if (locationCompare != 0) return locationCompare;

      // ثم اسم الأصل لتجميع الأصول ذات الاسم المتشابه.
      final nameCompare = textValue(
        aData,
        'name',
      ).compareTo(textValue(bData, 'name'));
      if (nameCompare != 0) return nameCompare;

      // ثم الرقم تصاعديًا كرقم وليس كنص: 2 قبل 10.
      final aNumber = numericAssetNumber(aData['number']);
      final bNumber = numericAssetNumber(bData['number']);
      if (aNumber != null && bNumber != null && aNumber != bNumber) {
        return aNumber.compareTo(bNumber);
      }
      if (aNumber != null && bNumber == null) return -1;
      if (aNumber == null && bNumber != null) return 1;

      // ترتيب ثابت عند تساوي كل الحقول السابقة.
      return a.id.compareTo(b.id);
    });

    return sortedDocs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadAssets() async {
    final snapshot = await _siteQuery.get();
    return _sortAssets(snapshot.docs);
  }

  Future<void> _makePdf(BuildContext context, {required bool share}) async {
    try {
      final docs = await _loadAssets();
      if (docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد أصول لإنشاء ملف PDF')),
          );
        }
        return;
      }

      // الخط الافتراضي في package:pdf لا يحتوي على الحروف العربية.
      // أضف ملفات Cairo إلى assets/fonts في المشروع كما هو موضح في الرد.
      final arabicRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
      );
      final arabicBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'),
      );
      final pdf = pw.Document();
      final rows = docs.map((doc) {
        final data = doc.data();
        return [
          _text(data, 'status'),
          _text(data, 'model'),
          _text(data, 'location'),
          _text(data, 'number', fallback: 'بدون رقم'),
          _text(data, 'name', fallback: 'بدون اسم'),
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicRegular, bold: arabicBold),
          build: (_) => [
            pw.Header(level: 0, child: pw.Text('تقرير أصول الموقع: $siteName')),
            pw.SizedBox(height: 12),
            pw.Text('عدد الأصول: ${docs.length}'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: const [
                'الحالة',
                'الموديل',
                'المكان',
                'الرقم',
                'اسم الأصل',
              ],
              data: rows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue100,
              ),
              cellAlignment: pw.Alignment.centerRight,
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(color: PdfColors.grey400),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      if (share) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'assets_${siteName.replaceAll(RegExp(r'\s+'), '_')}.pdf',
        );
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إنشاء ملف PDF: $error'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  bool _matchesSearch(Map<String, dynamic> data, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    const searchableFields = [
      'name',
      'number',
      'location',
      'type',
      'status',
      'serialNumber',
      'model',
      'manufacturer',
    ];

    return searchableFields.any((field) {
      final value = data[field]?.toString().toLowerCase() ?? '';
      return value.contains(normalizedQuery);
    });
  }

  Widget _buildSearchableBody() {
    var searchText = '';
    final searchController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: searchController,
                //  textDirection: TextDirection.RTL,
                onChanged: (value) {
                  setLocalState(() => searchText = value);
                },
                decoration: InputDecoration(
                  hintText: 'ابحث باسم الأصل أو الرقم أو المكان...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchText.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح البحث',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            setLocalState(() => searchText = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1E88E5),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _siteQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _MessageState(
                      icon: Icons.error_outline,
                      title: 'تعذر تحميل الأصول',
                      subtitle: snapshot.error.toString(),
                      action: ElevatedButton.icon(
                        onPressed: () => (context as Element).markNeedsBuild(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final sortedDocs = _sortAssets(
                    snapshot.data?.docs ?? const [],
                  );
                  final docs = sortedDocs
                      .where((doc) => _matchesSearch(doc.data(), searchText))
                      .toList();

                  if (docs.isEmpty) {
                    return _MessageState(
                      icon: searchText.trim().isEmpty
                          ? Icons.inventory_2_outlined
                          : Icons.search_off,
                      title: searchText.trim().isEmpty
                          ? 'لا توجد أصول'
                          : 'لا توجد نتائج مطابقة',
                      subtitle: searchText.trim().isEmpty
                          ? 'لا توجد أصول مسجلة في موقع $siteName'
                          : 'جرّب البحث باسم أو رقم أصل آخر',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _AssetCard(
                      data: docs[index].data(),
                      documentId: docs[index].id,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('أصول $siteName'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: () => (context as Element).markNeedsBuild(),
          ),
        ],
      ),
      body: _buildSearchableBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: FloatingActionButton.extended(
                  heroTag: 'previewAssetsPdf',
                  onPressed: () => _makePdf(context, share: false),
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('معاينة PDF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FloatingActionButton.extended(
                  heroTag: 'shareAssetsPdf',
                  onPressed: () => _makePdf(context, share: true),
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.share),
                  label: const Text('مشاركة PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.data, required this.documentId});

  final Map<String, dynamic> data;
  final String documentId;

  String _value(String key, {String fallback = 'غير محدد'}) {
    final value = data[key];
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final name = _value('name', fallback: 'أصل بدون اسم');
    final number = _value('number', fallback: 'بدون رقم');
    final location = _value('location');
    //  final type = _value('type');
    final status = _value('status');
    // final serialNumber = _value('serialNumber');
    final model = _value('model');
    final manufacturer = _value('manufacturer');

    return InkWell(
      onTap: () {
        Navigator.pop(context, {
          'site': data['site'] ?? '',
          'location': data['location'] ?? '',
          'name': name,
          'id': documentId,
        });
      },
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.precision_manufacturing_outlined,
                      color: Color(0xFF1E88E5),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'رقم الأصل: $number',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (data['status'] != null)
                    _StatusChip(
                      status: status == 'active'
                          ? 'نشط'
                          : status == 'inactive'
                          ? 'غير نشط'
                          : 'تحت الصيانة',
                    ),
                ],
              ),
              const Divider(height: 24),
              _InfoRow(
                icon: Icons.place_outlined,
                label: 'المكان',
                value: location,
              ),
              /*  _InfoRow(
                icon: Icons.category_outlined,
                label: 'النوع',
                value: type,
              ),
                _InfoRow(
                icon: Icons.confirmation_number_outlined,
                label: 'الرقم التسلسلي',
                value: serialNumber,
              ), */
              _InfoRow(
                icon: Icons.settings_outlined,
                label: 'الموديل',
                value: model,
              ),
              _InfoRow(
                icon: Icons.business_outlined,
                label: 'الشركة المصنعة',
                value: manufacturer,
              ),
              const SizedBox(height: 8),
              Text(
                'معرّف المستند: $documentId',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      backgroundColor: status == 'نشط'
          ? const Color.fromARGB(255, 122, 238, 132)
          : status == 'غير نشط'
          ? const Color.fromARGB(255, 243, 97, 97)
          : const Color.fromARGB(255, 201, 173, 61),
      side: BorderSide(color: Colors.green.shade200),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
