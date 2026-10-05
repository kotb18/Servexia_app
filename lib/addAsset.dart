import 'dart:convert';
import 'dart:typed_data';

import 'package:characters/characters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// مرّر هذا المفتاح إلى MaterialApp أو CupertinoApp.
/// استخدامه يمنع مشاكل اختلاف BuildContext بعد عمليات الحفظ والتنقل.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key, required this.groupId});

  final String groupId;
  static const String screenRoute = 'addAsset';

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _siteController = TextEditingController();
  final _locationController = TextEditingController();
  final _assetNameController = TextEditingController();
  final _modelController = TextEditingController();
  final _assetNumberController = TextEditingController();

  bool _loading = false;
  int? _maxAssets;
  int? _currentAssetNumber;
  String? _selectedSite;
  String? _selectedLocation;
  int _suggestionRequestId = 0;
  bool _assetNumberManuallyEdited = false;

  CollectionReference<Map<String, dynamic>> get _itemsRef => FirebaseFirestore
      .instance
      .collection('assets')
      .doc(widget.groupId)
      .collection('items');

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _siteController.dispose();
    _locationController.dispose();
    _assetNameController.dispose();
    _modelController.dispose();
    _assetNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadLimits() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('variables').doc('kotb').get(),
        _itemsRef.count().get(),
      ]);

      if (!mounted) return;
      final variables = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final count = results[1] as AggregateQuerySnapshot;

      setState(() {
        _maxAssets = variables.data()?['maxAssets'] as int?;
        _currentAssetNumber = count.count;
      });
    } catch (_) {
      // لا نمنع المستخدم من تعبئة النموذج إذا تعذر تحميل الإعدادات.
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _suggestionsStream({
    String? site,
    String? location,
    String? name,
  }) {
    Query<Map<String, dynamic>> query = _itemsRef;
    if (site != null && site.trim().isNotEmpty) {
      query = query.where('site', isEqualTo: site.trim());
    }
    if (location != null && location.trim().isNotEmpty) {
      query = query.where('location', isEqualTo: location.trim());
    }
    if (name != null && name.trim().isNotEmpty) {
      query = query.where('name', isEqualTo: name.trim());
    }
    return query.snapshots();
  }

  List<String> _uniqueValues(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String field,
  ) {
    final values = snapshot.docs
        .map((doc) => doc.data()[field])
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> _modelValues(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final site = (_selectedSite ?? _siteController.text).trim().toLowerCase();
    final location = (_selectedLocation ?? _locationController.text)
        .trim()
        .toLowerCase();
    final name = _assetNameController.text.trim().toLowerCase();
    final models = <String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final itemSite = (data['site'] as String? ?? '').trim().toLowerCase();
      final itemLocation = (data['location'] as String? ?? '')
          .trim()
          .toLowerCase();
      final itemName = (data['name'] as String? ?? '').trim().toLowerCase();
      final model = (data['model'] as String? ?? '').trim();

      if (model.isEmpty) continue;
      if (site.isNotEmpty && itemSite != site) continue;
      if (location.isNotEmpty && itemLocation != location) continue;
      if (name.isNotEmpty && itemName != name) continue;
      models.add(model);
    }

    final result = models.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  String _englishPrefix(String value) {
    // تحويل الحروف العربية إلى كتابة لاتينية تقريبية، مع الاحتفاظ
    // بالحروف والأرقام الإنجليزية الموجودة أصلًا.
    const arabicToLatin = <String, String>{
      'ا': 'A',
      'أ': 'A',
      'إ': 'I',
      'آ': 'AA',
      'ب': 'B',
      'ت': 'T',
      'ث': 'TH',
      'ج': 'J',
      'ح': 'H',
      'خ': 'KH',
      'د': 'D',
      'ذ': 'DH',
      'ر': 'R',
      'ز': 'Z',
      'س': 'S',
      'ش': 'SH',
      'ص': 'S',
      'ض': 'D',
      'ط': 'T',
      'ظ': 'Z',
      'ع': 'A',
      'غ': 'GH',
      'ف': 'F',
      'ق': 'Q',
      'ك': 'K',
      'ل': 'L',
      'م': 'M',
      'ن': 'N',
      'ه': 'H',
      'ة': 'H',
      'و': 'W',
      'ؤ': 'W',
      'ي': 'Y',
      'ى': 'A',
      'ئ': 'Y',
      'ء': 'A',
    };

    final buffer = StringBuffer();
    for (final character in value.trim().toUpperCase().characters) {
      if (arabicToLatin.containsKey(character)) {
        buffer.write(arabicToLatin[character]);
      } else {
        buffer.write(character);
      }
    }

    final normalized = buffer
        .toString()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return normalized.isEmpty ? 'ASSET' : normalized;
  }

  Future<void> _suggestAssetNumber() async {
    final site = _siteController.text.trim();
    final location = _locationController.text.trim();
    final name = _assetNameController.text.trim();

    if (site.isEmpty || location.isEmpty || name.isEmpty) return;

    final requestId = ++_suggestionRequestId;

    try {
      final snapshot = await _itemsRef
          .where('site', isEqualTo: site)
          .where('location', isEqualTo: location)
          .where('name', isEqualTo: name)
          .get();

      if (!mounted || requestId != _suggestionRequestId) return;

      int maxNumber = 0;
      final numberPattern = RegExp(r'-(\d+)$');

      for (final doc in snapshot.docs) {
        final value = (doc.data()['number'] as String? ?? '').trim();
        final match = numberPattern.firstMatch(value);
        if (match == null) continue;

        final parsedNumber = int.tryParse(match.group(1)!);
        if (parsedNumber != null && parsedNumber > maxNumber) {
          maxNumber = parsedNumber;
        }
      }

      if (_assetNumberManuallyEdited) return;

      final nextNumber = maxNumber + 1;
      final prefix = _englishPrefix(name);
      _assetNumberController.text =
          '$prefix-${nextNumber.toString().padLeft(3, '0')}';
    } catch (_) {
      // لا نوقف إدخال الأصل إذا تعذر اقتراح الرقم.
    }
  }

  Future<void> _saveAsset() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_maxAssets != null &&
        _currentAssetNumber != null &&
        _currentAssetNumber! >= _maxAssets!) {
      _showMessage('لقد وصلت إلى الحد الأقصى للأصول المسموح بها.');
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .set({'groupId': widget.groupId}, SetOptions(merge: true));

      final assetRef = await _saveAssetAtomically();

      if (!mounted) return;

      final savedAsset = <String, String>{
        'id': assetRef.id,
        'site': _siteController.text.trim(),
        'location': _locationController.text.trim(),
        'name': _assetNameController.text.trim(),
        'model': _modelController.text.trim(),
        'number': _assetNumberController.text.trim(),
      };

      setState(() => _loading = false);
      await _showQrAfterSave(savedAsset);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (error is _DuplicateAssetNumberException) {
        _showMessage('رقم الأصل موجود بالفعل. أدخل رقمًا آخر.');
      } else {
        _showMessage('تعذر حفظ الأصل، حاول مرة أخرى.');
      }
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> _saveAssetAtomically() async {
    final site = _siteController.text.trim();
    final location = _locationController.text.trim();
    final name = _assetNameController.text.trim();
    final model = _modelController.text.trim();
    var candidate = _assetNumberController.text.trim().toUpperCase();

    if (candidate.isEmpty) {
      throw _DuplicateAssetNumberException();
    }

    for (var attempt = 0; attempt < 20; attempt++) {
      final duplicate = await _itemsRef
          .where('number', isEqualTo: candidate)
          .limit(1)
          .get();

      // الرقم المكتوب يدويًا يجب رفضه، أما الرقم المقترح تلقائيًا
      // فينتقل للرقم التالي إذا حدث سباق بين مستخدمين.
      if (duplicate.docs.isNotEmpty && _assetNumberManuallyEdited) {
        throw _DuplicateAssetNumberException();
      }
      if (duplicate.docs.isNotEmpty) {
        candidate = _incrementAssetNumber(candidate);
        continue;
      }

      final assetRef = _itemsRef.doc();
      final indexId = base64Url.encode(utf8.encode(candidate));
      final indexRef = FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('numberIndex')
          .doc(indexId);

      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final indexSnapshot = await transaction.get(indexRef);
          if (indexSnapshot.exists) {
            throw _DuplicateAssetNumberException();
          }

          transaction.set(indexRef, {
            'number': candidate,
            'assetId': assetRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          });

          transaction.set(assetRef, {
            'id': assetRef.id,
            'site': site,
            'location': location,
            'name': name,
            'model': model,
            'number': candidate,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });
        });

        _assetNumberController.text = candidate;
        return assetRef;
      } on _DuplicateAssetNumberException {
        if (_assetNumberManuallyEdited) rethrow;
        candidate = _incrementAssetNumber(candidate);
      }
    }

    throw StateError('Could not reserve a unique asset number.');
  }

  String _incrementAssetNumber(String value) {
    final match = RegExp(r'^(.*?)-(\d+)$').firstMatch(value);
    if (match == null) {
      return '$value-001';
    }

    final prefix = match.group(1)!;
    final number = int.tryParse(match.group(2)!) ?? 0;
    final width = match.group(2)!.length < 3 ? 3 : match.group(2)!.length;
    return '$prefix-${(number + 1).toString().padLeft(width, '0')}';
  }

  String _qrPayload(Map<String, String> asset) {
    return jsonEncode({
      'type': 'asset',
      'id': asset['id'],
      'number': asset['number'],
      'site': asset['site'],
      'location': asset['location'],
      'name': asset['name'],
      'model': asset['model'],
    });
  }

  /// انتظار قصير حتى تنتهي animation إغلاق الحوار السابق؛
  /// إظهار حوار جديد فور إغلاق آخر قد يبتلعه Flutter ولا يظهر.
  Future<void> _waitForDialogTransition() =>
      Future<void>.delayed(const Duration(milliseconds: 120));

  Future<void> _showQrAfterSave(Map<String, String> asset) async {
    // ننتظر دورة واجهة واحدة بعد انتهاء الحفظ حتى لا يتعارض الحوار
    // مع إغلاق لوحة المفاتيح أو إعادة بناء الشاشة.
    await Future<void>.delayed(Duration.zero);
    final navigator =
        appNavigatorKey.currentState ??
        (mounted ? Navigator.of(context, rootNavigator: true) : null);
    final overlayContext = navigator?.overlay?.context;
    if (overlayContext == null) return;

    final action = await showDialog<String>(
      context: overlayContext,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تم حفظ الأصل بنجاح'),
          content: const Text('هل تريد إنشاء رمز QR لهذا الأصل أو طباعته؟'),
          // وضع الأزرار رأسيًا يمنع اختفاء زر إنشاء QR بسبب ضيق العرض
          // أو اتجاه RTL على الشاشات الصغيرة.
          actions: [
            SizedBox(
              // لا تستخدم double.infinity داخل AlertDialog؛ فهو يعتمد على
              // IntrinsicWidth ويسبب خطأ LayoutBuilder أثناء القياس.
              width: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('إنشاء QR'),
                    onPressed: () => Navigator.of(dialogContext).pop('create'),
                  ),
                  const SizedBox(height: 8),
                  /*  OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('طباعة'),
                    onPressed: () => Navigator.of(dialogContext).pop('print'),
                  ), */
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop('later'),
                    child: const Text('لاحقًا'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (action == null) return;

    final rootNavigator =
        appNavigatorKey.currentState ??
        (mounted ? Navigator.of(context, rootNavigator: true) : null);
    if (rootNavigator == null) return;

    final payload = _qrPayload(asset);

    if (action == 'create') {
      await _showQrDialog(asset, payload);
    } else if (action == 'print') {
      await _printAssetQr(asset, payload);
      await _waitForDialogTransition();
      await _showQrDialog(asset, payload);
    }
  }

  Future<void> _showQrDialog(Map<String, String> asset, String payload) async {
    // ننتظر انتهاء animation إغلاق الحوار السابق حتى لا يبتلع
    // Flutter هذا الحوار ويختفي دون أن يظهر.
    await _waitForDialogTransition();

    if (!mounted && appNavigatorKey.currentState == null) return;

    final navigator =
        appNavigatorKey.currentState ??
        (mounted ? Navigator.of(context, rootNavigator: true) : null);
    final dialogContext = navigator?.overlay?.context;
    if (dialogContext == null) return;

    // نستخدم Dialog بدل AlertDialog: AlertDialog يلف محتواه بـ IntrinsicWidth،
    // وأي LayoutBuilder بداخله (مثل QrImageView) ينهار معه بخطأ
    // "LayoutBuilder does not support returning intrinsic dimensions".
    await showDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 330,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text(
                    'QR - ${asset['number']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          color: Colors.white,
                          // رسم QR مباشرة عبر QrPainter دون LayoutBuilder.
                          child: CustomPaint(
                            size: const Size.square(230),
                            painter: QrPainter(
                              data: payload,
                              version: QrVersions.auto,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              color: Colors.black,
                              // ignore: deprecated_member_use
                              //  color: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          asset['number'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          asset['name'] ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('إغلاق'),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.ios_share_outlined),
                        label: const Text('تصدير / مشاركة'),
                        onPressed: () => _shareAssetQr(asset, payload),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('طباعة QR'),
                        onPressed: () => _printAssetQr(asset, payload),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List> _assetQrPdf(
    Map<String, String> asset,
    String payload,
  ) async {
    // خط النظام الافتراضي في package:pdf لا يحتوي على الحروف العربية.
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'),
    );
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Center(
            child: pw.Container(
              width: 300,
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    asset['number'] ?? '',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: payload,
                    width: 230,
                    height: 230,
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(asset['name'] ?? '', textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    asset['location'] ?? '',
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(asset['site'] ?? '', textAlign: pw.TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return pdf.save();
  }

  Future<void> _shareAssetQr(Map<String, String> asset, String payload) async {
    try {
      final bytes = await _assetQrPdf(asset, payload);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'asset_${asset['number'] ?? 'qr'}.pdf',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('تعذر تصدير أو مشاركة QR: $error');
    }
  }

  Future<void> _printAssetQr(Map<String, String> asset, String payload) async {
    try {
      final bytes = await _assetQrPdf(asset, payload);
      await Printing.layoutPdf(
        name: 'asset_${asset['number'] ?? 'qr'}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('تعذرت طباعة QR: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _resetFromSite() {
    _selectedSite = _siteController.text.trim();
    _selectedLocation = null;
    _locationController.clear();
    _assetNameController.clear();
    _modelController.clear();
    _assetNumberController.clear();
    _assetNumberManuallyEdited = false;
    setState(() {});
  }

  void _resetFromLocation() {
    _selectedLocation = _locationController.text.trim();
    _assetNameController.clear();
    _modelController.clear();
    _assetNumberController.clear();
    _assetNumberManuallyEdited = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF172033),
        title: const Text(
          'إضافة أصل جديد',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEAF3FF), Color(0xFFF6F8FC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 8, 16, 124 + bottomInset),
              children: [
                _buildHeader(theme),
                const SizedBox(height: 16),
                _buildSection(
                  title: 'الموقع',
                  subtitle: 'اختر موقعًا سابقًا أو اكتب موقعًا جديدًا',
                  icon: Icons.location_city_rounded,
                  child: _buildSiteField(),
                ),
                _buildSection(
                  title: 'المكان داخل الموقع',
                  subtitle: 'تظهر الأماكن المرتبطة بالموقع المختار',
                  icon: Icons.pin_drop_rounded,
                  child: _buildLocationField(),
                ),
                _buildSection(
                  title: 'بيانات المعدة',
                  subtitle: 'يمكنك اختيار قيمة سابقة أو إدخال قيمة جديدة',
                  icon: Icons.precision_manufacturing_rounded,
                  child: Column(
                    children: [
                      _buildAssetNameField(),
                      const SizedBox(height: 14),
                      _buildModelField(),
                      const SizedBox(height: 14),
                      _buildAssetNumberField(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: _buildSaveBar(),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1769E0), Color(0xFF4B8FF0)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1769E0).withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.add_business_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سجّل أصلًا جديدًا',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'استخدم الاقتراحات لتعبئة البيانات بسرعة ودقة',
                  style: TextStyle(
                    color: Color(0xFFE6F0FF),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A16233D),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF1769E0), size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF748096),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 21),
      suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
      filled: true,
      fillColor: const Color(0xFFFAFBFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE3EE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE3EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1769E0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE05252)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE05252), width: 1.5),
      ),
    );
  }

  Widget _buildAutocompleteField({
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String field,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
    FormFieldValidator<String>? validator,
    List<String> Function(QuerySnapshot<Map<String, dynamic>> snapshot)?
    valuesBuilder,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final options = snapshot.hasData
            ? (valuesBuilder?.call(snapshot.data!) ??
                  _uniqueValues(snapshot.data!, field))
            : <String>[];
        return Autocomplete<String>(
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return options;
            return options.where((item) => item.toLowerCase().contains(query));
          },
          optionsMaxHeight: 260,
          onSelected: (value) {
            controller.text = value;
            onChanged(value);
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                if (textController.text != controller.text &&
                    !focusNode.hasFocus) {
                  textController.text = controller.text;
                }
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.next,
                  textDirection: TextDirection.rtl,
                  decoration: _inputDecoration(
                    label: label,
                    hint: hint,
                    icon: icon,
                  ),
                  validator: validator,
                  onChanged: (value) {
                    controller.text = value;
                    onChanged(value);
                  },
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                );
              },
        );
      },
    );
  }

  Widget _buildSiteField() => _buildAutocompleteField(
    stream: _suggestionsStream(),
    field: 'site',
    controller: _siteController,
    label: 'الموقع',
    hint: 'مثال: مصنع القاهرة',
    icon: Icons.location_city_rounded,
    onChanged: (_) => _resetFromSite(),
    validator: (value) =>
        value == null || value.trim().isEmpty ? 'أدخل الموقع' : null,
  );

  Widget _buildLocationField() => _buildAutocompleteField(
    stream: _suggestionsStream(site: _selectedSite),
    field: 'location',
    controller: _locationController,
    label: 'المكان داخل الموقع',
    hint: 'الدور الأول - غرفة المولدات',
    icon: Icons.place_rounded,
    onChanged: (_) {
      _resetFromLocation();
      _suggestAssetNumber();
    },
    validator: (value) => value == null || value.trim().isEmpty
        ? 'أدخل المكان داخل الموقع'
        : null,
  );

  Widget _buildAssetNameField() => _buildAutocompleteField(
    stream: _suggestionsStream(
      site: _selectedSite,
      location: _selectedLocation,
    ),
    field: 'name',
    controller: _assetNameController,
    label: 'اسم المعدة',
    hint: 'مثال: مولد كهرباء',
    icon: Icons.precision_manufacturing_rounded,
    onChanged: (_) {
      _modelController.clear();
      _assetNumberController.clear();
      _assetNumberManuallyEdited = false;
      setState(() {});
      _suggestAssetNumber();
    },
    validator: (value) =>
        value == null || value.trim().isEmpty ? 'أدخل اسم المعدة' : null,
  );

  Widget _buildModelField() => _buildAutocompleteField(
    // نقرأ الأصول السابقة كلها ثم نطابق السياق محليًا؛
    // هذا يمنع اعتماد الاقتراحات على Composite Index في Firestore.
    stream: _suggestionsStream(),
    field: 'model',
    controller: _modelController,
    label: 'موديل المعدة',
    hint: 'اختر موديلًا سابقًا أو اكتب موديلًا جديدًا',
    icon: Icons.settings_suggest_rounded,
    onChanged: (_) {},
    /* validator: (value) =>
        value == null || value.trim().isEmpty ? 'أدخل موديل المعدة' : null, */
    valuesBuilder: _modelValues,
  );

  Widget _buildAssetNumberField() {
    return TextFormField(
      controller: _assetNumberController,
      textInputAction: TextInputAction.done,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.text,
      decoration:
          _inputDecoration(
            label: 'رقم المعدة',
            hint: 'GENERATOR-001',
            icon: Icons.tag_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'إعادة اقتراح الرقم',
              onPressed: _suggestAssetNumber,
            ),
          ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'أدخل رقم المعدة' : null,
      onChanged: (_) {
        _assetNumberManuallyEdited = true;
      },
      onFieldSubmitted: (_) => _saveAsset(),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _saveAsset,
          icon: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline_rounded),
          label: Text(
            _loading ? 'جاري الحفظ...' : 'حفظ الأصل',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1769E0),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF9DBBEA),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

class _DuplicateAssetNumberException implements Exception {}
