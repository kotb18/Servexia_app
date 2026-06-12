import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintenance/addAwarehouseItem.dart';
import 'package:maintenance/customersSuppliers.dart';
import 'package:maintenance/invoiceSettings.dart';
import 'package:maintenance/models.dart';
import 'package:maintenance/myInvoices.dart';
import 'package:maintenance/warehouseScreen.dart';
import 'package:maintenance/workSpace.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ═══ SECTION 1: CONSTANTS & THEME ══════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.background,
      selectedColor: AppColors.primary,
      labelStyle: const TextStyle(fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══ SECTION 2: INVOICE TYPE MODEL ═════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class InvoiceTypeModel {
  final String title;
  final String type;
  final String titleEnglish;
  final IconData icon;
  final Color color;
  final bool affectsStock;
  final bool needsWarehouseItems;
  final bool allowsManualItems;
  final bool requiresOriginalInvoice;

  const InvoiceTypeModel({
    required this.title,
    required this.type,
    required this.titleEnglish,
    required this.icon,
    required this.color,
    required this.affectsStock,
    required this.needsWarehouseItems,
    required this.allowsManualItems,
    required this.requiresOriginalInvoice,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══ SECTION 3: GLOBAL STATE (FIXED - Encapsulated in ChangeNotifier) ══════════
// ═══════════════════════════════════════════════════════════════════════════════

class InvoiceState extends ChangeNotifier {
  DateTime selectedDate = DateTime.now();
  int lastInvoiceNumber = 0;
  double priceSumItems = 0.0;
  double discountValue = 0.0;
  double taxValue = 0.0;
  double total = 0.0;

  String? companyName;
  String? companyAddress;
  String? companyPhone;
  String? companyEmail;
  String? companyLogoPath;

  double? amountPaid;
  double? amountDue;

  bool showLogo = true;
  bool showAddress = true;
  bool showPhone = true;
  bool showEmail = true;
  bool showNotes = true;
  bool showTax = true;
  bool showDiscount = true;

  // For return invoices
  String? originalInvoiceId;
  String? originalInvoiceNumber;

  // Payment schedule
  List<Map<String, dynamic>> paymentScheduleData = [
    {
      "type": "مدفوع",
      "value": 0.0,
      'valuePicked': false,
      "date": DateTime.now(),
      'datePicked': false,
      "status": "تم",
    },
    {
      "type": "مستحق",
      "value": 0.0,
      "valuePicked": false,
      "date": DateTime.now().add(const Duration(days: 30)),
      'datePicked': false,
      "status": "!",
    },
  ];
  List<int> paymentIndexes = [0, 1];

  // Loading state
  bool _loading = false;
  bool get loading => _loading;
  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  // Recalculate flag
  bool _reCalculate = false;
  bool get reCalculate => _reCalculate;
  set reCalculate(bool value) {
    _reCalculate = value;
    notifyListeners();
  }

  void resetPaymentSchedule() {
    paymentScheduleData = [
      {
        "type": "مدفوع",
        "value": 0.0,
        'valuePicked': false,
        "date": DateTime.now(),
        'datePicked': false,
        "status": "تم",
      },
      {
        "type": "مستحق",
        "value": 0.0,
        "valuePicked": false,
        "date": DateTime.now().add(const Duration(days: 30)),
        'datePicked': false,
        "status": "!",
      },
    ];
    paymentIndexes = [0, 1];
    notifyListeners();
  }

  void reset() {
    selectedDate = DateTime.now();
    priceSumItems = 0.0;
    discountValue = 0.0;
    taxValue = 0.0;
    total = 0.0;
    originalInvoiceId = null;
    originalInvoiceNumber = null;
    resetPaymentSchedule();
    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══ SECTION 4: MAIN PAGE ══════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class InvoicePage extends StatefulWidget {
  const InvoicePage({
    super.key,
    required this.groupId,
    required this.itemsSale,
    required this.name,
    required this.phone,
    required this.address,
    required this.customerId,
    required this.isFromConstCustomers,
    required this.isFromWorkSpace,
    required this.itemsPurchase,
    required this.type,
    this.invoice,
    this.isEditMode = false,
    required this.isFormStore,
    this.orderId,
  });

  static const String screenroute = 'InvoicePage';

  final String groupId;
  final List<Map> itemsSale;
  final List<Map> itemsPurchase;
  final String name;
  final String phone;
  final String address;
  final String customerId;
  final bool isFromConstCustomers;
  final bool isFromWorkSpace;
  final String type;
  final Invoice? invoice;
  final bool isEditMode;
  final bool isFormStore;
  final String? orderId;

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String selectedFilter = 'بيع';
  late double totalBeforeReturn = 0.0;
  late double totalPaidInstallments = 0.0;
  late String paymentMethodReturn = '';

  final List<InvoiceTypeModel> invoiceTypes = [
    const InvoiceTypeModel(
      title: 'فاتورة بيع',
      type: 'بيع',
      titleEnglish: 'sale',
      icon: Icons.shopping_cart_outlined,
      color: AppColors.success,
      affectsStock: true,
      needsWarehouseItems: true,
      allowsManualItems: false,
      requiresOriginalInvoice: false,
    ),
    const InvoiceTypeModel(
      title: 'فاتورة شراء',
      type: 'شراء',
      titleEnglish: 'purchase',
      icon: Icons.shopping_bag_outlined,
      color: AppColors.primary,
      affectsStock: true,
      needsWarehouseItems: true,
      allowsManualItems: false,
      requiresOriginalInvoice: false,
    ),
    const InvoiceTypeModel(
      title: 'مرتجع',
      type: 'مرتجع',
      titleEnglish: 'return',
      icon: Icons.assignment_return_outlined,
      color: AppColors.danger,
      affectsStock: true,
      needsWarehouseItems: false,
      allowsManualItems: false,
      requiresOriginalInvoice: true,
    ),
    const InvoiceTypeModel(
      title: 'فاتورة صيانة',
      type: 'صيانة',
      titleEnglish: 'maintenance',
      icon: Icons.build_outlined,
      color: AppColors.warning,
      affectsStock: false,
      needsWarehouseItems: false,
      allowsManualItems: true,
      requiresOriginalInvoice: false,
    ),
    const InvoiceTypeModel(
      title: 'عرض سعر',
      type: 'عرض سعر',
      titleEnglish: 'quote',
      icon: Icons.description_outlined,
      color: AppColors.secondary,
      affectsStock: false,
      needsWarehouseItems: true,
      allowsManualItems: true,
      requiresOriginalInvoice: false,
    ),
  ];
  Invoice? result;
  late InvoiceState state;

  @override
  void initState() {
    super.initState();
    selectedFilter = widget.type;
    state = InvoiceState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    state.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.groupId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          state.companyName = data['name'] ?? '';
          state.companyAddress = data['address'] ?? '';
          state.companyPhone = data['phone'] ?? '';
          state.companyEmail = data['email'] ?? '';
          state.showLogo = data['showLogo'] ?? true;
          state.showAddress = data['showAddress'] ?? true;
          state.showPhone = data['showPhone'] ?? true;
          state.showEmail = data['showEmail'] ?? true;
          state.showNotes = data['showNotes'] ?? true;
          state.showTax = data['showTax'] ?? true;
          state.showDiscount = data['showDiscount'] ?? true;
          state.lastInvoiceNumber = data['lastInvoiceNumber'] ?? 1;
        });
      }

      final prefs = await SharedPreferences.getInstance();
      state.companyLogoPath = prefs.getString('logoPath${widget.groupId}');
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  void _resetForNewType(String newType) {
    setState(() {
      selectedFilter = newType;
      state.reset();
      widget.itemsPurchase.clear();
      widget.itemsSale.clear();
      returnItems.clear();
      returnType = '';
      selectedPaymentMethod = 'كاش';
      taxController.text = '0.0';
      discountController.text = '0.0';
      nameController.clear();
      phoneController.clear();
      addressController.clear();

      // Clear items based on type
      if (newType != 'بيع' && newType != 'عرض سعر') {
        widget.itemsSale.clear();
      }
      if (newType != 'شراء' && newType != 'عرض سعر') {
        widget.itemsPurchase.clear();
      }
    });
    _animationController.forward(from: 0);
    setState(() => state.reCalculate = true);
  }

  Future<void> _selectOriginalInvoice(bool isSelectionMode) async {
    returnItems.clear();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyInvoicesPage(
          groupId: widget.groupId,
          isSelectionMode: isSelectionMode,
          customerId: widget.customerId,
          customerName: widget.name,
          isFromCustomerScreen: false,
        ),
      ),
    );
    if (result != null && result is Invoice) {
      debugPrint('Selected original invoice: ${result.invoiceNumber}');
      setState(() {
        state.originalInvoiceId = result.id;
        state.originalInvoiceNumber = result.invoiceNumber;

        // Auto-fill customer data from original invoice
        final customer = result.customer;
        nameController.text = customer.name ?? '';
        phoneController.text = customer.phone ?? '';
        addressController.text = customer.address ?? '';
        returnType = result.type;
        selectedPaymentMethod = result.paymentMethod;
        discountController.text = result.summary.discountPercent.toString();
        taxController.text = result.summary.taxPercent.toString();
        totalBeforeReturn = double.parse(
          result.summary.total.toStringAsFixed(2),
        );
        paymentMethodReturn = result.paymentMethod;
        if (paymentMethodReturn == 'كاش') {
          totalPaidInstallments = double.parse(
            result.summary.total.toStringAsFixed(2),
          );
        } else {
          totalPaidInstallments = double.parse(
            (result.totalPaidInstallments.toStringAsFixed(2)),
          );
        }
        print('sssssssssssssssssssssssssssssssssssssssssss$totalBeforeReturn');
        // Copy payment schedule
        state.paymentScheduleData.clear();
        for (var installment in result.installments) {
          state.paymentScheduleData.add({
            "type": installment.type,
            "value": installment.value,
            'valuePicked': true,
            "date": installment.date,
            'datePicked': true,
            "status": installment.status,
          });
        }

        // Copy items for return (preserve item IDs for stock restoration)
        widget.itemsSale.clear();
        widget.itemsPurchase.clear();
        for (var item in result.items) {
          returnItems.add({
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'originalItem': true,
            'id': item.itemId ?? '',
            // FIX: Preserve item ID for stock restoration
          });
        }

        state.reCalculate = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم اختيار الفاتورة الأصلية: ${result.invoiceNumber}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _selectOriginalInvoice2(bool isSelectionMode) async {
    returnItems.clear();
    late Invoice? result;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyInvoicesPage(
          groupId: widget.groupId,
          isSelectionMode: isSelectionMode,
          customerId: widget.customerId,
          customerName: widget.name,
          isFromCustomerScreen: false,
          onInvoiceSelected: (invoice) {
            result = invoice; // استلم الفاتورة المختارة
            // هنا تستلم البيانات في الصفحة البعيدة مباشرة
            print("تم استلام الفاتورة: ${invoice.invoiceNumber}");
          },
        ),
        // settings: RouteSettings(name: '/MyInvoices'), // اختياري لتسمية المسار
      ),
    );
    if (result != null && result is Invoice) {
      debugPrint('Selected original invoice: ${result!.invoiceNumber}');
      setState(() {
        state.originalInvoiceId = result!.id;
        state.originalInvoiceNumber = result!.invoiceNumber;

        // Auto-fill customer data from original invoice
        final customer = result!.customer;
        nameController.text = customer.name ?? '';
        phoneController.text = customer.phone ?? '';
        addressController.text = customer.address ?? '';
        selectedFilter = result!.type;
        selectedPaymentMethod = result!.paymentMethod;
        discountController.text = result!.summary.discountPercent.toString();
        taxController.text = result!.summary.taxPercent.toString();
        // Copy payment schedule
        state.paymentScheduleData.clear();
        for (var installment in result!.installments) {
          state.paymentScheduleData.add({
            "type": installment.type,
            "value": installment.value,
            'valuePicked': true,
            "date": installment.date,
            'datePicked': true,
            "status": installment.status,
          });
        }

        // Copy items for return (preserve item IDs for stock restoration)
        widget.itemsSale.clear();
        widget.itemsPurchase.clear();
        for (var item in result!.items) {
          result!.type == 'بيع'
              ? widget.itemsSale.add({
                  'name': item.name,
                  'quantity': item.quantity,
                  'price': item.price,
                  'originalItem': true,
                  /*  'id':
                item.itemId ??
                '', */
                  // FIX: Preserve item ID for stock restoration
                })
              : result!.type == 'شراء'
              ? widget.itemsPurchase.add({
                  'name': item.name,
                  'quantity': item.quantity,
                  'price': item.price,
                  'originalItem': true,
                  /*  'id':
                item.itemId ??
                '', */
                  // FIX: Preserve item ID for stock restoration
                })
              : widget.itemsSale.add({
                  'name': item.name,
                  'quantity': item.quantity,
                  'price': item.price,
                  'originalItem': true,
                  /*  'id':
                item.itemId ??
                '', */
                  // FIX: Preserve item ID for stock restoration
                });
        }

        state.reCalculate = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم اختيار الفاتورة الأصلية: ${result!.invoiceNumber}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Color _getBackgroundColor(String type) {
    switch (type) {
      case 'بيع':
        return AppColors.success;
      case 'شراء':
        return AppColors.primary;
      case 'صيانة':
        return AppColors.warning;
      case 'مرتجع':
        return AppColors.danger;
      case 'عرض سعر':
        return AppColors.secondary;
      default:
        return AppColors.background;
    }
  }

  String _getTypeHint(String type) {
    switch (type) {
      case 'بيع':
        return 'عند حفظ الفاتورة، سيتم خصم الكميات من المخزون';
      case 'شراء':
        return 'عند حفظ الفاتورة، سيتم إضافة الكميات إلى المخزون';
      case 'مرتجع':
        return 'سيتم إعادة الكميات إلى المخزون عند الحفظ';
      case 'صيانة':
        return 'إضافة بنود الصيانة يدوياً';
      case 'عرض سعر':
        return 'عرض سعر - لا يؤثر على المخزون';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = invoiceTypes.firstWhere(
      (t) => t.type == selectedFilter,
    );

    return WillPopScope(
      onWillPop: () async {
        state.loading = false;
        nameController.clear();
        addressController.clear();
        phoneController.clear();
        notesController.clear();
        taxController.text = '0';
        discountController.text = '0';
        widget.itemsSale.clear();
        widget.itemsPurchase.clear();
        selectedPaymentMethod = 'كاش';
        returnItems.clear();
        Navigator.popUntil(
          context,
          ModalRoute.withName(WorkspaceHomeScreen.screenroute),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: _getBackgroundColor(selectedFilter),
        floatingActionButton: !widget.isEditMode
            ? FloatingActionButton.extended(
                onPressed: () async {
                  _resetForNewType('بيع');

                  _selectOriginalInvoice2(false);
                },
                backgroundColor: const Color.fromARGB(255, 115, 5, 117),
                foregroundColor: Colors.white,
                elevation: 6,
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text(
                  'فواتيري',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        appBar: AppBar(
          title: Text(
            !widget.isEditMode ? 'تسجيل فاتورة جديدة' : 'تعديل فاتورة',
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceSettingsPage(
                      groupId: widget.groupId,
                      isFromConstCustomers: false,
                      name: widget.name,
                      phone: widget.phone,
                      address: widget.address,
                      items: selectedFilter == 'بيع'
                          ? widget.itemsSale
                          : selectedFilter == 'شراء'
                          ? widget.itemsPurchase
                          : selectedFilter == 'عرض سعر'
                          ? []
                          : [],
                      customerId: widget.customerId,
                    ),
                  ),
                );
                if (result == true) _loadSettings();
              },
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Filter Chips
            if (!widget.isEditMode)
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: invoiceTypes.length,
                  itemBuilder: (context, index) {
                    final type = invoiceTypes[index];
                    final isSelected = type.type == selectedFilter;

                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: FilterChip(
                          avatar: Icon(
                            type.icon,
                            size: 18,
                            color: isSelected ? Colors.white : type.color,
                          ),
                          label: Text(type.title),
                          selected: isSelected,
                          selectedColor: type.color,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(
                            color: AppColors.border,
                            width: 2,
                          ),
                          onSelected: (_) => _resetForNewType(type.type),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Type hint
            if (_getTypeHint(selectedFilter).isNotEmpty && !widget.isEditMode)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  _getTypeHint(selectedFilter),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Return invoice selector
            if (selectedFilter == 'مرتجع' && !widget.isEditMode)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الفاتورة الأصلية',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (state.originalInvoiceNumber != null)
                            Text(
                              state.originalInvoiceNumber!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _selectOriginalInvoice(true);
                      },
                      icon: const Icon(Icons.search, color: Colors.white),
                      label: Text(
                        state.originalInvoiceId == null
                            ? 'اختيار فاتورة'
                            : 'تغيير',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          12,
                          150,
                          155,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Invoice Content
            Expanded(
              child:
                  selectedFilter == 'مرتجع' &&
                      state.originalInvoiceNumber == null
                  ? SizedBox.shrink()
                  : InvoicePageDesign(
                      type: selectedFilter,
                      groupId: widget.groupId,
                      itemsSale: widget.itemsSale,
                      itemsPurchase: widget.itemsPurchase,
                      name: widget.name,
                      phone: widget.phone,
                      address: widget.address,
                      customerId: widget.customerId,
                      isFromConstCustomers: widget.isFromConstCustomers,
                      state: state,
                      invoiceType: selectedType,
                      isEditMode: widget.isEditMode,
                      totalBeforeReturn: totalBeforeReturn,
                      totalPaidInstallments: totalPaidInstallments,
                      isFromStore: widget.isFormStore,
                      orderId: widget.orderId ?? '',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══ SECTION 5: INVOICE DESIGN (Content Widget) ══════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

// Global controllers - scoped to file for shared access between widgets
TextEditingController nameController = TextEditingController();
TextEditingController addressController = TextEditingController();
TextEditingController phoneController = TextEditingController();
TextEditingController notesController = TextEditingController();
TextEditingController taxController = TextEditingController(text: '0');
TextEditingController discountController = TextEditingController(text: '0');
String? selectedPaymentMethod = 'كاش';
List<Map> returnItems = [];
String returnType = '';

// For maintenance items (manual entry)
List<Map<String, dynamic>> maintenanceItems = [];
TextEditingController maintenanceDescController = TextEditingController();
TextEditingController maintenancePriceController = TextEditingController();

class InvoicePageDesign extends StatefulWidget {
  final String type;
  final String groupId;
  final List<Map> itemsSale;
  final List<Map> itemsPurchase;
  final String name;
  final String phone;
  final String address;
  final String customerId;
  final bool isFromConstCustomers;
  final InvoiceState state;
  final InvoiceTypeModel invoiceType;
  final bool isEditMode;
  final double totalBeforeReturn;
  final double totalPaidInstallments;
  final bool isFromStore;
  final String orderId;

  const InvoicePageDesign({
    super.key,
    required this.type,
    required this.groupId,
    required this.itemsSale,
    required this.name,
    required this.phone,
    required this.address,
    required this.customerId,
    required this.isFromConstCustomers,
    required this.state,
    required this.invoiceType,
    required this.itemsPurchase,
    required this.isEditMode,
    required this.totalBeforeReturn,
    required this.totalPaidInstallments,
    required this.isFromStore,
    required this.orderId,
  });

  @override
  State<InvoicePageDesign> createState() => _InvoicePageDesignState();
}

class _InvoicePageDesignState extends State<InvoicePageDesign> {
  final List<String> paymentMethods = ['كاش', 'آجل', 'تقسيط'];
  late double netTotal = 0.0;
  @override
  void initState() {
    super.initState();
    // Initialize controllers with customer data if coming from customers list
    if (widget.isFromConstCustomers || widget.isFromStore) {
      nameController.text = widget.name;
      phoneController.text = widget.phone;
      addressController.text = widget.address;
    }
    selectedPaymentMethod = 'كاش';
    // Initialize tax/discount from settings
    taxController.text = !widget.state.showTax ? '0' : taxController.text;
    discountController.text = !widget.state.showDiscount
        ? '0'
        : discountController.text;

    // Trigger initial calculation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calculateTotals();
    });
  }

  @override
  void dispose() {
    // Note: Global controllers are NOT disposed here to preserve state across rebuilds
    // They are reset in WillPopScope when leaving the page
    super.dispose();
  }

  /// Get current items list based on invoice type
  List<Map> get _currentItems {
    switch (widget.type) {
      case 'صيانة':
        return maintenanceItems;
      case 'شراء':
        return widget.itemsPurchase;
      case 'بيع':
        return widget.itemsSale;
      case 'مرتجع':
        return returnItems;
      case 'عرض سعر':
      default:
        return widget.itemsSale;
    }
  }

  /// Calculate all financial totals
  void _calculateTotals() {
    if (!mounted) return;

    setState(() {
      double sum = 0.0;

      switch (widget.type) {
        case 'صيانة':
          sum = maintenanceItems.fold(
            0.0,
            (sum, item) =>
                sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1)),
          );
          break;
        case 'شراء':
          sum = widget.itemsPurchase.fold(
            0.0,
            (sum, item) =>
                sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1)),
          );
          break;
        case 'عرض سعر':
        case 'بيع':
          sum = widget.itemsSale.fold(
            0.0,
            (sum, item) =>
                sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1).abs()),
          );
          break;
        case 'مرتجع':
          sum = returnItems.fold(
            0.0,
            (sum, item) =>
                sum + ((item['price'] ?? 0) * (item['quantity'] ?? 0).abs()),
          );

          break;
      }

      widget.state.priceSumItems = sum;

      final discountPercent = double.tryParse(discountController.text) ?? 0;
      widget.state.discountValue =
          widget.state.priceSumItems * discountPercent / 100;

      final taxPercent = double.tryParse(taxController.text) ?? 0;
      widget.state.taxValue =
          (widget.state.priceSumItems - widget.state.discountValue) *
          taxPercent /
          100;

      widget.state.total = double.parse(
        (widget.state.priceSumItems +
                widget.state.taxValue -
                widget.state.discountValue)
            .toStringAsFixed(2),
      );
      setState(() {
        netTotal = double.parse(
          (widget.totalBeforeReturn -
                  widget.totalPaidInstallments -
                  widget.state.total)
              .toStringAsFixed(2),
        );
      });
      widget.state.reCalculate = false;
    });
  }

  /// Show edit dialog for numeric fields
  void _showEditDialog({
    required String title,
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required VoidCallback onSave,
    String? suffix,
  }) {
    final tempController = TextEditingController(text: controller.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tempController,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: label,
                suffixText: suffix,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onTap: () {
                tempController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: tempController.text.length,
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              controller.text = tempController.text;
              onSave();
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  /// Reset all invoice data
  void _resetInvoice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('تأكيد'),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من إعادة تعيين جميع بيانات الفاتورة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                widget.state.resetPaymentSchedule();
                maintenanceItems.clear();
              });
              nameController.clear();
              addressController.clear();
              phoneController.clear();
              notesController.clear();
              taxController.text = widget.state.showTax ? '0' : '0';
              discountController.text = '0';
              widget.itemsSale.clear();
              widget.itemsPurchase.clear();
              selectedPaymentMethod = 'كاش';
              returnItems.clear();
              _calculateTotals();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('موافق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Get English title for invoice number generation
  String _getTitleEnglish(String type) {
    switch (type) {
      case 'بيع':
        return 'sale';
      case 'شراء':
        return 'purchase';
      case 'صيانة':
        return 'maintenance';
      case 'مرتجع':
        return 'return';
      case 'عرض سعر':
        return 'quote';
      default:
        return 'invoice';
    }
  }

  /// Build invoice data map for Firestore
  Map<String, dynamic> buildInvoiceData(String? reInvoiceId) {
    final List<Map<String, dynamic>> items = [];

    switch (widget.type) {
      case 'صيانة':
        items.addAll(
          maintenanceItems.map(
            (item) => {
              "name": item['name'],
              "quantity": item['quantity'] ?? 1,
              "price": item['price'] ?? 0,
              "total": (item['quantity'] ?? 1) * (item['price'] ?? 0),
              "isManual": true,
              'itemId': item['id'] ?? '',
            },
          ),
        );
        break;
      case 'شراء':
        items.addAll(
          widget.itemsPurchase.map(
            (item) => {
              "name": item['name'],
              "quantity": item['quantity'] ?? 0,
              "price": item['price'] ?? 0,
              "total": (item['quantity'] ?? 0) * (item['price'] ?? 0),
              'itemId': item['id'] ?? '',
            },
          ),
        );
        break;
      case 'عرض سعر':
        items.addAll(
          widget.itemsSale.map(
            (item) => {
              "name": item['name'],
              "quantity": item['quantity'] ?? 0,
              "price": item['price'] ?? 0,
              "total": (item['quantity'] ?? 0) * (item['price'] ?? 0),
              "isManual": item['isManual'] ?? false,
              'itemId': item['id'] ?? '',
            },
          ),
        );
        break;
      case 'مرتجع':
        items.addAll(
          returnItems.map(
            (item) => {
              "name": item['name'],
              "quantity": item['quantity'] ?? 0,
              "price": item['price'] ?? 0,
              "total": (item['quantity'] ?? 0).abs() * (item['price'] ?? 0),
              "isReturn": true,
              'itemId':
                  item['id'] ?? '', // FIX: Include itemId for stock restoration
            },
          ),
        );
        break;
      default: // 'بيع'
        items.addAll(
          widget.itemsSale.map(
            (item) => {
              "name": item['name'],
              "quantity": item['quantity'] ?? 0,
              "price": item['price'] ?? 0,
              "total": (item['quantity'] ?? 0).abs() * (item['price'] ?? 0),
              'itemId': item['id'] ?? '',
            },
          ),
        );
    }

    return {
      'reInvoiceId': reInvoiceId ?? '', // Include ID for edit mode
      "type": widget.type,
      "customer": {
        "id": widget.customerId,
        "name": nameController.text.isNotEmpty ? nameController.text : null,
        "phone": phoneController.text.isNotEmpty ? phoneController.text : null,
        "address": addressController.text.isNotEmpty
            ? addressController.text
            : null,
      },
      "items": items,
      "summary": {
        "subTotal": widget.state.priceSumItems,
        "discountPercent": double.tryParse(discountController.text) ?? 0,
        "discountValue": widget.state.discountValue,
        "taxPercent": double.tryParse(taxController.text) ?? 0,
        "taxValue": widget.state.taxValue,
        "total": widget.state.total,
      },
      "notes": notesController.text.isNotEmpty ? notesController.text : null,
      "date": widget.state.selectedDate.toIso8601String(),
      "invoiceNumber": widget.type != 'مرتجع'
          ? "${_getTitleEnglish(widget.type)}-${DateTime.now().year}-${widget.state.lastInvoiceNumber + 1}"
          : 'return-${widget.state.originalInvoiceNumber ?? ''}',
      "createdAt": DateTime.now().toIso8601String(),
      'paymentMethod': selectedPaymentMethod,
      'thereIsReturn': false,
      if (widget.type == 'مرتجع') ...{
        'originalInvoiceId': widget.state.originalInvoiceId,
        'originalInvoiceNumber': widget.state.originalInvoiceNumber,
        'returnType': 'مرتجع $returnType',
        'returnSummary': {
          'totalBeforeReturn': widget.totalBeforeReturn,
          'totalPaidInstallments': widget.totalPaidInstallments,
          "total": widget.state.total,
          'netTotal': netTotal,
        },
      },
      if (widget.type == 'عرض سعر') 'isQuote': true,
    };
  }

  /// Save invoice to Firestore and update stock
  Future<void> saveInvoice() async {
    final firestore = FirebaseFirestore.instance;

    final invoiceDocRef = firestore
        .collection('invoices')
        .doc(widget.groupId)
        .collection('items')
        .doc();

    final String reInvoiceId = invoiceDocRef.id;

    final dataFinal = buildInvoiceData(reInvoiceId);

    // إضافة جدول الدفع
    if (selectedPaymentMethod != 'كاش') {
      for (int i = 0; i < widget.state.paymentScheduleData.length; i++) {
        dataFinal['payment${i + 1}'] = {
          "type": widget.state.paymentScheduleData[i]['type'],
          "value": widget.state.paymentScheduleData[i]['value'],
          "date": (widget.state.paymentScheduleData[i]['date'] as DateTime)
              .toIso8601String(),
          "status": widget.state.paymentScheduleData[i]['status'],
        };
      }
    }

    final batch = firestore.batch();

    // حفظ الفاتورة
    batch.set(invoiceDocRef, dataFinal);

    // تحديث الفاتورة الأصلية لو مرتجع
    if (widget.type == 'مرتجع') {
      final originalInvoiceRef = firestore
          .collection('invoices')
          .doc(widget.groupId)
          .collection('items')
          .doc(widget.state.originalInvoiceId);

      batch.update(originalInvoiceRef, {
        'thereIsReturn': true,
        'reInvoiceId': reInvoiceId,
      });
    }
    if (widget.orderId != '') {
      final ref4 = FirebaseFirestore.instance
          .collection('store_orders')
          .doc(widget.groupId)
          .collection('items')
          .doc(widget.orderId);
      batch.update(ref4, {'linkedInvoiceId': reInvoiceId});
    }
    // تحديث رقم آخر فاتورة
    final invoiceMainRef = firestore.collection('invoices').doc(widget.groupId);

    batch.update(invoiceMainRef, {
      'lastInvoiceNumber': widget.state.lastInvoiceNumber + 1,
    });

    // تحديث المخزون
    if (widget.invoiceType.affectsStock &&
        (widget.type == 'بيع' || widget.type == 'شراء')) {
      await _updateStock();
    } else if (widget.type == 'مرتجع') {
      await _restoreStock();
    }

    // تنفيذ كل العمليات مرة واحدة
    await batch.commit();
  }

  /// Update stock for sale/purchase invoices
  Future<void> _updateStock() async {
    final items = widget.type == 'شراء'
        ? widget.itemsPurchase
        : widget.itemsSale;
    final batch = FirebaseFirestore.instance.batch();

    for (var item in items) {
      final itemId = item['id'] as String?;
      if (itemId == null || itemId.isEmpty) continue;

      final ref = FirebaseFirestore.instance
          .collection('inventory')
          .doc(widget.groupId)
          .collection('items')
          .doc(itemId);
      final ref2 = ref.collection('movements').doc();
      batch.set(ref2, {
        'type': widget.type == 'شراء' ? 'in' : 'out',
        'qty': item['quantity'],
        'unit': 'unit',
        'note': widget.type == 'شراء'
            ? 'تمت الإضافة عن طريق فاتورة الشراء رقم ${_getTitleEnglish(widget.type)}-${DateTime.now().year}-${widget.state.lastInvoiceNumber + 1}'
            : 'تم الصرف عن طريق فاتورة البيع رقم ${_getTitleEnglish(widget.type)}-${DateTime.now().year}-${widget.state.lastInvoiceNumber + 1}',
        'createdBy': 'currentUser',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(ref, {
        'quantity': FieldValue.increment(
          widget.type == 'شراء' ? item['quantity'] : -item['quantity'],
        ), // زيادة 5
      });
    }

    await batch.commit();
  }

  /// Restore stock for return invoices - FIX: Uses returnItems instead of itemsSale
  Future<void> _restoreStock() async {
    final batch = FirebaseFirestore.instance.batch();

    // FIX: Use returnItems instead of widget.itemsSale
    for (var item in returnItems) {
      final itemId = item['id'] as String?;
      if (itemId == null || itemId.isEmpty) continue;

      final ref = FirebaseFirestore.instance
          .collection('inventory')
          .doc(widget.groupId)
          .collection('items')
          .doc(itemId);

      final doc = await ref.get();
      if (doc.exists) {
        final currentQty = (doc.data()?['quantity'] ?? 0) as num;
        final returnedQty = (item['quantity'] ?? 0).abs();
        if (returnType == 'بيع') {
          batch.update(ref, {'quantity': currentQty + returnedQty});
        } else if (returnType == 'شراء') {
          batch.update(ref, {'quantity': currentQty - returnedQty});
        }
      }
    }

    await batch.commit();
  }

  /// Get customer label based on invoice type
  String _getCustomerLabel() {
    switch (widget.type) {
      case 'شراء':
        return 'اسم المورد';
      case 'صيانة':
        return 'اسم العميل';
      default:
        return 'اسم العميل';
    }
  }

  /// Add maintenance item dialog
  void _addMaintenanceItem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'إضافة بند صيانة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: maintenanceDescController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'وصف البند',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maintenancePriceController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'السعر',
                // suffixText: 'ج.م',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (maintenanceDescController.text.isNotEmpty &&
                  maintenancePriceController.text.isNotEmpty) {
                setState(() {
                  maintenanceItems.add({
                    'name': maintenanceDescController.text,
                    'price':
                        double.tryParse(maintenancePriceController.text) ?? 0,
                    'quantity': 1,
                  });
                  maintenanceDescController.clear();
                  maintenancePriceController.clear();
                  _calculateTotals();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  /// Show dialog for manual item entry
  void _showManualItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'إضافة صنف يدوي',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'اسم الصنف',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'السعر',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'الكمية',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                setState(() {
                  widget.itemsSale.add({
                    'name': nameCtrl.text,
                    'price': double.tryParse(priceCtrl.text) ?? 0,
                    'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                    'isManual': true,
                  });
                  _calculateTotals();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.state.loading
        ? const Center(
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          )
        : Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildInvoiceInfo(),
                          const Divider(height: 32),
                          _buildCustomerSection(),
                          const Divider(height: 32),
                          _buildItemsSection(),
                          const Divider(height: 32),
                          _buildTotalsSection(),
                          const Divider(height: 32),
                          if (widget.type == 'مرتجع') _buildTable(),
                          const Divider(height: 32),
                          if (widget.type == 'بيع' ||
                              widget.type == 'شراء' ||
                              widget.type == 'مرتجع')
                            _buildPaymentMethod(),

                          if ((selectedPaymentMethod == 'آجل' ||
                                  selectedPaymentMethod == 'تقسيط') &&
                              widget.type != 'عرض سعر') ...[
                            _buildDuePaymentsSection(),
                            const SizedBox(height: 20),
                          ],

                          _buildNotesSection(),
                          const SizedBox(height: 24),
                          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
  }

  // ─── UI BUILDERS ───

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.invoiceType.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.invoiceType.icon,
            color: widget.invoiceType.color,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.type != 'مرتجع'
                    ? widget.invoiceType.title
                    : 'return-${widget.state.originalInvoiceNumber ?? ''}',
                style: const TextStyle(
                  // fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                widget.type != 'مرتجع'
                    ? '${_getTitleEnglish(widget.type)}-${DateTime.now().year}-${widget.state.lastInvoiceNumber + 1}'
                    : '',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _resetInvoice,
          icon: const Icon(Icons.refresh, color: AppColors.danger),
          tooltip: 'إعادة تعيين',
        ),
      ],
    );
  }

  Widget _buildInvoiceInfo() {
    final formattedDate =
        '${widget.state.selectedDate.year}-'
        '${widget.state.selectedDate.month.toString().padLeft(2, '0')}-'
        '${widget.state.selectedDate.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoItem(
              icon: Icons.calendar_today_outlined,
              label: 'التاريخ',
              value: formattedDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: widget.state.selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.primary,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() => widget.state.selectedDate = picked);
                }
              },
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: AppColors.divider,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: _buildInfoItem(
              icon: Icons.numbers_outlined,
              label: 'رقم الفاتورة',
              value: '${widget.state.lastInvoiceNumber + 1}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'طريقة الدفع',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: paymentMethods.map((method) {
              final isSelected = selectedPaymentMethod == method;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    widget.state.resetPaymentSchedule();
                    selectedPaymentMethod = method;
                    // Reset payment schedule for new method
                    widget.state.paymentScheduleData = [
                      {
                        "type": "مدفوع",
                        "value": 0.0,
                        'valuePicked': false,
                        "date": DateTime.now(),
                        'datePicked': false,
                        "status": "تم",
                      },
                      {
                        "type": selectedPaymentMethod == 'آجل'
                            ? "مستحق"
                            : 'قسط 1',
                        "value": 0.0,
                        "valuePicked": false,
                        "date": DateTime.now().add(const Duration(days: 30)),
                        'datePicked': false,
                        "status": "!",
                      },
                    ];
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      method,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCustomerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getCustomerLabel(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.type != 'مرتجع')
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => CustomersSuppliers(
                        groupId: widget.groupId,
                        itemsSale: widget.itemsSale.isEmpty
                            ? []
                            : widget.itemsSale,
                        itemsPruchase: widget.itemsPurchase.isEmpty
                            ? []
                            : widget.itemsPurchase,
                        isFromInvoice: true,
                        invoiceType: widget.type,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text('اختيار من القائمة'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: nameController,
          label: 'الاسم',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: phoneController,
          label: 'رقم الهاتف',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: addressController,
          label: 'العنوان',
          icon: Icons.location_on_outlined,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: widget.type != 'مرتجع',
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
    );
  }

  Widget _buildItemsSection() {
    final items = _currentItems;
    final bool isMaintenance = widget.type == 'صيانة';
    final bool isQuote = widget.type == 'عرض سعر';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isMaintenance
                  ? 'بنود الصيانة'
                  : widget.type == 'مرتجع'
                  ? 'الأصناف المرتجعة'
                  : 'الأصناف',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.type == 'مرتجع'
                    ? Colors.red
                    : AppColors.textPrimary,
              ),
            ),
            if (items.isNotEmpty)
              Text(
                '${items.length} ${isMaintenance ? 'بند' : 'صنف'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (items.isEmpty)
          _buildEmptyItemsState(isMaintenance)
        else
          _buildItemsList(items, isMaintenance),

        const SizedBox(height: 12),
        if (widget.type != 'مرتجع') _buildAddItemButton(isMaintenance, isQuote),
      ],
    );
  }

  Widget _buildEmptyItemsState(bool isMaintenance) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(
              isMaintenance ? Icons.build_outlined : Icons.inventory_2_outlined,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              isMaintenance ? 'لا توجد بنود صيانة' : 'لا توجد أصناف',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isMaintenance ? 'أضف بنود الصيانة' : 'أضف أصناف من المخزن',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(List<Map> items, bool isMaintenance) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final quantity = (item['quantity'] ?? 0).abs();
        final price = item['price'] ?? 0;
        final total = quantity * price;
        final bool isReturn =
            item['isReturn'] == true || (item['quantity'] ?? 0) < 0;

        return Dismissible(
          key: Key(item['id']?.toString() ?? '$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: AppColors.danger,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            setState(() {
              if (isMaintenance) {
                maintenanceItems.removeAt(index);
              } else if (widget.type == 'شراء') {
                widget.itemsPurchase.removeAt(index);
              } else if (widget.type == 'مرتجع') {
                returnItems.removeAt(index);
              } else {
                widget.itemsSale.removeAt(index);
              }
              _calculateTotals();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isReturn
                        ? AppColors.danger.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isMaintenance
                        ? Icons.build_outlined
                        : Icons.inventory_2_outlined,
                    color: isReturn ? AppColors.danger : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'بند غير معروف',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (!isMaintenance)
                        Text(
                          '$quantity × ${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  total.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isReturn ? AppColors.danger : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddItemButton(bool isMaintenance, bool isQuote) {
    if (isMaintenance) {
      return OutlinedButton.icon(
        onPressed: _addMaintenanceItem,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('إضافة بند صيانة'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }

    if (isQuote) {
      return Column(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreScreen(
                    groupId: widget.groupId,
                    isFromInvoice: true,
                    deletedItems: widget.state.total == 0.0,
                    invoiceType: widget.type,
                    customerId: widget.customerId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.warehouse_outlined),
            label: const Text('اختيار من المخزن'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showManualItemDialog,
            icon: const Icon(Icons.edit_note),
            label: const Text('إضافة صنف يدوي'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: widget.type == 'بيع'
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreScreen(
                    groupId: widget.groupId,
                    isFromInvoice: true,
                    deletedItems: widget.state.total == 0.0,
                    invoiceType: widget.type,
                    customerId: widget.customerId,
                  ),
                ),
              );
            }
          : () async {
              await AwesomeDialog(
                dialogType: DialogType.question,
                context: context,
                title: 'إضـــافة صنف',
                btnOkText: 'صنف مخزني',
                btnCancelText: 'صنف جديد',
                btnOkColor: Colors.blueGrey,
                btnCancelColor: const Color.fromARGB(255, 8, 73, 126),
                btnOkOnPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoreScreen(
                        groupId: widget.groupId,
                        isFromInvoice: true,
                        deletedItems: widget.state.total == 0.0,
                        invoiceType: widget.type,
                        customerId: widget.customerId,
                      ),
                    ),
                  );
                },
                btnCancelOnPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddInventoryItemScreen(
                        groupId: widget.groupId,
                        invoiceType: widget.type,
                        isFromInvoice: true,
                        customerId: widget.customerId,
                      ),
                    ),
                  );
                },
              ).show();
            },
      icon: const Icon(Icons.add_circle_outline),
      label: Text(
        widget.type == 'بيع' ? 'إختيـــار صنف من المخزن' : 'إضـــافة صنف',
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (widget.state.showDiscount || widget.state.showTax)
            _buildTotalRow('المجموع الفرعي', widget.state.priceSumItems),
          const SizedBox(height: 8),
          if (widget.state.showDiscount)
            _buildEditableTotalRow(
              label: 'الخصم',
              controller: discountController,
              suffix: '%',
              calculatedValue: widget.state.discountValue,
              color: Colors.redAccent,
              onEdit: () => widget.type != 'مرتجع'
                  ? _showEditDialog(
                      title: 'تعديل نسبة الخصم',
                      label: 'نسبة الخصم',
                      controller: discountController,
                      keyboardType: TextInputType.number,
                      suffix: '%',
                      onSave: _calculateTotals,
                    )
                  : null,
            ),
          const SizedBox(height: 8),
          if (widget.state.showTax)
            _buildEditableTotalRow(
              label: 'الضريبة',
              controller: taxController,
              suffix: '%',
              calculatedValue: widget.state.taxValue,
              color: Colors.black,
              onEdit: () => widget.type != 'مرتجع'
                  ? _showEditDialog(
                      title: 'تعديل نسبة الضريبة',
                      label: 'نسبة الضريبة',
                      controller: taxController,
                      keyboardType: TextInputType.number,
                      suffix: '%',
                      onSave: _calculateTotals,
                    )
                  : null,
            ),
          if (widget.state.showDiscount || widget.state.showTax)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
          _buildTotalRow(
            'الإجمالي الكلي',
            widget.state.total,
            isTotal: true,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double value, {
    bool isTotal = false,
    Color? color,
  }) {
    // FIX: Use post-frame callback safely with mounted check
    if (widget.state.reCalculate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _calculateTotals());
        }
      });
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal
                ? (color ?? AppColors.textPrimary)
                : AppColors.textSecondary,
          ),
        ),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: isTotal ? 20 : 15,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal
                ? (color ?? AppColors.textPrimary)
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.5)},
      children: [
        // عنوان الجدول
        TableRow(
          decoration: BoxDecoration(color: Colors.blue.shade50),
          children: [
            _tableCell('البيان', isHeader: true),
            _tableCell('القيمة', isHeader: true),
          ],
        ),

        // الإجمالي الأصلي
        TableRow(
          children: [
            _tableCell('إجمالي الفاتورة الأصلية'),
            _tableCell('${widget.totalBeforeReturn} ', color: Colors.green),
          ],
        ),
        // إجمالي المدفوع في الفاتورة الأصلية
        TableRow(
          children: [
            _tableCell('إجمالي المدفوع في الفاتورة الأصلية'),
            _tableCell('${widget.totalPaidInstallments} ', color: Colors.red),
          ],
        ),
        // إجمالي المرتجع
        TableRow(
          children: [
            _tableCell('إجمالي المرتجع'),
            _tableCell('${widget.state.total} ', color: Colors.red),
          ],
        ),

        // الصافي بعد المرتجع
        TableRow(
          decoration: BoxDecoration(color: Colors.green.shade50),
          children: [
            _tableCell('الصافي بعد المرتجع', isBold: true),
            _tableCell(
              '$netTotal ',
              isBold: true,
              color: netTotal < 0.0
                  ? const Color.fromARGB(255, 175, 28, 112)
                  : const Color.fromARGB(255, 6, 88, 9),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isHeader ? 16 : 14,
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.w500,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }

  Widget _buildEditableTotalRow({
    required String label,
    required TextEditingController controller,
    required String suffix,
    required double calculatedValue,
    required VoidCallback? onEdit,
    required Color color,
  }) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${controller.text}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              calculatedValue.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuePaymentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'جدولة المدفوعات',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        CustomPaymentsTable(
          total: widget.type == 'مرتجع' ? netTotal : widget.state.total,
          paymentScheduleData: widget.state.paymentScheduleData,
          paymentIndexes: widget.state.paymentIndexes,
          paymentMethod: selectedPaymentMethod,
          onDataChanged: () => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return TextField(
      controller: notesController,
      maxLines: 3,
      textAlign: TextAlign.right,
      decoration: const InputDecoration(
        labelText: 'ملاحظات',
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: 48),
          child: Icon(Icons.notes_outlined),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    final bool hasItems = widget.type == 'صيانة'
        ? maintenanceItems.isNotEmpty
        : (widget.itemsSale.isNotEmpty ||
              widget.itemsPurchase.isNotEmpty ||
              returnItems.isNotEmpty);

    final bool isValid =
        hasItems &&
        (widget.type != 'مرتجع' || widget.state.originalInvoiceId != null);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isValid
            ? () => showCustomDialog(
                context: context,
                title: 'تأكيد الحفظ',
                message: 'إختر نوع الفاتوره',
              )
            : null,
        icon: const Icon(Icons.save_outlined, color: Colors.white),
        label: Text(
          widget.type == 'عرض سعر' ? 'حفظ عرض السعر' : 'حفظ وطباعة الفاتورة',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          disabledBackgroundColor: AppColors.border,
        ),
      ),
    );
  }

  Future<void> showCustomDialog({
    required BuildContext context,
    required String title,
    required String message,

    VoidCallback? onConfirm,
  }) async {
    await showDialog(
      context: context,
      //  barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (!mounted) return;
                navigator.pop();
                await _handleSave(true);
              },
              child: Text('طابعة حرارية'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (!mounted) return;
                navigator.pop();
                await _handleSave(false);
              },
              child: Text('طابعة A4'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSave(bool thermalInvoice) async {
    // Validate payment schedule sums
    if (selectedPaymentMethod != 'كاش' && widget.type != 'عرض سعر') {
      double sum = widget.state.paymentScheduleData.fold(
        0.0,
        (sum, item) => sum + ((item['value'] ?? 0.0) as num).toDouble(),
      );
      if (sum != widget.state.total) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'خطأ',
          desc: 'لا يمكن ان يكون مجموع الأقساط لا يساوي المجموع الكلي',
          btnOkText: 'حسنا',
          btnOkOnPress: () {},
        ).show();
        return;
      }
    }

    try {
      setState(() => widget.state.loading = true);
      await saveInvoice();

      // Prepare items for PDF
      List<Map<String, dynamic>> pdfItems = [];
      if (widget.type == 'صيانة') {
        pdfItems = maintenanceItems
            .map(
              (item) => {
                'name': item['name'],
                'quantity': item['quantity'] ?? 1,
                'price': item['price'] ?? 0,
                'total': (item['quantity'] ?? 1) * (item['price'] ?? 0),
              },
            )
            .toList();
      } else if (widget.type == 'شراء') {
        pdfItems = widget.itemsPurchase
            .map(
              (item) => {
                'name': item['name'] ?? '',
                'quantity': item['quantity'] ?? 0,
                'price': item['price'] ?? 0,
                'total': (item['quantity'] ?? 0) * (item['price'] ?? 0),
              },
            )
            .toList();
      } else if (widget.type == 'مرتجع') {
        // FIX: Use returnItems for PDF generation
        pdfItems = returnItems
            .map(
              (item) => {
                'name': item['name'] ?? '',
                'quantity': (item['quantity'] ?? 0).abs(),
                'price': item['price'] ?? 0,
                'total': (item['quantity'] ?? 0).abs() * (item['price'] ?? 0),
              },
            )
            .toList();
      } else {
        pdfItems = widget.itemsSale
            .map(
              (item) => {
                'name': item['name'] ?? '',
                'quantity': (item['quantity'] ?? 0).abs(),
                'price': item['price'] ?? 0,
                'total': (item['quantity'] ?? 0).abs() * (item['price'] ?? 0),
              },
            )
            .toList();
      }
      if (thermalInvoice == true) {
        final pdfBytes = await ThermalPrinterService.generateThermalPdf(
          invoiceType: widget.type,
          invoiceNumber:
              "${_getTitleEnglish(widget.type)}-${DateTime.now().year}-${widget.state.lastInvoiceNumber + 1}",
          invoiceDate: widget.state.selectedDate,
          clientName: nameController.text,
          items: pdfItems,
          subtotal: widget.state.priceSumItems,
          discount: widget.state.discountValue,
          tax: widget.state.taxValue,
          total: widget.state.total,
          notes: notesController.text.isNotEmpty ? notesController.text : null,
          companyName: widget.state.companyName,
          isQuote: widget.type == 'عرض سعر',
        );
        await ThermalPrinterService.printThermalPdf(pdfBytes);

        // أو مشاركة
        await ThermalPrinterService.shareToThermalPrinter(
          pdfBytes,
          'فاتورة_001',
        );
      } else {
        await InvoiceGenerator.generateProfessionalInvoice(
          invoiceType: widget.type,
          invoiceNumber:
              "${_getTitleEnglish(widget.type)}-${DateTime.now().year}-${widget.state.lastInvoiceNumber + 1}",
          invoiceDate: widget.state.selectedDate,
          clientName: nameController.text,
          clientAddress: addressController.text,
          clientPhone: phoneController.text,
          items: pdfItems,
          subtotal: widget.state.priceSumItems,
          discount: widget.state.discountValue,
          tax: widget.state.taxValue,
          total: widget.state.total,
          notes: notesController.text.isNotEmpty ? notesController.text : null,
          companyName: widget.state.companyName,
          companyAddress: widget.state.companyAddress,
          companyPhone: widget.state.companyPhone,
          companyEmail: widget.state.companyEmail,
          companyLogoPath: widget.state.companyLogoPath,
          isDue: selectedPaymentMethod == 'آجل',
          isInstallment: selectedPaymentMethod == 'تقسيط',
          dueDates: widget.state.paymentScheduleData,
          showAddress: widget.state.showAddress,
          showEmail: widget.state.showEmail,
          showDiscount: widget.state.showDiscount,
          showLogo: widget.state.showLogo,
          showNotes: widget.state.showNotes,
          showPhone: widget.state.showPhone,
          showTax: widget.state.showTax,
          isQuote: widget.type == 'عرض سعر',
          originalInvoiceNumber: widget.state.originalInvoiceNumber,
        );
      }

      setState(() => widget.state.loading = false);

      // Reset controllers
      nameController.clear();
      addressController.clear();
      phoneController.clear();
      notesController.clear();
      taxController.text = '0';
      discountController.text = '0';
      widget.itemsSale.clear();
      widget.itemsPurchase.clear();
      selectedPaymentMethod = 'كاش';
      returnItems.clear();

      if (mounted) {
        Navigator.popUntil(
          context,
          ModalRoute.withName(WorkspaceHomeScreen.screenroute),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  widget.type == 'عرض سعر'
                      ? 'تم حفظ عرض السعر'
                      : 'تم حفظ الفاتورة بنجاح',
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
      setState(() => widget.state.loading = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══ SECTION 6: PAYMENTS TABLE (Refactored with proper data flow) ════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class CustomPaymentsTable extends StatefulWidget {
  final double total;
  final List<Map<String, dynamic>> paymentScheduleData;
  final List<int> paymentIndexes;
  final String? paymentMethod;
  final VoidCallback onDataChanged;

  const CustomPaymentsTable({
    super.key,
    required this.total,
    required this.paymentScheduleData,
    required this.paymentIndexes,
    required this.paymentMethod,
    required this.onDataChanged,
  });

  @override
  State<CustomPaymentsTable> createState() => _CustomPaymentsTableState();
}

class _CustomPaymentsTableState extends State<CustomPaymentsTable> {
  String formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void editValue(int index) {
    final controller = TextEditingController(
      text: widget.paymentScheduleData[index]['value'].toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "تعديل القيمة",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'المبلغ'),
            onTap: () {
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            },
            validator: (value) {
              final parsed = double.tryParse(value ?? '0') ?? 0;
              if (parsed >= widget.total) {
                return 'المبلغ يجب أن يكون أقل من الإجمالي';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                setState(() {
                  final value = double.tryParse(controller.text) ?? 0;
                  widget.paymentScheduleData[index]['value'] = value;
                  widget.paymentScheduleData[index]['valuePicked'] = true;

                  // Auto-calculate remaining
                  double sum = widget.paymentScheduleData
                      .take(index + 1)
                      .fold(
                        0.0,
                        (sum, item) => sum + (item['value'] as num).toDouble(),
                      );
                  double remaining = widget.total - sum;

                  if (remaining > 0 &&
                      index < widget.paymentScheduleData.length - 1) {
                    for (
                      int i = index + 1;
                      i < widget.paymentScheduleData.length;
                      i++
                    ) {
                      widget.paymentScheduleData[i]['value'] =
                          remaining /
                          (widget.paymentScheduleData.length - index - 1);
                      widget.paymentScheduleData[i]['valuePicked'] = true;
                    }
                  }
                });
                widget.onDataChanged();
                Navigator.pop(context);
              }
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }

  Future<void> pickDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.paymentScheduleData[index]['date'] as DateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        widget.paymentScheduleData[index]['date'] = picked;
        widget.paymentScheduleData[index]['datePicked'] = true;
      });

      if (widget.paymentScheduleData[0]['datePicked'] == true) {
        final otherIndexes = widget.paymentIndexes
            .where((item) => item != 0)
            .toList();
        for (var i in otherIndexes) {
          setState(() {
            widget.paymentScheduleData[i]['datePicked'] = true;
          });
        }
      }
      widget.onDataChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'النوع',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'القيمة',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'التاريخ',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'الحالة',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Rows
              ...List.generate(widget.paymentScheduleData.length, (index) {
                final item = widget.paymentScheduleData[index];
                return Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            item['type'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => editValue(index),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            color: item['valuePicked']
                                ? Colors.transparent
                                : AppColors.primary.withOpacity(0.05),
                            child: Text(
                              item['valuePicked']
                                  ? (item['value'] as double).toStringAsFixed(2)
                                  : 'تعديل',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: item['valuePicked']
                                    ? AppColors.textPrimary
                                    : AppColors.primary,
                                fontWeight: item['valuePicked']
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => pickDate(index),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            color: item['datePicked']
                                ? Colors.transparent
                                : AppColors.primary.withOpacity(0.05),
                            child: Text(
                              item['datePicked']
                                  ? formatDate(item['date'] as DateTime)
                                  : 'تعديل',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: item['datePicked']
                                    ? AppColors.textPrimary
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            item['status'] == 'تم'
                                ? Icons.check_circle
                                : Icons.pending,
                            color: item['status'] == 'تم'
                                ? AppColors.success
                                : AppColors.warning,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        if (widget.paymentMethod == 'تقسيط')
          TextButton(
            onPressed: () {
              setState(() {
                widget.paymentScheduleData.add({
                  "type": 'قسط ${widget.paymentScheduleData.length}',
                  "value": 0.0,
                  "valuePicked": false,
                  "date": DateTime.now().add(
                    Duration(days: 30 * (widget.paymentScheduleData.length)),
                  ),
                  'datePicked': false,
                  "status": "!",
                });
              });
              widget.paymentIndexes.add(widget.paymentIndexes.length);
              widget.onDataChanged();
            },
            child: const Text('إضافة قسط'),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══ SECTION 7: PDF GENERATOR (Corrected & Optimized) ════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class PdfTheme {
  const PdfTheme._();

  static const PdfColor primary = PdfColor.fromInt(0xFF2563EB);
  static const PdfColor primaryDark = PdfColor.fromInt(0xFF1D4ED8);
  static const PdfColor success = PdfColor.fromInt(0xFF10B981);
  static const PdfColor warning = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor danger = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor info = PdfColor.fromInt(0xFF0EA5E9);
  static const PdfColor textPrimary = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textSecondary = PdfColor.fromInt(0xFF64748B);
  static const PdfColor background = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor surface = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor border = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor headerBg = PdfColor.fromInt(0xFF1E293B);
}

class InvoiceTypeStyle {
  final String titleAr;
  final String titleEn;
  final PdfColor primaryColor;
  final PdfColor lightColor;
  final String badgeText;

  const InvoiceTypeStyle({
    required this.titleAr,
    required this.titleEn,
    required this.primaryColor,
    required this.lightColor,
    required this.badgeText,
  });
}

class InvoiceTypeStyles {
  const InvoiceTypeStyles._();

  static final Map<String, InvoiceTypeStyle> _styles = {
    'بيع': InvoiceTypeStyle(
      titleAr: 'فاتورة بيع',
      titleEn: 'SALE INVOICE',
      primaryColor: PdfTheme.success,
      lightColor: const PdfColor.fromInt(0xFFD1FAE5),
      badgeText: 'SALE',
    ),
    'شراء': InvoiceTypeStyle(
      titleAr: 'فاتورة شراء',
      titleEn: 'PURCHASE INVOICE',
      primaryColor: PdfTheme.primary,
      lightColor: const PdfColor.fromInt(0xFFDBEAFE),
      badgeText: 'PURCHASE',
    ),
    'صيانة': InvoiceTypeStyle(
      titleAr: 'فاتورة صيانة',
      titleEn: 'MAINTENANCE INVOICE',
      primaryColor: PdfTheme.warning,
      lightColor: const PdfColor.fromInt(0xFFFEF3C7),
      badgeText: 'MAINTENANCE',
    ),
    'مرتجع': InvoiceTypeStyle(
      titleAr: 'فاتورة مرتجع',
      titleEn: 'RETURN INVOICE',
      primaryColor: PdfTheme.danger,
      lightColor: const PdfColor.fromInt(0xFFFEE2E2),
      badgeText: 'RETURN',
    ),
    'عرض سعر': InvoiceTypeStyle(
      titleAr: 'عرض سعر',
      titleEn: 'QUOTATION',
      primaryColor: PdfTheme.info,
      lightColor: const PdfColor.fromInt(0xFFE0F2FE),
      badgeText: 'QUOTE',
    ),
  };

  static InvoiceTypeStyle get(String type) {
    return _styles[type] ?? _styles['بيع']!;
  }
}

// Helper widget for bullet points
pw.Widget _pdfBullet(PdfColor color, {double size = 8}) {
  return pw.Container(
    width: size,
    height: size,
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: pw.BorderRadius.circular(size / 2),
    ),
  );
}

// Helper widget for small labels
pw.Widget _pdfIconLabel(String label, PdfColor color, {double fontSize = 8}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(
      label,
      style: pw.TextStyle(
        fontSize: fontSize,
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

class InvoiceGenerator {
  const InvoiceGenerator._();

  static Future<Uint8List> generateProfessionalInvoice({
    required String invoiceType,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String clientName,
    required String clientAddress,
    required String clientPhone,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    required bool isDue,
    required bool isInstallment,
    List<Map<String, dynamic>>? dueDates,
    String? notes,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String? companyLogoPath,
    bool? showLogo,
    bool? showAddress,
    bool? showPhone,
    bool? showEmail,
    bool? showNotes,
    bool? showTax,
    bool? showDiscount,
    bool isQuote = false,
    String? originalInvoiceNumber,
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    // Load logo
    pw.MemoryImage? logoImage;
    if (companyLogoPath != null && File(companyLogoPath).existsSync()) {
      final bytes = await File(companyLogoPath).readAsBytes();
      logoImage = pw.MemoryImage(bytes);
    }

    // Get invoice style based on type
    final style = InvoiceTypeStyles.get(invoiceType);

    // Pre-calculate values
    final formattedDate =
        '${invoiceDate.year}-${invoiceDate.month.toString().padLeft(2, '0')}-${invoiceDate.day.toString().padLeft(2, '0')}';

    String paymentStatus;
    PdfColor paymentColor;
    if (isQuote) {
      paymentStatus = 'عرض سعر';
      paymentColor = PdfTheme.info;
    } else if (isInstallment) {
      paymentStatus = 'تقسيط';
      paymentColor = PdfTheme.warning;
    } else if (isDue) {
      paymentStatus = 'آجل';
      paymentColor = PdfTheme.warning;
    } else {
      paymentStatus = 'مدفوع';
      paymentColor = PdfTheme.success;
    }

    String clientLabel;
    if (invoiceType == 'شراء') {
      clientLabel = 'المورد';
    } else {
      clientLabel = 'العميل';
    }

    String footerText;
    if (isQuote) {
      footerText = 'عرض سعر صالح لمدة 15 يوماً';
    } else if (invoiceType == 'مرتجع') {
      footerText = 'فاتورة مرتجعة - يتم إعادة الكميات للمخزون';
    } else {
      footerText = 'فاتورة إلكترونية - لا تحتاج توقيعاً';
    }

    // Table setup
    List<String> headers;
    Map<int, pw.Alignment> cellAlignments;
    List<List<dynamic>> tableData;

    if (invoiceType == 'صيانة') {
      headers = ['الإجمالي', 'السعر', 'البند'];
      cellAlignments = {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
      };
    } else {
      headers = ['الإجمالي', 'السعر', 'الكمية', 'الوصف'];
      cellAlignments = {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
      };
    }

    tableData = items.map((item) {
      final qty = (item['quantity'] ?? 0) as num;
      final price = (item['price'] ?? 0) as num;
      final itemTotal = qty * price;

      if (invoiceType == 'صيانة') {
        return [
          itemTotal.toStringAsFixed(2),
          price.toStringAsFixed(2),
          item['name']?.toString() ?? '',
        ];
      }
      return [
        itemTotal.toStringAsFixed(2),
        price.toStringAsFixed(2),
        qty.toString(),
        item['name']?.toString() ?? '',
      ];
    }).toList();

    // Helper function for consistent text styling
    pw.TextStyle _textStyle({
      double fontSize = 10,
      PdfColor color = PdfTheme.textPrimary,
      pw.FontWeight fontWeight = pw.FontWeight.normal,
    }) {
      return pw.TextStyle(
        font: arabicFont,
        fontBold: arabicFontBold,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
    }

    pw.Widget _summaryRow(
      String label,
      double value, {
      bool isTotal = false,
      bool isDiscount = false,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: _textStyle(
                fontSize: isTotal ? 10 : 9,
                color: isTotal ? PdfTheme.textPrimary : PdfTheme.textSecondary,
                fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              value.toStringAsFixed(2),
              style: _textStyle(
                fontSize: isTotal ? 12 : 10,
                color: isDiscount
                    ? PdfTheme.danger
                    : (isTotal ? style.primaryColor : PdfTheme.textPrimary),
                fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    // ==================== BUILD PDF ====================
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
          buildBackground: isQuote
              ? (context) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Watermark(
                    angle: 0.5,
                    child: pw.Opacity(
                      opacity: 0.06,
                      child: pw.Text(
                        'QUOTATION',
                        style: pw.TextStyle(
                          fontSize: 70,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfTheme.info,
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ═══ HEADER + BADGE + META ═══
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfTheme.headerBg,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(12),
                      topRight: pw.Radius.circular(12),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Invoice type badge
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: pw.BoxDecoration(
                          color: style.primaryColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              style.titleAr,
                              style: _textStyle(
                                fontSize: 14,
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              style.titleEn,
                              style: _textStyle(
                                fontSize: 8,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      // Company info
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              companyName ?? 'اسم الشركة',
                              style: _textStyle(
                                fontSize: 18,
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Wrap(
                              spacing: 12,
                              children: [
                                if (companyPhone != null && showPhone != false)
                                  pw.Text(
                                    companyPhone,
                                    style: _textStyle(
                                      fontSize: 8,
                                      color: PdfColors.grey400,
                                    ),
                                  ),
                                if (companyAddress != null &&
                                    showAddress != false)
                                  pw.Text(
                                    companyAddress,
                                    style: _textStyle(
                                      fontSize: 8,
                                      color: PdfColors.grey400,
                                    ),
                                  ),
                                if (companyEmail != null && showEmail != false)
                                  pw.Text(
                                    companyEmail,
                                    style: _textStyle(
                                      fontSize: 8,
                                      color: PdfColors.grey400,
                                    ),
                                  ),
                              ],
                            ),
                            pw.SizedBox(height: 6),
                            pw.Row(
                              children: [
                                if (!isQuote && invoiceType != 'مرتجع')
                                  pw.Text(
                                    'رقم: $invoiceNumber',
                                    style: _textStyle(
                                      fontSize: 9,
                                      color: PdfColors.white,
                                    ),
                                  ),
                                pw.SizedBox(width: 12),
                                if (!isQuote && invoiceType != 'مرتجع')
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: pw.BoxDecoration(
                                      color: paymentColor,
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Text(
                                      paymentStatus,
                                      style: _textStyle(
                                        fontSize: 8,
                                        color: PdfColors.white,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Logo
                      if (logoImage != null && showLogo != false)
                        pw.Column(
                          children: [
                            pw.Container(
                              width: 50,
                              height: 50,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                borderRadius: pw.BorderRadius.circular(8),
                                border: pw.Border.all(
                                  color: PdfTheme.border,
                                  width: 0.5,
                                ),
                              ),
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Image(logoImage, fit: pw.BoxFit.fill),
                            ),
                            pw.Text(
                              'التاريخ: $formattedDate',
                              style: _textStyle(
                                fontSize: 9,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // ═══ CLIENT SECTION ═══
                if (clientName.isNotEmpty)
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfTheme.border, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: pw.BoxDecoration(
                            color: style.lightColor,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            clientLabel,
                            style: _textStyle(
                              fontSize: 9,
                              color: style.primaryColor,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Text(
                          clientName,
                          style: _textStyle(
                            fontSize: 13,
                            color: PdfTheme.textPrimary,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Wrap(
                            spacing: 8,
                            children: [
                              if (clientAddress.isNotEmpty)
                                pw.Text(
                                  clientAddress,
                                  style: _textStyle(
                                    fontSize: 8,
                                    color: PdfTheme.textSecondary,
                                  ),
                                ),
                              if (clientPhone.isNotEmpty)
                                pw.Text(
                                  clientPhone,
                                  style: _textStyle(
                                    fontSize: 8,
                                    color: PdfTheme.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (originalInvoiceNumber != null)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfTheme.danger,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              'مرتجع من: $originalInvoiceNumber',
                              style: _textStyle(
                                fontSize: 8,
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                pw.SizedBox(height: 12),

                // ═══ ITEMS TABLE ═══
                pw.TableHelper.fromTextArray(
                  headers: headers,
                  headerStyle: _textStyle(
                    fontSize: 10,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: style.primaryColor,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(8),
                      topRight: pw.Radius.circular(8),
                    ),
                  ),
                  headerHeight: 28,
                  cellHeight: 32,
                  cellStyle: _textStyle(
                    fontSize: 9,
                    color: PdfTheme.textPrimary,
                  ),
                  cellAlignments: cellAlignments,
                  oddRowDecoration: const pw.BoxDecoration(
                    color: PdfTheme.background,
                  ),
                  border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(
                      color: PdfTheme.border,
                      width: 0.5,
                    ),
                  ),
                  data: tableData,
                ),
                pw.SizedBox(height: 12),

                // ═══ SUMMARY ═══
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfTheme.background,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfTheme.border, width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'الملخص',
                          style: _textStyle(
                            fontSize: 10,
                            color: PdfTheme.textSecondary,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        _summaryRow('المجموع:', subtotal),
                        if (showDiscount != false && discount > 0)
                          _summaryRow('الخصم:', discount, isDiscount: true),
                        if (showTax != false && tax > 0)
                          _summaryRow('الضريبة:', tax),
                        pw.Divider(
                          color: PdfTheme.border,
                          height: 10,
                          thickness: 0.5,
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            color: style.lightColor,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: _summaryRow('الإجمالي:', total, isTotal: true),
                        ),
                      ],
                    ),
                  ),
                ),

                // Payment schedule
                if (dueDates != null &&
                    dueDates.isNotEmpty &&
                    (isDue || isInstallment) &&
                    !isQuote)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: pw.BoxDecoration(
                          color: style.lightColor,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'المدفوعات',
                          style: _textStyle(
                            fontSize: 9,
                            color: style.primaryColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.TableHelper.fromTextArray(
                        headers: ['الحالة', 'التاريخ', 'القيمة', 'النوع'],
                        headerStyle: _textStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        headerDecoration: const pw.BoxDecoration(
                          color: PdfTheme.headerBg,
                        ),
                        headerHeight: 24,
                        cellHeight: 26,
                        headerAlignments: {
                          0: pw.Alignment.center,
                          1: pw.Alignment.center,
                          2: pw.Alignment.center,
                          3: pw.Alignment.center,
                        },
                        cellAlignment: pw.Alignment.center,
                        cellStyle: _textStyle(
                          fontSize: 8,
                          color: PdfTheme.textPrimary,
                        ),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(0.8),
                          1: const pw.FlexColumnWidth(1.2),
                          2: const pw.FlexColumnWidth(1),
                          3: const pw.FlexColumnWidth(1),
                        },
                        border: pw.TableBorder(
                          horizontalInside: pw.BorderSide(
                            color: PdfTheme.border,
                            width: 0.5,
                          ),
                        ),
                        data: dueDates.map((item) {
                          final date = item['date'] is DateTime
                              ? item['date'] as DateTime
                              : DateTime.parse(item['date'].toString());
                          final status = item['status']?.toString() ?? '';
                          final isPaid = status == 'تم';
                          return [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: pw.BoxDecoration(
                                color: isPaid
                                    ? PdfTheme.success
                                    : PdfTheme.warning,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                status,
                                style: _textStyle(
                                  fontSize: 8,
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                            '${(item['value'] ?? 0.0).toStringAsFixed(2)}',
                            item['type']?.toString() ?? '',
                          ];
                        }).toList(),
                      ),
                    ],
                  ),

                // Notes
                if (notes != null && notes.isNotEmpty && showNotes != false)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 12),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfTheme.background,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(
                            color: PdfTheme.border,
                            width: 1,
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'ملاحظات',
                              style: _textStyle(
                                fontSize: 10,
                                color: PdfTheme.textSecondary,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              notes,
                              style: _textStyle(
                                fontSize: 9,
                                color: PdfTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                // ═══ FOOTER ═══
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 16),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfTheme.background,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'شكراً لتعاملكم معنا',
                              style: _textStyle(
                                fontSize: 10,
                                color: PdfTheme.textPrimary,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              footerText,
                              style: _textStyle(
                                fontSize: 7,
                                color: PdfTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: invoiceNumber,
                        width: 40,
                        height: 40,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    // Print
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${isQuote ? 'عرض_سعر' : 'فاتورة'}_$invoiceNumber.pdf',
    );

    // Share
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${isQuote ? 'عرض_سعر' : 'فاتورة'}_$invoiceNumber.pdf',
    );

    return bytes;
  }
}

class ThermalPrinterService {
  // ═══════════════════════════════════════════════════
  // Generate thermal PDF - FIXED
  // ═══════════════════════════════════════════════════
  static Future<Uint8List> generateThermalPdf({
    required String invoiceType,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String clientName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    String? companyName,
    String? notes,
    bool isQuote = false,
  }) async {
    final pdf = pw.Document();

    // ═══ FIXED: 80mm thermal roll width ═══
    // 80mm = 226.77 points (72 dpi)
    final rollWidth = 80.0 * 72.0 / 25.4;

    // ═══ FIXED: Load Arabic font with fallback ═══
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    final formattedDate =
        '${invoiceDate.year}-${invoiceDate.month.toString().padLeft(2, '0')}-${invoiceDate.day.toString().padLeft(2, '0')}';

    String paymentStatus = isQuote ? 'عرض سعر' : 'مدفوع';

    // Helper for text style
    pw.TextStyle _style({
      double fontSize = 10,
      PdfColor color = PdfColors.black,
      pw.FontWeight weight = pw.FontWeight.normal,
    }) {
      return pw.TextStyle(
        font: arabicFont,
        fontBold: arabicFontBold,
        fontSize: fontSize,
        color: color,
        fontWeight: weight,
      );
    }

    pdf.addPage(
      pw.Page(
        // ═══ FIXED: Roll paper format ═══
        pageFormat: PdfPageFormat(rollWidth, double.infinity),
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        build: (context) {
          // ═══ FIXED: RTL Directionality ═══
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              // ═══ FIXED: Cross axis start (right alignment) ═══
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ═══ HEADER ═══
                pw.Center(
                  child: pw.Text(
                    companyName ?? 'اسم الشركة',
                    style: _style(fontSize: 16, weight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    '$invoiceType - $paymentStatus',
                    style: _style(fontSize: 12, weight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'رقم: $invoiceNumber',
                    style: _style(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'التاريخ: $formattedDate',
                    style: _style(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),

                // ═══ CLIENT - FIXED: Right aligned ═══
                if (clientName.isNotEmpty) ...[
                  pw.Text(
                    'العميل: $clientName',
                    style: _style(fontSize: 10),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 8),
                ],

                // ═══ ITEMS TABLE - FIXED: Better layout for thermal ═══
                // بدل Table نستخدم Column عشان التحكم أفضل
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final qty = (item['quantity'] ?? 0) as num;
                  final price = (item['price'] ?? 0) as num;
                  final itemTotal = qty * price;
                  final name = item['name']?.toString() ?? '';

                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: index < items.length - 1
                              ? PdfColors.grey400
                              : PdfColors.black,
                          width: index < items.length - 1 ? 0.5 : 1,
                        ),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Name on top
                        pw.Text(
                          name,
                          style: _style(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                        pw.SizedBox(height: 2),
                        // Qty, Price, Total in row
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '${qty.toString()} × ${price.toStringAsFixed(2)}',
                              style: _style(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              itemTotal.toStringAsFixed(2),
                              style: _style(
                                fontSize: 10,
                                weight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),

                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),

                // ═══ SUMMARY - FIXED: Right aligned ═══
                _summaryRow('المجموع:', subtotal, _style),
                if (discount > 0)
                  _summaryRow(
                    'الخصم:',
                    -discount,
                    _style,
                    color: PdfColors.red,
                  ),
                if (tax > 0) _summaryRow('الضريبة:', tax, _style),

                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),

                // Total bold
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'الإجمالي:',
                      style: _style(fontSize: 12, weight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      total.toStringAsFixed(2),
                      style: _style(fontSize: 12, weight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),

                // ═══ NOTES ═══
                if (notes != null && notes.isNotEmpty) ...[
                  pw.Divider(thickness: 0.5),
                  pw.Text(
                    'ملاحظات:',
                    style: _style(fontSize: 9, weight: pw.FontWeight.bold),
                  ),
                  pw.Text(notes, style: _style(fontSize: 8)),
                  pw.SizedBox(height: 8),
                ],

                // ═══ FOOTER ═══
                pw.Divider(thickness: 1),
                pw.Center(
                  child: pw.Text(
                    'شكراً لتعاملكم معنا',
                    style: _style(fontSize: 11, weight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: invoiceNumber,
                    width: 50,
                    height: 50,
                  ),
                ),
                // ═══ FIXED: Feed for cutting ═══
                pw.SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  // ═══ FIXED: Summary row with proper RTL ═══
  static pw.Widget _summaryRow(
    String label,
    double value,
    pw.TextStyle Function({
      double fontSize,
      PdfColor color,
      pw.FontWeight weight,
    })
    style, {
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Label first (right side in RTL)
          pw.Text(label, style: style(fontSize: 10)),
          // Value second (left side in RTL)
          pw.Text(
            value.abs().toStringAsFixed(2),
            style: style(fontSize: 10, color: color ?? PdfColors.black),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Print Methods
  // ═══════════════════════════════════════════════════

  static Future<void> printThermalPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'thermal_invoice.pdf',
    );
  }

  static Future<void> directPrintThermal({
    required Uint8List pdfBytes,
    String? printerUrl,
  }) async {
    Printer? selectedPrinter;

    if (printerUrl != null) {
      final printers = await Printing.listPrinters();
      selectedPrinter = printers.firstWhere(
        (p) => p.url == printerUrl,
        orElse: () => throw Exception('Printer not found: $printerUrl'),
      );
    }

    await Printing.directPrintPdf(
      printer: selectedPrinter!,
      onLayout: (PdfPageFormat format) async => pdfBytes,
      format: PdfPageFormat(80 * 72 / 25.4, double.infinity),
    );
  }

  static Future<void> shareToThermalPrinter(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: '$fileName.pdf');
  }
}
