import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintenance/addAwarehouseItem.dart';
import 'package:maintenance/customersSuppliers.dart';
import 'package:maintenance/invoiceSettings.dart';
import 'package:maintenance/warehouseScreen.dart';
import 'package:maintenance/workSpace.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool loading = false;
bool reCalculate = false;

List<Map<String, dynamic>> data = [
  {
    "type": "مدفوع",
    "value": 0.0,
    'valuePicked': false,
    "date": DateTime.now(),
    'datePicked': false,
    "status": "تم",
  },
  {
    "type": selectedPaymentMethod == 'آجل' ? "مستحق" : 'قسط 1',
    "value": 0.0,
    "valuePicked": false,
    "date": DateTime.now().add(const Duration(days: 30)),
    'datePicked': false,
    "status": "!",
  },
];
List indexes = [0, 1];

// ==================== CONSTANTS & THEME ====================

class AppColors {
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

// ==================== MODELS ====================

class InvoiceType {
  final String title;
  final String type;
  final String titleEnglish;
  final IconData icon;
  final Color color;

  const InvoiceType({
    required this.title,
    required this.type,
    required this.titleEnglish,
    required this.icon,
    required this.color,
  });
}

// ==================== GLOBAL STATE (Refactored) ====================

class InvoiceState {
  static DateTime selectedDate = DateTime.now();
  late int lastInvoiceNumber = 0;
  double priceSumItems = 0.0;
  late double discountValue = 0.0;
  late double taxValue = 0.14;
  late double total = 0.0;
  String? companyName;
  String? companyAddress;
  String? companyPhone;
  String? companyEmail;
  String? companyLogoPath;
  double? amountPaid;
  double? amountDue;
  late bool showLogo = true;
  late bool showAddress = true;
  late bool showPhone = true;
  late bool showEmail = true;
  late bool showNotes = true;
  late bool showTax = true;
  late bool showDiscount = true;
}

// ==================== MAIN PAGE ====================

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

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String selectedFilter = 'بيع';

  final List<InvoiceType> invoiceTypes = [
    const InvoiceType(
      title: 'فاتورة بيع',
      type: 'بيع',
      titleEnglish: 'sale',
      icon: Icons.shopping_cart_outlined,
      color: AppColors.success,
    ),
    const InvoiceType(
      title: 'فاتورة شراء',
      type: 'شراء',
      titleEnglish: 'purchase',
      icon: Icons.shopping_bag_outlined,
      color: AppColors.primary,
    ),
    const InvoiceType(
      title: 'فاتورة صيانة',
      type: 'صيانة',
      titleEnglish: 'maintenance',
      icon: Icons.build_outlined,
      color: AppColors.warning,
    ),
    const InvoiceType(
      title: 'مرتجع',
      type: 'مرتجع',
      titleEnglish: 'return',
      icon: Icons.assignment_return_outlined,
      color: AppColors.danger,
    ),
    const InvoiceType(
      title: 'عرض سعر',
      type: 'عرض سعر',
      titleEnglish: 'quote',
      icon: Icons.description_outlined,
      color: AppColors.secondary,
    ),
  ];

  InvoiceState state = InvoiceState();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      setState(() {
        taxController.text = state.showTax ? '14' : '0';
        discountController.text =
            state.showDiscount && discountController.text.isNotEmpty
            ? discountController.text
            : '0';
      });
      if (widget.isFromWorkSpace) {
        setState(() {
          reCalculate = false;
        });
      } else {
        setState(() {
          reCalculate = true;
        });
      }

      final prefs = await SharedPreferences.getInstance();
      state.companyLogoPath = prefs.getString('logoPath${widget.groupId}');
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = invoiceTypes.firstWhere(
      (t) => t.type == selectedFilter,
    );

    return WillPopScope(
      onWillPop: () async {
        loading = false;
        nameController.clear();
        addressController.clear();
        phoneController.clear();
        notesController.clear();
        taxController.text = '14';
        discountController.text = '0';
        widget.itemsSale.clear();
        selectedPaymentMethod = 'كاش';
        Navigator.popUntil(
          context,
          ModalRoute.withName(WorkspaceHomeScreen.screenroute),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('تسجيل فاتورة جديدة'),
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
                      items: widget.itemsSale,
                      customerId: widget.customerId,
                    ),
                  ),
                );

                if (result == true) {
                  _loadSettings(); // 🔥 اعمل reload
                }
              },
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Filter Chips
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                        side: BorderSide(
                          color: isSelected ? type.color : AppColors.border,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedFilter = type.type;
                            nameController.clear();
                            addressController.clear();
                            phoneController.clear();
                            notesController.clear();
                            print(selectedFilter);

                            if (selectedFilter != 'بيع') {
                              widget.itemsSale.clear();
                            }
                            if (selectedFilter != 'شراء') {
                              widget.itemsPurchase.clear();
                            }

                            selectedPaymentMethod = 'كاش';
                          });
                          _animationController.forward(from: 0);
                          setState(() {
                            reCalculate = true;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),

            // Invoice Content
            Expanded(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: Tween<double>(begin: 0.8, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: child,
                  );
                },
                child: InvoicePageDesign(
                  type: selectedFilter,
                  groupId: widget.groupId,
                  itemsSale: widget.itemsSale,
                  itemsPurchase: [],
                  name: widget.name,
                  phone: widget.phone,
                  address: widget.address,
                  customerId: widget.customerId,
                  isFromConstCustomers: widget.isFromConstCustomers,
                  state: state,
                  invoiceType: selectedType,
                  reCalculate: reCalculate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== INVOICE DESIGN ====================

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
  final InvoiceType invoiceType;
  final bool reCalculate;

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
    required this.reCalculate,
    required this.itemsPurchase,
  });

  @override
  State<InvoicePageDesign> createState() => _InvoicePageDesignState();
}

InvoiceState state = InvoiceState();
TextEditingController nameController = TextEditingController();
TextEditingController addressController = TextEditingController();
TextEditingController phoneController = TextEditingController();
TextEditingController notesController = TextEditingController();
TextEditingController taxController = TextEditingController(
  //  text: state.showTax ? '14' : '0',
);
TextEditingController discountController = TextEditingController(
  // text: state.showDiscount ? discountController.text : '0',
);
String? selectedPaymentMethod = 'كاش';

class _InvoicePageDesignState extends State<InvoicePageDesign> {
  final List<String> paymentMethods = ['كاش', 'آجل', 'تقسيط'];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.isFromConstCustomers ? widget.name : nameController.text,
    );
    addressController = TextEditingController(
      text: widget.isFromConstCustomers
          ? widget.address
          : addressController.text,
    );
    phoneController = TextEditingController(
      text: widget.isFromConstCustomers ? widget.phone : phoneController.text,
    );
    notesController = TextEditingController();
    discountController = TextEditingController(
      text: !state.showDiscount
          ? '0'
          : discountController.text.isNotEmpty
          ? discountController.text
          : '0',
    );
    taxController = TextEditingController(
      text: !state.showTax
          ? '0'
          : taxController.text.isNotEmpty
          ? taxController.text
          : '14',
    );

    _calculateTotals();
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    notesController.dispose();
    taxController.dispose();
    discountController.dispose();
    super.dispose();
  }

  void _calculateTotals() {
    setState(() {
      widget.state.priceSumItems = widget.itemsSale.isEmpty
          ? 0.0
          : widget.itemsSale.fold(
              0.0,
              (sum, item) =>
                  sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1)),
            );

      final discountPercent = double.tryParse(discountController.text) ?? 0;
      widget.state.discountValue =
          widget.state.priceSumItems * discountPercent / 100;

      final taxPercent = double.tryParse(taxController.text) ?? 0;
      widget.state.taxValue = widget.state.priceSumItems * taxPercent / 100;

      widget.state.total =
          widget.state.priceSumItems +
          widget.state.taxValue -
          widget.state.discountValue;
    });
  }

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
        content: const Text('هل أنت متأكد من إعادة تعين جميع بيانات الفاتورة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                data = [
                  {
                    "type": "مدفوع",
                    "value": 0.0,
                    'valuePicked': false,
                    "date": DateTime.now(),
                    'datePicked': false,
                    "status": "تم",
                  },
                  {
                    "type": selectedPaymentMethod == 'آجل' ? "مستحق" : 'قسط 1',
                    "value": 0.0,
                    "valuePicked": false,
                    "date": DateTime.now().add(const Duration(days: 30)),
                    'datePicked': false,
                    "status": "!",
                  },
                ];
              });
              nameController.clear();
              addressController.clear();
              phoneController.clear();
              notesController.clear();
              taxController.text = widget.state.showTax ? '14' : '0';
              discountController.text = '0';
              widget.itemsSale.clear();
              selectedPaymentMethod = 'كاش';
              indexes = [0, 1];
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

  Map<String, dynamic> buildInvoiceData() {
    return {
      "groupId": widget.groupId,
      "type": widget.type,
      "titleEnglish": _getTitleEnglish(widget.type),
      "customer": {
        "id": widget.customerId.isNotEmpty ? widget.customerId : null,
        "name": nameController.text.isNotEmpty ? nameController.text : null,
        "phone": phoneController.text.isNotEmpty ? phoneController.text : null,
        "address": addressController.text.isNotEmpty
            ? addressController.text
            : null,
      },
      "items": widget.itemsSale
          .map(
            (item) => {
              "name": item['name'],
              "quantity": item['quantity'] ?? 0,
              "price": item['price'] ?? 0,
              "total": (item['quantity'] ?? 0) * (item['price'] ?? 0),
            },
          )
          .toList(),
      "summary": {
        "subTotal": widget.state.priceSumItems,
        "discountPercent": double.tryParse(discountController.text) ?? 0,
        "discountValue": widget.state.discountValue,
        "taxPercent": double.tryParse(taxController.text) ?? 0,
        "taxValue": widget.state.taxValue,
        "total": widget.state.total,
      },
      "notes": notesController.text.isNotEmpty ? notesController.text : null,
      "date": InvoiceState.selectedDate.toIso8601String(),
      "invoiceNumber":
          "${_getTitleEnglish(widget.type)}-${DateTime.now().year}-${widget.state.lastInvoiceNumber + 1}",
      "createdAt": DateTime.now().toIso8601String(),
    };
  }

  Future<void> saveInvoice() async {
    final data = buildInvoiceData();
    await FirebaseFirestore.instance
        .collection('invoices')
        .doc(widget.groupId)
        .collection('items')
        .add(data);
  }

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

  @override
  Widget build(BuildContext context) {
    return loading
        ? Center(
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          )
        : Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Main Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          _buildHeader(),
                          const SizedBox(height: 20),

                          // Invoice Info
                          _buildInvoiceInfo(),
                          const Divider(height: 32),

                          // Payment Method
                          if (widget.type == 'بيع' || widget.type == 'شراء')
                            _buildPaymentMethod(),

                          // Customer Section
                          _buildCustomerSection(),
                          const Divider(height: 32),

                          // Items Section
                          _buildItemsSection(),
                          const Divider(height: 32),

                          // Totals
                          _buildTotalsSection(),
                          const Divider(height: 32),

                          // Due Payments (if applicable)
                          if (selectedPaymentMethod == 'آجل' ||
                              selectedPaymentMethod == 'تقسيط') ...[
                            _buildDuePaymentsSection(),
                            const SizedBox(height: 20),
                          ],

                          // Notes
                          _buildNotesSection(),
                          const SizedBox(height: 24),

                          // Save Button
                          _buildSaveButton(widget.state.total),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
  }

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
                widget.invoiceType.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '#${_getTitleEnglish(widget.type)}-${DateTime.now().year}-${widget.state.lastInvoiceNumber + 1}',
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
        '${InvoiceState.selectedDate.year}-${InvoiceState.selectedDate.month.toString().padLeft(2, '0')}-${InvoiceState.selectedDate.day.toString().padLeft(2, '0')}';

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
                  initialDate: InvoiceState.selectedDate,
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
                  setState(() {
                    InvoiceState.selectedDate = picked;
                  });
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
                    indexes = [0, 1];
                    selectedPaymentMethod = method;
                    data = [
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
                    print(selectedPaymentMethod);

                    print(data);
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
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => CustomersSuppliers(
                      groupId: widget.groupId,
                      items: widget.itemsSale.isEmpty ? [] : widget.itemsSale,
                      isFromInvoice: true,
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
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: phoneController,
          label: 'رقم الهاتف',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: addressController,
          label: 'العنوان',
          icon: Icons.location_on_outlined,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      onChanged: (value) => onChanged?.call(value),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'الأصناف',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${widget.itemsSale.length} صنف',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (widget.itemsSale.isEmpty)
          _buildEmptyItemsState()
        else
          _buildItemsList(),

        const SizedBox(height: 12),
        _buildAddItemButton(),
      ],
    );
  }

  Widget _buildEmptyItemsState() {
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
              Icons.inventory_2_outlined,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد أصناف',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'أضف أصناف من المخزن',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemsSale.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = widget.itemsSale[index];
        final total = (item['quantity'] ?? 0) * (item['price'] ?? 0);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
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
                      item['name'] ?? 'صنف غير معروف',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${item['quantity']} × ${item['price']?.toStringAsFixed(2)}',
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddItemButton() {
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
                      ),
                    ),
                  );
                },
                btnCancelOnPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddInventoryItemScreen(groupId: widget.groupId),
                    ),
                  );
                },
              ).show();
            },
      icon: const Icon(Icons.add_circle_outline),
      label: Text(
        (widget.type == 'بيع') ? 'إختيـــار صنف من المخزن' : 'إضـــافة صنف',
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
          (!widget.state.showDiscount && !widget.state.showTax)
              ? SizedBox.shrink()
              : _buildTotalRow('المجموع الفرعي', widget.state.priceSumItems),
          const SizedBox(height: 8),
          widget.state.showDiscount
              ? _buildEditableTotalRow(
                  label: 'الخصم',
                  controller: discountController,
                  suffix: '%',
                  calculatedValue: widget.state.discountValue,
                  onEdit: () => _showEditDialog(
                    title: 'تعديل نسبة الخصم',
                    label: 'نسبة الخصم',
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    suffix: '%',
                    onSave: _calculateTotals,
                  ),
                )
              : SizedBox.shrink(),
          const SizedBox(height: 8),
          widget.state.showTax
              ? _buildEditableTotalRow(
                  label: 'الضريبة',
                  controller: taxController,
                  suffix: '%',
                  calculatedValue: widget.state.taxValue,
                  onEdit: () => _showEditDialog(
                    title: 'تعديل نسبة الضريبة',
                    label: 'نسبة الضريبة',
                    controller: taxController,
                    keyboardType: TextInputType.number,
                    suffix: '%',
                    onSave: _calculateTotals,
                  ),
                )
              : SizedBox.shrink(),
          (!widget.state.showDiscount && !widget.state.showTax)
              ? SizedBox.shrink()
              : const Padding(
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
    if (widget.reCalculate) {
      setState(() {
        _calculateTotals();

        if (isTotal) {
          value = widget.state.total;
        } else {
          value = widget.state.priceSumItems;
        }
      });
    }

    print('xxxxxxxxxxxxxxxxxxxxxxxxx${widget.state.showTax}');
    print('mmmmmmmmmmmmmmmmmmmmmmmmm${widget.state.total}');
    print('yyyyyyyyyyyyyyyyyyyyyyyyy${widget.state.taxValue}');
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

  Widget _buildEditableTotalRow({
    required String label,
    required TextEditingController controller,
    required String suffix,
    required double calculatedValue,
    required VoidCallback onEdit,
  }) {
    if (widget.reCalculate) {
      setState(() {
        controller;
      });
    }
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
        CustomPaymentsTable(total: widget.state.total),
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

  Widget _buildSaveButton(double total) {
    final isValid =
        widget.itemsSale.isNotEmpty && nameController.text.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isValid ? () => _handleSave(total) : null,
        icon: const Icon(Icons.save_outlined, color: Colors.white),
        label: const Text(
          'حفظ وطباعة الفاتورة',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          disabledBackgroundColor: AppColors.border,
        ),
      ),
    );
  }

  Future<void> _handleSave(double total) async {
    double sum = data.fold(0.0, (sum, item) => sum + item['value']);
    if (sum != total && selectedPaymentMethod != 'كاش') {
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
    try {
      setState(() {
        loading = true;
      });
      await saveInvoice();

      await InvoiceGenerator.generateProfessionalInvoice(
        invoiceType: widget.type,
        invoiceNumber:
            "${_getTitleEnglish(widget.type)}-${DateTime.now().year}-${widget.state.lastInvoiceNumber + 1}",
        invoiceDate: InvoiceState.selectedDate,
        clientName: nameController.text,
        clientAddress: addressController.text,
        clientPhone: phoneController.text,
        items: widget.itemsSale
            .map(
              (item) => {
                'name': item['name'] ?? '',
                'quantity': item['quantity'] ?? 0,
                'price': item['price'] ?? 0,
                'total': (item['quantity'] ?? 0) * (item['price'] ?? 0),
              },
            )
            .toList(),
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
        dueDates: data,
        showAddress: widget.state.showAddress,
        showEmail: widget.state.showEmail,
        showDiscount: widget.state.showDiscount,
        showLogo: widget.state.showLogo,
        showNotes: widget.state.showNotes,
        showPhone: widget.state.showPhone,
        showTax: widget.state.showTax,
      );
      setState(() {
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم حفظ الفاتورة بنجاح'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
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
      setState(() {
        loading = false;
      });
    }
    setState(() {
      loading = false;
    });
  }
}

// ==================== PAYMENTS TABLE ====================

class CustomPaymentsTable extends StatefulWidget {
  final double total;

  const CustomPaymentsTable({super.key, required this.total});

  @override
  State<CustomPaymentsTable> createState() => _CustomPaymentsTableState();
}

class _CustomPaymentsTableState extends State<CustomPaymentsTable> {
  String formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void editValue(int index) {
    final controller = TextEditingController(
      text: data[index]['value'].toString(),
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
            decoration: const InputDecoration(
              labelText: 'المبلغ',
              // suffixText: 'ج.م',
            ),
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

                  data[index]['value'] = value;
                  data[index]['valuePicked'] = true;
                  double sum = data.fold(
                    0.0,
                    (sum, item) => sum + item['value'],
                  );
                  print(sum);
                  // Auto-calculate the other row

                  List otherIndexes = indexes;
                  if (index == 0) {
                    otherIndexes = indexes.where((item) => item != 0).toList();
                    print(otherIndexes);
                    for (var i in otherIndexes) {
                      data[i]['value'] =
                          (widget.total - value) / otherIndexes.length;
                      data[i]['valuePicked'] = true;
                    }
                  } else if (index != 0 &&
                      index != indexes.last - 1 &&
                      index != indexes.last) {
                    otherIndexes = indexes
                        .where((item) => item > index)
                        .toList();
                    print(otherIndexes);
                    double newSum = 0;

                    for (int i = 0; i <= index; i++) {
                      newSum += data[i]['value'];
                    }
                    print(',,,,,,,,,,,,,,,,,,,$newSum');
                    for (var i in otherIndexes) {
                      data[i]['value'] =
                          (widget.total - newSum) / otherIndexes.length;
                      data[i]['valuePicked'] = true;
                    }
                  } else if (index != 0 && index == indexes.last - 1) {
                    double newSum = 0;

                    for (int i = 0; i <= index; i++) {
                      newSum += data[i]['value'];
                    }
                    data[indexes.last]['value'] = widget.total - newSum;
                    data[indexes.last]['valuePicked'] = true;
                  } else if (index != 0 &&
                      index == indexes.last &&
                      indexes.length == 2) {
                    data[0]['value'] = widget.total - data[1]['value'];
                    data[0]['valuePicked'] = true;
                  }

                  /* else if (index != 0) {
                    double newSum = 0;

                    for (int i = 0; i <= index; i++) {
                      newSum += data[i]['value'];
                    }
                    if (newSum > widget.total) {
                      Navigator.pop(context);
                      AwesomeDialog(
                        context: context,
                        title: 'خطأ',
                        desc: 'لا يمكن ان يكون مجموع الاقساط أكبر من الإجمالي',
                        btnOkText: 'حسنا',
                        btnOkOnPress: () {},
                      ).show();
                    }
                    return;
                  } */
                });
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
      initialDate: data[index]['date'],
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
        data[index]['date'] = picked;
        data[index]['datePicked'] = true;
      });
    }
    if (data[0]['datePicked'] = true) {
      List otherIndexes = indexes;
      otherIndexes = indexes.where((item) => item != 0).toList();
      print(otherIndexes);
      for (var i in otherIndexes) {
        setState(() {
          data[i]['datePicked'] = true;
        });
      }
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
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
              ...List.generate(data.length, (index) {
                final item = data[index];
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
                                  ? item['value'].toStringAsFixed(2)
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
                                  ? formatDate(item['date'])
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
        selectedPaymentMethod == 'تقسيط'
            ? TextButton(
                onPressed: () async {
                  setState(() {
                    data.add({
                      "type": 'قسط ${data.length}',
                      "value": 0.0,
                      "valuePicked": false,
                      // في السطر 1847 تقريباً، قم بتعديل إضافة التاريخ لتصبح هكذا:
                      "date": DateTime(
                        DateTime.now().year,
                        DateTime.now().month +
                            data.length, // زيادة عدد الأشهر بناءً على طول القائمة
                        DateTime.now().day,
                      ),

                      'datePicked': false,
                      "status": "!",
                    });
                  });
                  indexes.add(indexes.length);
                  print(indexes);
                },
                child: Text('إضافة قسط'),
              )
            : SizedBox.shrink(),
      ],
    );
  }
}

// ==================== PDF GENERATOR ====================

// ==================== PDF THEME & COLORS ====================

class PdfTheme {
  static const PdfColor primary = PdfColor.fromInt(0xFF2563EB);
  static const PdfColor primaryDark = PdfColor.fromInt(0xFF1D4ED8);
  static const PdfColor success = PdfColor.fromInt(0xFF10B981);
  static const PdfColor warning = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor danger = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor textPrimary = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textSecondary = PdfColor.fromInt(0xFF64748B);
  static const PdfColor background = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor surface = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor border = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor headerBg = PdfColor.fromInt(0xFF1E293B);
}

// ==================== INVOICE TYPE STYLING ====================

class InvoiceTypeStyle {
  final String title;
  final String titleEnglish;
  final PdfColor accentColor;
  final String iconCode;

  const InvoiceTypeStyle({
    required this.title,
    required this.titleEnglish,
    required this.accentColor,
    required this.iconCode,
  });
}

class InvoiceTypeStyles {
  static final Map<String, InvoiceTypeStyle> styles = {
    'sale': InvoiceTypeStyle(
      title: 'فاتورة بيع',
      titleEnglish: 'Sale Invoice',
      accentColor: PdfTheme.success,
      iconCode: '🛒',
    ),
    'purchase': InvoiceTypeStyle(
      title: 'فاتورة شراء',
      titleEnglish: 'Purchase Invoice',
      accentColor: PdfTheme.primary,
      iconCode: '📦',
    ),
    'maintenance': InvoiceTypeStyle(
      title: 'فاتورة صيانة',
      titleEnglish: 'Maintenance Invoice',
      accentColor: PdfTheme.warning,
      iconCode: '🔧',
    ),
    'return': InvoiceTypeStyle(
      title: 'فاتورة مرتجع',
      titleEnglish: 'Return Invoice',
      accentColor: PdfTheme.danger,
      iconCode: '↩️',
    ),
    'quote': InvoiceTypeStyle(
      title: 'عرض سعر',
      titleEnglish: 'Quotation',
      accentColor: PdfColor.fromInt(0xFF0EA5E9),
      iconCode: '📋',
    ),
  };

  static InvoiceTypeStyle get(String type) {
    return styles[type.toLowerCase()] ?? styles['sale']!;
  }
}

// ==================== ENHANCED INVOICE GENERATOR ====================

class InvoiceGenerator {
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
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();
    //  final arabicFontLight = await PdfGoogleFonts.cairoLight();

    // Load logo
    pw.MemoryImage? logoImage;
    if (companyLogoPath != null && File(companyLogoPath).existsSync()) {
      final bytes = await File(companyLogoPath).readAsBytes();
      logoImage = pw.MemoryImage(bytes);
    }

    // Get invoice style
    final style = InvoiceTypeStyles.get(invoiceType);

    // Helper widgets
    pw.Widget buildHeader() {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: PdfTheme.headerBg,
          borderRadius: const pw.BorderRadius.only(
            topLeft: pw.Radius.circular(12),
            topRight: pw.Radius.circular(12),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Company Info
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName ?? 'اسم الشركة',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  if (companyAddress != null)
                    pw.Row(
                      children: [
                        pw.Icon(
                          pw.IconData(0xe0c8),
                          size: 12,
                          color: PdfColors.grey300,
                        ),
                        pw.SizedBox(width: 4),
                        pw.Text(
                          companyAddress,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey300,
                          ),
                        ),
                      ],
                    ),
                  pw.SizedBox(height: 4),
                  if (companyPhone != null)
                    pw.Row(
                      children: [
                        pw.Icon(
                          pw.IconData(0xe0cd),
                          size: 12,
                          color: PdfColors.grey300,
                        ),
                        pw.SizedBox(width: 4),
                        pw.Text(
                          companyPhone,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey300,
                          ),
                        ),
                      ],
                    ),
                  pw.SizedBox(height: 4),
                  if (companyEmail != null)
                    pw.Row(
                      children: [
                        pw.Icon(
                          pw.IconData(0xe0be),
                          size: 12,
                          color: PdfColors.grey300,
                        ),
                        pw.SizedBox(width: 4),
                        pw.Text(
                          companyEmail,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey300,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Logo
            if (logoImage != null)
              pw.Container(
                width: 80,
                height: 80,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
          ],
        ),
      );
    }

    pw.Widget buildInvoiceBadge() {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: pw.BoxDecoration(
          color: style.accentColor,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              style.title,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              style.titleEnglish,
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget buildInvoiceMeta() {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfTheme.background,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'رقم الفاتورة',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfTheme.textSecondary,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  invoiceNumber,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfTheme.textPrimary,
                  ),
                ),
              ],
            ),
            pw.Container(width: 1, height: 30, color: PdfTheme.border),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'التاريخ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfTheme.textSecondary,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${invoiceDate.year}-${invoiceDate.month.toString().padLeft(2, '0')}-${invoiceDate.day.toString().padLeft(2, '0')}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfTheme.textPrimary,
                  ),
                ),
              ],
            ),
            pw.Container(width: 1, height: 30, color: PdfTheme.border),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'حالة الدفع',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfTheme.textSecondary,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: isDue ? PdfTheme.warning : PdfTheme.success,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    selectedPaymentMethod!,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    pw.Widget buildClientSection() {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfTheme.border),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'بيانات العميل',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfTheme.textSecondary,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              clientName,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfTheme.textPrimary,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Icon(
                  pw.IconData(0xe0c8),
                  size: 10,
                  color: PdfTheme.textSecondary,
                ),
                pw.SizedBox(width: 4),
                pw.Expanded(
                  child: pw.Text(
                    clientAddress,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                pw.Icon(
                  pw.IconData(0xe0cd),
                  size: 10,
                  color: PdfTheme.textSecondary,
                ),
                pw.SizedBox(width: 4),
                pw.Text(
                  clientPhone,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    pw.Widget buildItemsTable() {
      return pw.TableHelper.fromTextArray(
        headers: ['الإجمالي', 'السعر', 'الكمية', 'الوصف'],
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 11,
        ),
        headerDecoration: pw.BoxDecoration(
          color: style.accentColor,
          borderRadius: const pw.BorderRadius.only(
            topLeft: pw.Radius.circular(8),
            topRight: pw.Radius.circular(8),
          ),
        ),
        cellAlignment: pw.Alignment.center,
        cellHeight: 40,
        cellStyle: pw.TextStyle(fontSize: 10, color: PdfTheme.textPrimary),
        oddRowDecoration: const pw.BoxDecoration(color: PdfTheme.background),
        data: items.map((item) {
          final qty = (item['quantity'] ?? 0) as num;
          final price = (item['price'] ?? 0) as num;
          final itemTotal = qty * price;
          return [
            itemTotal.toStringAsFixed(2),
            price.toStringAsFixed(2),
            qty.toString(),
            item['name']?.toString() ?? '',
          ];
        }).toList(),
      );
    }

    pw.Widget _buildSummaryRow(
      String label,
      double value, {
      bool isTotal = false,
      bool isDiscount = false,
    }) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 12 : 10,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isTotal ? PdfTheme.textPrimary : PdfTheme.textSecondary,
            ),
          ),
          pw.Text(
            '${value.toStringAsFixed(2)} ',
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 10,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isDiscount
                  ? PdfTheme.danger
                  : (isTotal ? style.accentColor : PdfTheme.textPrimary),
            ),
          ),
        ],
      );
    }

    pw.Widget buildSummary() {
      return pw.Container(
        width: 240,
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfTheme.background,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfTheme.border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'ملخص الفاتورة',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfTheme.textSecondary,
              ),
            ),
            pw.SizedBox(height: 12),
            _buildSummaryRow('المجموع الفرعي:', subtotal),
            pw.SizedBox(height: 8),
            _buildSummaryRow('الخصم:', discount, isDiscount: true),
            pw.SizedBox(height: 8),
            _buildSummaryRow('الضريبة:', tax),
            pw.Divider(color: PdfTheme.border, height: 20),
            _buildSummaryRow('الإجمالي الكلي:', total, isTotal: true),
          ],
        ),
      );
    }

    pw.Widget buildDueDates() {
      if (!isDue /* || dueDates == null || dueDates.isEmpty || */ &&
          !isInstallment)
        return pw.SizedBox();

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 20),
          pw.Text(
            'جدولة المدفوعات',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfTheme.textSecondary,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['الحالة', 'التاريخ', 'القيمة', 'النوع'],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfTheme.headerBg),
            cellAlignment: pw.Alignment.center,
            cellStyle: pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.8),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
            },
            data: dueDates!.map((item) {
              final date = item['date'] as DateTime;
              final status = item['status']?.toString() ?? '';
              final isPaid = status == 'تم';
              return [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: pw.BoxDecoration(
                    color: isPaid ? PdfTheme.success : PdfTheme.warning,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    status,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                '${(item['value'] ?? 0.0).toStringAsFixed(2)} ',
                item['type']?.toString() ?? '',
              ];
            }).toList(),
          ),
        ],
      );
    }

    pw.Widget buildNotes() {
      if (notes == null || notes.isEmpty) return pw.SizedBox();

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 20),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfTheme.background,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfTheme.border),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ملاحظات',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfTheme.textSecondary,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  notes,
                  style: pw.TextStyle(fontSize: 9, color: PdfTheme.textPrimary),
                ),
              ],
            ),
          ),
        ],
      );
    }

    pw.Widget buildFooter() {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 30),
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfTheme.background,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'شكراً لتعاملكم معنا',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfTheme.textPrimary,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'هذه الفاتورة صادرة إلكترونياً ولا تحتاج توقيع',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfTheme.textSecondary,
                  ),
                ),
              ],
            ),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: invoiceNumber,
              width: 50,
              height: 50,
            ),
          ],
        ),
      );
    }

    // Build PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with company info
                buildHeader(),
                pw.SizedBox(height: 20),

                // Invoice badge and meta
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 2, child: buildInvoiceBadge()),
                    pw.SizedBox(width: 16),
                    pw.Expanded(flex: 3, child: buildInvoiceMeta()),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Client info
                buildClientSection(),
                pw.SizedBox(height: 24),

                // Items
                pw.Text(
                  'تفاصيل الأصناف',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfTheme.textSecondary,
                  ),
                ),
                pw.SizedBox(height: 8),
                buildItemsTable(),
                pw.SizedBox(height: 20),

                // Summary aligned right
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: buildSummary(),
                ),

                // Due dates
                buildDueDates(),

                // Notes
                buildNotes(),

                // Footer
                buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'فاتورة رقم $invoiceNumber.pdf',
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'فاتورة رقم $invoiceNumber.pdf',
    );

    return bytes;
  }
}
