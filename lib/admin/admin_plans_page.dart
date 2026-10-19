import 'package:flutter/material.dart';
import 'package:maintenance/Subscruption/plan_model.dart';
import 'package:maintenance/Subscruption/plan_service.dart';

/// اقتراحات اختيارية فقط؛ يمكن كتابة أي معرّف آخر يدويًا.
const List<String> kSuggestedProductIds = <String>[
  'servexia_monthly',
  'servexia_yearly_main',
  'servexia_monthly_pro',
  'servexia_yearly_pro',
  'servexia_monthly_enterprice',
  'servexia_yearly_enterprice',
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
              tooltip: 'تهيئة الباقات الافتراضية',
              onPressed: () => _seedPlans(context),
              icon: const Icon(Icons.cloud_upload_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
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
            _productLine('معرّف المنتج الشهري', plan.monthlyProductId),
            const SizedBox(height: 7),
            _productLine('معرّف المنتج السنوي', plan.yearlyProductId),
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

  Widget _productLine(String label, String value) {
    return Row(
      children: [
        Icon(
          value.trim().isEmpty
              ? Icons.warning_amber_rounded
              : Icons.tag_rounded,
          size: 16,
          color: value.trim().isEmpty ? Colors.orange : _primary,
        ),
        const SizedBox(width: 7),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? 'غير محدد' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
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
    final idCtrl = TextEditingController(text: existing?.id ?? '');
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
    final monthlyProductCtrl = TextEditingController(
      text: existing?.monthlyProductId ?? '',
    );
    final yearlyProductCtrl = TextEditingController(
      text: existing?.yearlyProductId ?? '',
    );
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        // امنع إغلاق النافذة بالنقر خارجها أثناء الحفظ.
        barrierDismissible: false,
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
                      _formSection('معرّفات المنتجات', Icons.tag_rounded),
                      const SizedBox(height: 10),
                      _productIdField(
                        monthlyProductCtrl,
                        'معرّف المنتج الشهري',
                      ),
                      _productIdField(yearlyProductCtrl, 'معرّف المنتج السنوي'),
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
                      _textField(
                        idCtrl,
                        'معرف الباقة',
                        text: true,
                        hint: 'مثال: main',
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
                          final id = idCtrl.text.trim();
                          if (id.isEmpty) {
                            _showMessage(
                              context,
                              'أدخل اسم الباقة.',
                              isError: true,
                            );
                            return;
                          }
                          if (id.contains('/')) {
                            _showMessage(
                              context,
                              'معرّف الباقة لا يجوز أن يحتوي على /.',
                              isError: true,
                            );
                            return;
                          }
                          final monthlyId = monthlyProductCtrl.text.trim();
                          final yearlyId = yearlyProductCtrl.text.trim();
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
                            id: id,
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
                              await _service.updatePlan(
                                plan,
                                oldId: existing.id,
                              );
                            } else {
                              await _service.addPlan(plan);
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (context.mounted) {
                              _showMessage(context, 'تم حفظ الباقة.');
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(() => isSaving = false);
                            }
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
      idCtrl.dispose();
      groupsCtrl.dispose();
      itemsCtrl.dispose();
      invoicesCtrl.dispose();
      assetsCtrl.dispose();
      membersCtrl.dispose();
      orderCtrl.dispose();
      monthlyProductCtrl.dispose();
      yearlyProductCtrl.dispose();
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

  /// حقل نص حر مع قائمة اقتراحات ثابتة اختيارية.
  Widget _productIdField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'اكتب معرّفًا أو اختر من القائمة',
          prefixIcon: const Icon(Icons.tag_rounded),
          suffixIcon: PopupMenuButton<String>(
            tooltip: 'اختيار معرّف مقترح',
            icon: const Icon(Icons.arrow_drop_down_rounded),
            onSelected: (value) {
              controller.value = TextEditingValue(
                text: value,
                selection: TextSelection.collapsed(offset: value.length),
              );
            },
            itemBuilder: (context) => kSuggestedProductIds
                .map((id) => PopupMenuItem<String>(value: id, child: Text(id)))
                .toList(),
          ),
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
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.red.shade700 : null,
          content: Text(message),
        ),
      );
  }
}
