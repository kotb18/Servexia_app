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
                _buildAssetWorks(), // ← ListView داخلي
              ] else
                _buildEmptyState(),
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
            value: selectedSite,
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
            value: selectedLocation,
            hint: const Text('اختر المكان'),
            items: locations
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) {
              setState(() {
                selectedLocation = v;
                selectedAssetName = null;
                selectedAssetId = null;
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
            value: selectedAssetName,
            hint: const Text('اختر اسم المعدة'),
            items: names
                .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                .toList(),
            onChanged: (v) {
              setState(() {
                selectedAssetName = v;
                selectedAssetId = null;
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
            value: selectedAssetId,
            hint: const Text('اختر رقم المعدة'),
            items: snap.data!.docs
                .map(
                  (doc) => DropdownMenuItem(
                    value: doc.id,
                    child: Text(doc['number'] ?? 'بدون رقم'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => selectedAssetId = v),
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
                label: 'تقرير PDF',
                color: Colors.blueGrey,
                onPressed: _generateAssetPdf,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.delete_outline,
                label: 'حذف الأصل',
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
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
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

  /// 📋 الأعمال المحسّنة
  Widget _buildAssetWorks() {
    final ref = FirebaseFirestore.instance
        .collection('assets')
        .doc(widget.groupId)
        .collection('items')
        .doc(selectedAssetId)
        .collection('works')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد أعمال لهذا الأصل',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        double total = 0;
        final works = snap.data!.docs;

        for (var doc in works) {
          final d = doc.data() as Map<String, dynamic>;
          total += (d['cost'] as num).toDouble();
        }

        return ListView.builder(
          shrinkWrap: true, // ⭐ مهم جدًا
          physics: const NeverScrollableScrollPhysics(),
          // physics: const BouncingScrollPhysics(),
          itemCount: works.length + 1,
          itemBuilder: (context, index) {
            if (index == works.length) {
              return _buildTotalCard(total);
            }

            final doc = works[index];
            final d = doc.data() as Map<String, dynamic>;
            final date = (d['taskDateTime'] as Timestamp).toDate();

            return _buildWorkCard(
              title: d['title'] ?? 'بدون عنوان',
              description: d['description'] ?? '',
              date: DateFormat('yyyy/MM/dd').format(date),
              cost: d['cost'] ?? 0,
              note: d['note'] ?? '',
              index: index,
            );
          },
        );
      },
    );
  }

  /// 💳 بطاقة العمل الواحد
  Widget _buildWorkCard({
    required String title,
    required String description,
    required String date,
    required dynamic cost,
    required String note,
    required int index,
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
                      '${cost.toStringAsFixed(2)} ج',
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
                  'إجمالي التكلفة',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${total.toStringAsFixed(2)} جنيه',
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

  /// 📄 إنشاء تقرير PDF احترافي
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
      final worksSnap = await assetRef
          .collection('works')
          .orderBy('createdAt')
          .get();

      final asset = assetSnap.data()!;
      final pdf = pw.Document();
      double total = 0;

      final List<List<String>> worksData = [];
      for (var w in worksSnap.docs) {
        final d = w.data();
        final date = (d['taskDateTime'] as Timestamp).toDate();
        total += (d['cost'] as num).toDouble();
        worksData.add([
          d['note'] ?? 'لا توجد',
          DateFormat('yyyy/MM/dd').format(date),
          '${d['cost']} جنيه',
          d['description'] ?? 'لا يوجد',
          d['title'] ?? 'بدون عنوان',
        ]);
      }

      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            textDirection: pw.TextDirection.rtl,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
                    pw.Text('الموقع: ${asset['site']}', style: boldTextStyle),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'المكان: ${asset['location']}',
                      style: boldTextStyle,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'اسم المعدة: ${asset['name']}',
                      style: boldTextStyle,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'رقم المعدة: ${asset['number']}',
                      style: boldTextStyle,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // جدول الأعمال
              pw.Text('سجل الأعمال والصيانة', style: subHeaderTextStyle),
              pw.SizedBox(height: 10),
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
                  'إجمالي التكلفة: ${total.toStringAsFixed(2)} جنيه',
                  style: totalTextStyle,
                ),
              ),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (_) => pdf.save());
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
