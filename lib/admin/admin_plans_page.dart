import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:maintenance/Subscruption/plan_model.dart';
import 'package:maintenance/Subscruption/plan_service.dart';

/// ضع هنا معرّفات المنتجات المطابقة تمامًا لما أنشأته في Google Play Console.
/// Google Play Billing لا يوفّر API لاسترجاع جميع المنتجات المسجلة تلقائيًا.
/// هذه القائمة هي مصدر الخيارات في شاشة إدارة الباقات، وليست حقول إدخال حر.
const List<String> kGooglePlaySubscriptionProductIds = <String>[
  'servexia_basic_monthly',
  'servexia_basic_yearly',
  'servexia_pro_monthly',
  'servexia_pro_yearly',
  'servexia_business_monthly',
  'servexia_business_yearly',
];

class AdminPlansPage extends StatefulWidget {
  const AdminPlansPage({super.key});

  @override
  State<AdminPlansPage> createState() => _AdminPlansPageState();
}

class _AdminPlansPageState extends State<AdminPlansPage> {
  static const Color _primary = Color(0xFF315BEA);
  static const Color _background = Color(0xFFF5F7FB);

  final PlanService _service = PlanService();
  final InAppPurchase _store = InAppPurchase.instance;

  List<ProductDetails> _storeProducts = const [];
  Set<String> _notFoundProductIds = const {};
  bool _loadingProducts = true;
  String? _productLoadError;

  @override
  void initState() {
    super.initState();
    _loadStoreProducts();
  }

  Future<void> _loadStoreProducts() async {
    if (kGooglePlaySubscriptionProductIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _productLoadError =
            'أضف معرّفات منتجات Google Play في القائمة أعلى الملف.';
      });
      return;
    }

    try {
      final available = await _store.isAvailable();
      if (!available) {
        if (!mounted) return;
        setState(() {
          _loadingProducts = false;
          _productLoadError =
              'Google Play Billing غير متاح على هذا الجهاز حاليًا.';
        });
        return;
      }

      final response = await _store.queryProductDetails(
        kGooglePlaySubscriptionProductIds.toSet(),
      );
      if (!mounted) return;
      setState(() {
        _storeProducts = response.productDetails
          ..sort((a, b) => a.id.compareTo(b.id));
        _notFoundProductIds = response.notFoundIDs.toSet();
        _loadingProducts = false;
        _productLoadError = response.error?.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _productLoadError = 'تعذر تحميل منتجات Google Play: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'إدارة الباقات',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: const Color(0xFF20253A),
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'تحديث منتجات Google Play',
              onPressed: _loadingProducts ? null : _loadStoreProducts,
              icon: const Icon(Icons.sync_rounded),
            ),
            IconButton(
              tooltip: 'تهيئة الباقات الافتراضية',
              onPressed: () => _seedPlans(context),
              icon: const Icon(Icons.cloud_upload_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildProductStatus(),
            Expanded(
              child: StreamBuilder<List<PlanModel>>(
                stream: _service.allPlansStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _centerMessage(
                      'حدث خطأ أثناء تحميل الباقات.\n${snapshot.error}',
                      icon: Icons.cloud_off_rounded,
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final plans = [...?snapshot.data]
                    ..sort((a, b) => a.order.compareTo(b.order));
                  if (plans.isEmpty) {
                    return _centerMessage(
                      'لا توجد باقات بعد.\nأضف باقة جديدة أو هيّئ الباقات الافتراضية.',
                      icon: Icons.inventory_2_outlined,
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      _sectionTitle('الباقات المسجلة', '${plans.length} باقات'),
                      const SizedBox(height: 12),
                      ...plans.map((plan) => _planCard(context, plan)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          onPressed: () => _showEditDialog(context, null),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'إضافة باقة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildProductStatus() {
    final isError = _productLoadError != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF4E5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError ? const Color(0xFFFFD79A) : const Color(0xFFE8EAF1),
        ),
      ),
      child: Row(
        children: [
          if (_loadingProducts)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isError ? Icons.warning_amber_rounded : Icons.shop_rounded,
              color: isError ? Colors.orange.shade800 : _primary,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _loadingProducts
                  ? 'جاري تحميل منتجات Google Play...'
                  : isError
                  ? _productLoadError!
                  : 'منتجات Google Play المتاحة: ${_storeProducts.length}',
              style: TextStyle(
                color: isError
                    ? Colors.orange.shade900
                    : const Color(0xFF4C5263),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!_loadingProducts)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'إعادة التحميل',
              onPressed: _loadStoreProducts,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _centerMessage(String text, {required IconData icon}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
            if (_productLoadError != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _loadStoreProducts,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة تحميل منتجات المتجر'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _seedPlans(BuildContext context) async {
    try {
      await _service.seedDefaultPlans();
      if (!context.mounted) return;
      _showMessage(context, 'تمت تهيئة الباقات بنجاح.');
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'تعذر تهيئة الباقات: $error', isError: true);
    }
  }

  Widget _planCard(BuildContext context, PlanModel plan) {
    final monthly = _productForId(plan.monthlyProductId);
    final yearly = _productForId(plan.yearlyProductId);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.isActive
              ? const Color(0xFFE7EAF1)
              : const Color(0xFFFFE0E0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ترتيب العرض: ${plan.order}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch.adaptive(
                      value: plan.isActive,
                      activeColor: _primary,
                      onChanged: (_) => _togglePlan(context, plan),
                    ),
                    Text(
                      plan.isActive ? 'نشطة' : 'متوقفة',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: plan.isActive
                            ? Colors.green.shade700
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 13),
            _productLine('شهري', monthly, plan.monthlyProductId),
            const SizedBox(height: 7),
            _productLine('سنوي', yearly, plan.yearlyProductId),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Divider(height: 1),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _limitChip('المجموعات', plan.maxGroups),
                _limitChip('المخزون', plan.maxInventoryItems),
                _limitChip('الفواتير/شهر', plan.maxInvoicesPerMonth),
                _limitChip('الأصول', plan.maxAssets),
                _limitChip('الأعضاء', plan.maxMembers),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditDialog(context, plan),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('تعديل بيانات الباقة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: BorderSide(color: _primary.withOpacity(.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'حذف الباقة',
                  onPressed: () => _confirmDelete(context, plan),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    backgroundColor: Colors.red.withOpacity(.08),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ProductDetails? _productForId(String id) {
    for (final product in _storeProducts) {
      if (product.id == id) return product;
    }
    return null;
  }

  Widget _productLine(String period, ProductDetails? product, String id) {
    final exists = product != null;
    final title = exists ? product.title : id;
    final subtitle = exists
        ? '${product.price}  •  ${product.id}'
        : (id.isEmpty
              ? 'لم يتم تعيين منتج'
              : 'المعرّف غير موجود في المتجر أو لم يُحمّل');
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _primary.withOpacity(.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            period,
            style: const TextStyle(
              color: _primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Icon(
          exists ? Icons.check_circle : Icons.warning_amber_rounded,
          size: 16,
          color: exists ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _limitChip(String title, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$title: ${value < 0 ? 'غير محدود' : value}',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _togglePlan(BuildContext context, PlanModel plan) async {
    try {
      await _service.toggleActive(plan);
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'تعذر تغيير الحالة: $error', isError: true);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, PlanModel plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('حذف باقة ${plan.name}؟'),
        content: const Text(
          'سيؤدي ذلك إلى حذف إعدادات الباقة من قاعدة البيانات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deletePlan(plan.id);
      if (context.mounted) _showMessage(context, 'تم حذف الباقة.');
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'تعذر حذف الباقة: $error', isError: true);
      }
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    PlanModel? existing,
  ) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final groupsCtrl = TextEditingController(
      text: '${existing?.maxGroups ?? 0}',
    );
    final itemsCtrl = TextEditingController(
      text: '${existing?.maxInventoryItems ?? 0}',
    );
    final invoicesCtrl = TextEditingController(
      text: '${existing?.maxInvoicesPerMonth ?? 0}',
    );
    final assetsCtrl = TextEditingController(
      text: '${existing?.maxAssets ?? 0}',
    );
    final membersCtrl = TextEditingController(
      text: '${existing?.maxMembers ?? 0}',
    );
    final orderCtrl = TextEditingController(text: '${existing?.order ?? 99}');

    var monthlyId = existing?.monthlyProductId ?? '';
    var yearlyId = existing?.yearlyProductId ?? '';
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !isSaving,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              title: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: _primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      isEdit ? 'تعديل ${existing.name}' : 'إضافة باقة',
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _formSection('منتجات Google Play', Icons.shop_rounded),
                      const SizedBox(height: 10),
                      _productDropdown(
                        label: 'المنتج الشهري',
                        selectedId: monthlyId,
                        onChanged: (value) =>
                            setDialogState(() => monthlyId = value ?? ''),
                        existingId: existing?.monthlyProductId,
                      ),
                      const SizedBox(height: 10),
                      _productDropdown(
                        label: 'المنتج السنوي',
                        selectedId: yearlyId,
                        onChanged: (value) =>
                            setDialogState(() => yearlyId = value ?? ''),
                        existingId: existing?.yearlyProductId,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'المعرّفات ثابتة من كتالوج التطبيق؛ اختر المنتج فقط. لا يتم تعديل معرّف Play Billing هنا.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _formSection(
                        'بيانات الباقة وحدودها',
                        Icons.settings_outlined,
                      ),
                      const SizedBox(height: 10),
                      _textField(
                        nameCtrl,
                        'اسم الباقة',
                        text: true,
                        hint: 'مثال: الاحترافية',
                      ),
                      Row(
                        children: [
                          Expanded(child: _textField(orderCtrl, 'ترتيب العرض')),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _textField(
                              groupsCtrl,
                              'المجموعات (-1 بلا حد)',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _textField(itemsCtrl, 'أصناف المخزون'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _textField(invoicesCtrl, 'الفواتير/شهر'),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _textField(assetsCtrl, 'الأصول')),
                          const SizedBox(width: 10),
                          Expanded(child: _textField(membersCtrl, 'الأعضاء')),
                        ],
                      ),
                      if (_loadingProducts) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 5),
                        const Text(
                          'جاري تحميل خيارات المنتجات...',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                      if (_productLoadError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _productLoadError!,
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            _showMessage(
                              context,
                              'أدخل اسم الباقة.',
                              isError: true,
                            );
                            return;
                          }
                          if (monthlyId.isEmpty || yearlyId.isEmpty) {
                            _showMessage(
                              context,
                              'اختر المنتج الشهري والسنوي.',
                              isError: true,
                            );
                            return;
                          }
                          if (monthlyId == yearlyId) {
                            _showMessage(
                              context,
                              'اختر منتجين مختلفين للشهري والسنوي.',
                              isError: true,
                            );
                            return;
                          }
                          final numericValues = [
                            orderCtrl.text,
                            groupsCtrl.text,
                            itemsCtrl.text,
                            invoicesCtrl.text,
                            assetsCtrl.text,
                            membersCtrl.text,
                          ];
                          if (numericValues.any(
                            (value) => int.tryParse(value.trim()) == null,
                          )) {
                            _showMessage(
                              context,
                              'تأكد من إدخال أرقام صحيحة في حقول الترتيب والحدود.',
                              isError: true,
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final plan = PlanModel(
                            id: isEdit
                                ? existing.id
                                : DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                            name: name,
                            monthlyProductId: monthlyId,
                            yearlyProductId: yearlyId,
                            maxGroups: _toInt(groupsCtrl.text),
                            maxInventoryItems: _toInt(itemsCtrl.text),
                            maxInvoicesPerMonth: _toInt(invoicesCtrl.text),
                            maxAssets: _toInt(assetsCtrl.text),
                            maxMembers: _toInt(membersCtrl.text),
                            order: _toInt(orderCtrl.text),
                            isActive: existing?.isActive ?? true,
                          );
                          try {
                            if (isEdit) {
                              await _service.updatePlan(plan);
                            } else {
                              await _service.addPlan(plan);
                            }
                            if (dialogContext.mounted)
                              Navigator.pop(dialogContext);
                            if (context.mounted)
                              _showMessage(context, 'تم حفظ الباقة.');
                          } catch (error) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              _showMessage(
                                context,
                                'تعذر حفظ الباقة: $error',
                                isError: true,
                              );
                            }
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(isSaving ? 'جارٍ الحفظ' : 'حفظ الباقة'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      nameCtrl.dispose();
      groupsCtrl.dispose();
      itemsCtrl.dispose();
      invoicesCtrl.dispose();
      assetsCtrl.dispose();
      membersCtrl.dispose();
      orderCtrl.dispose();
    }
  }

  Widget _formSection(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primary),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    );
  }

  Widget _productDropdown({
    required String label,
    required String selectedId,
    required ValueChanged<String?> onChanged,
    String? existingId,
  }) {
    final ids = <String>{..._storeProducts.map((product) => product.id)};
    // إن كان المنتج القديم غير موجود حاليًا في Play، نعرضه كي لا يتغير ضمنيًا.
    if (existingId != null && existingId.isNotEmpty) ids.add(existingId);
    final items = ids.toList()..sort();
    final safeValue = items.contains(selectedId) ? selectedId : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.shopping_bag_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
      ),
      hint: Text(
        _loadingProducts ? 'تحميل المنتجات...' : 'اختر منتجًا من Google Play',
      ),
      items: items.map((id) {
        final product = _productForId(id);
        final notFound = _notFoundProductIds.contains(id) || product == null;
        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            product == null
                ? '$id${notFound ? ' (غير متاح)' : ''}'
                : '${product.title} — ${product.price}  •  $id',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: items.isEmpty ? null : onChanged,
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool text = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: text ? TextInputType.text : TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
        ),
      ),
    );
  }

  int _toInt(String value) => int.parse(value.trim());

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : null,
        content: Text(message),
      ),
    );
  }
}
