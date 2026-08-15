import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maintenance/advanced.dart';
import 'package:maintenance/invoicePage.dart';
import 'models.dart';
import 'services.dart';

class MyInvoicesPage extends StatefulWidget {
  final String groupId;
  final bool isSelectionMode;
  final Function(Invoice)? onInvoiceSelected;
  final String customerId;
  final String customerName;
  final String screenroute = '/myInvoices';
  final bool isFromCustomerScreen;

  const MyInvoicesPage({
    super.key,
    required this.groupId,
    required this.isSelectionMode,
    this.onInvoiceSelected,
    required this.customerId,
    required this.customerName,
    required this.isFromCustomerScreen,
  });

  @override
  State<MyInvoicesPage> createState() => _MyInvoicesPageState();
}

class _MyInvoicesPageState extends State<MyInvoicesPage> {
  final InvoiceService _invoiceService = InvoiceService();

  // الفلاتر
  String _selectedType = 'الكل';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPaymentMethod = 'الكل';
  String _selectedInstallmentStatus = 'الكل';

  /// بناء الـ Query ديناميكياً
  Query<Map<String, dynamic>> get _invoicesQuery {
    return _invoiceService.getInvoicesQuery(
      widget.groupId,
      customerId: widget.isFromCustomerScreen ? widget.customerId : null,
      type: _selectedType == 'الكل' ? null : _selectedType,
      paymentMethod: _selectedPaymentMethod,
      installmentStatus: _selectedInstallmentStatus,
      fromDate: _startDate,
      toDate: _endDate,
      searchText: _searchQuery.isEmpty ? null : _searchQuery,
      excludeReturns: widget.isSelectionMode,
      excludeMaintenance: widget.isSelectionMode,
      excludeQuotes: widget.isSelectionMode,
    );
  }

  /// مفتاح فريد يتغير مع كل فلتر لإعادة بناء الـ Pagination
  String get _filterKey {
    return '${widget.groupId}_'
        '${widget.customerId}_'
        '${widget.isSelectionMode}_'
        '${_selectedType}_' // ✅ صح: ${_selectedType}_
        '${_searchQuery}_'
        '${_selectedPaymentMethod}_'
        '${_selectedInstallmentStatus}_'
        '${_startDate?.millisecondsSinceEpoch}_'
        '${_endDate?.millisecondsSinceEpoch}';
  }

  void _editInvoice(Invoice invoice) async {
    if (widget.onInvoiceSelected != null) {
      widget.onInvoiceSelected!(invoice);
      if (!mounted) return;
      Navigator.pop(context, ModalRoute.withName(InvoicePage.screenroute));
    } else {
      if (!mounted) return;
      Navigator.pop(context, {'invoice': invoice, 'isEditMode': true});
    }
  }

  void _deleteInvoice(Invoice invoice) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل أنت متأكد أنك تريد حذف الفاتورة رقم ${invoice.invoiceNumber}؟',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('حذف'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed != null && confirmed) {
        if (invoice.id != null) {
          try {
            await _invoiceService.deleteInvoice(widget.groupId, invoice.id!);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف الفاتورة بنجاح.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن حذف فاتورة بدون معرف.')),
          );
        }
      }
    });
  }

  Future<void> showCustomDialog({
    required BuildContext context,
    required String title,
    required String message,
    required Invoice invoice,
    VoidCallback? onConfirm,
  }) async {
    await showDialog(
      context: context,
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
                _printInvoice(invoice, true);
              },
              child: const Text('طابعة حرارية'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (!mounted) return;
                navigator.pop();
                _printInvoice(invoice, false);
              },
              child: const Text('طابعة A4'),
            ),
          ],
        );
      },
    );
  }

  void _printInvoice(Invoice invoice, bool thermalInvoice) async {
    if (thermalInvoice) {
      final pdfBytes = await ThermalPrinterService.generateThermalPdf(
        invoiceType: invoice.type,
        invoiceNumber: invoice.invoiceNumber,
        invoiceDate: invoice.date,
        clientName: invoice.customerName,
        items: invoice.items.map((item) {
          return {
            'itemId': item.itemId ?? '',
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'total': item.total,
          };
        }).toList(),
        subtotal: invoice.summary.subTotal,
        discount: invoice.summary.discountValue,
        tax: invoice.summary.taxValue,
        total: invoice.summary.total,
        notes: invoice.notes,
        companyName: invoice.companyName,
        isQuote: invoice.type == 'عرض سعر',
      );
      await ThermalPrinterService.printThermalPdf(pdfBytes);
      await ThermalPrinterService.shareToThermalPrinter(pdfBytes, 'فاتورة_001');
    } else {
      await InvoiceGenerator.generateProfessionalInvoice(
        invoiceType: invoice.type,
        invoiceNumber: invoice.invoiceNumber,
        invoiceDate: invoice.date,
        clientName: invoice.customerName,
        clientAddress: invoice.customerAddress,
        clientPhone: invoice.customerPhone,
        items: invoice.items.map((item) {
          return {
            'itemId': item.itemId ?? '',
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'total': item.total,
          };
        }).toList(),
        subtotal: invoice.summary.subTotal,
        discount: invoice.summary.discountValue,
        tax: invoice.summary.taxValue,
        total: invoice.summary.total,
        notes: invoice.notes,
        companyName: invoice.companyName,
        companyAddress: invoice.companyAddress,
        companyPhone: invoice.companyPhone,
        companyEmail: invoice.companyEmail,
        companyLogoPath: 'widget.state.companyLogoPath',
        isDue: invoice.paymentMethod == 'آجل',
        isInstallment: invoice.paymentMethod == 'تقسيط',
        dueDates: invoice.installments.map((installment) {
          return {
            'date': installment.date,
            'value': installment.value,
            'status': installment.status,
            'type': installment.type,
          };
        }).toList(),
        showAddress: invoice.showAddress,
        showEmail: invoice.showEmail,
        showDiscount: invoice.showDiscount,
        showLogo: invoice.showLogo,
        showNotes: invoice.showNotes,
        showPhone: invoice.showPhone,
        showTax: invoice.showTax,
        isQuote: invoice.type == 'عرض سعر',
        originalInvoiceNumber: invoice.type == 'مرتجع'
            ? invoice.invoiceNumber
            : null,
      );
    }
  }

  void _openInvoiceDetails(Invoice invoice) {
    if (widget.isSelectionMode) {
      Navigator.pop(context, invoice);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            InvoiceDetailPage(invoice: invoice, groupId: widget.groupId),
      ),
    );
  }

  void _openFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterPanel(
        selectedType: _selectedType,
        selectedPaymentMethod: _selectedPaymentMethod,
        selectedInstallmentStatus: _selectedInstallmentStatus,
        startDate: _startDate,
        endDate: _endDate,
        onApply: (type, paymentMethod, installmentStatus, start, end) {
          setState(() {
            _selectedType = type;
            _selectedPaymentMethod = paymentMethod;
            _selectedInstallmentStatus = installmentStatus;
            _startDate = start;
            _endDate = end;
          });
          Navigator.pop(context);
        },
        onReset: () {
          setState(() {
            _selectedType = 'الكل';
            _selectedPaymentMethod = 'الكل';
            _selectedInstallmentStatus = 'الكل';
            _startDate = null;
            _endDate = null;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: !widget.isFromCustomerScreen
            ? const Color(0xFF1E3A8A)
            : Colors.green,
        title: Text(
          (!widget.isSelectionMode && !widget.isFromCustomerScreen)
              ? 'فواتيري'
              : (widget.isSelectionMode && !widget.isFromCustomerScreen)
              ? 'اختر فاتورة للإرتجاع'
              : (!widget.isSelectionMode && widget.isFromCustomerScreen)
              ? 'فواتير: ${widget.customerName}'
              : '',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!widget.isFromCustomerScreen)
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: _openFilterPanel,
            ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.isSelectionMode && !widget.isFromCustomerScreen)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        StatisticsPage(groupId: widget.groupId),
                  ),
                );
              },
              label: const Text('عرض الإحصائيات'),
              icon: const Icon(Icons.bar_chart_outlined),
            ),

          // ✅ شريط البحث
          if (!widget.isFromCustomerScreen)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ابحث عن رقم الفاتورة أو اسم العميل...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF1E3A8A),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),

          // ✅ Chips الفلاتر المفعلة
          if (_selectedType != 'الكل' ||
              _selectedPaymentMethod != 'الكل' ||
              _selectedInstallmentStatus != 'الكل' ||
              _startDate != null ||
              _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedType != 'الكل')
                    Chip(
                      label: Text(_selectedType),
                      onDeleted: () => setState(() => _selectedType = 'الكل'),
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (_selectedPaymentMethod != 'الكل')
                    Chip(
                      label: Text(_selectedPaymentMethod),
                      onDeleted: () =>
                          setState(() => _selectedPaymentMethod = 'الكل'),
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (_selectedInstallmentStatus != 'الكل')
                    Chip(
                      label: Text(_selectedInstallmentStatus),
                      onDeleted: () =>
                          setState(() => _selectedInstallmentStatus = 'الكل'),
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (_startDate != null)
                    Chip(
                      label: Text(
                        'من: ${DateFormat('dd/MM/yyyy', 'ar').format(_startDate!)}',
                      ),
                      onDeleted: () => setState(() => _startDate = null),
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (_endDate != null)
                    Chip(
                      label: Text(
                        'إلى: ${DateFormat('dd/MM/yyyy', 'ar').format(_endDate!)}',
                      ),
                      onDeleted: () => setState(() => _endDate = null),
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

          // ✅ قائمة الفواتير مع Pagination
          Expanded(
            child: _searchQuery.isNotEmpty
                // ✅ وضع البحث: Query منفصل
                ? FirestorePagination(
                    key: ValueKey('search_${_searchQuery}_$_filterKey'),
                    query: _invoiceService.searchInvoicesQuery(
                      widget.groupId,
                      _searchQuery,
                    ),
                    limit: 5, // نزودها شوية عشان نغطي الفراغات
                    viewType: ViewType.list,
                    isLive: true,
                    padding: const EdgeInsets.all(16),
                    initialLoader: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    bottomLoader: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    onEmpty: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد نتائج لـ "$_searchQuery"',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context, docs, index) {
                      final invoice = Invoice.fromFirestore(docs[index]);
                      return _buildInvoiceCard(invoice);
                    },
                  )
                // ✅ وضع الفلاتر: Pagination العادي
                : FirestorePagination(
                    key: ValueKey(_filterKey),
                    query: _invoicesQuery,
                    limit: 5,
                    viewType: ViewType.list,
                    isLive: true,
                    padding: const EdgeInsets.all(16),
                    initialLoader: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    bottomLoader: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    onEmpty: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد فواتير',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context, docs, index) {
                      final invoice = Invoice.fromFirestore(docs[index]);
                      return _buildInvoiceCard(invoice);
                    },
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    // ⚠️ فلترة isSelectionMode + thereIsReturn
    if (widget.isSelectionMode && invoice.thereIsReturn) {
      return const SizedBox.shrink();
    }

    return InvoiceCard(
      groupId: widget.groupId,
      invoice: invoice,
      isSelectionMode: widget.isSelectionMode,
      onTap: () => _openInvoiceDetails(invoice),
      onEdit: () => _editInvoice(invoice),
      onDelete: () => _deleteInvoice(invoice),
      onPrint: () => showCustomDialog(
        context: context,
        title: 'اختر نوع الطباعة',
        message: 'هل ترغب في طباعة الفاتورة على طابعة حرارية أم طابعة A4؟',
        invoice: invoice,
      ),
    );
  }
}

/// بطاقة الفاتورة (محدثة مع عرض الأقساط)
class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  final bool isSelectionMode;
  final String groupId;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    required this.isSelectionMode,
    this.onEdit,
    this.onDelete,
    this.onPrint,
    required this.groupId,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPrint;

  Widget _actionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final InvoiceService _invoiceService = InvoiceService();
    print('lllllllllllllllllllllllllllll${invoice.thereIsReturn}');
    Color typeColor;
    String typeLabel;
    typeLabel = invoice.type == 'مرتجع' ? invoice.returnType : invoice.type;
    typeColor = invoice.type == 'بيع'
        ? const Color(0xFF10B981)
        : invoice.type == 'شراء'
        ? Colors.blue
        : invoice.type == 'صيانة'
        ? const Color.fromARGB(255, 222, 157, 18)
        : invoice.type == 'مرتجع'
        ? Colors.red
        : const Color(0xFF8B5CF6);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: رقم الفاتورة والنوع
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMMM yyyy', 'ar').format(invoice.date),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
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
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // الخط الفاصل
              Container(height: 1, color: const Color(0xFFE5E7EB)),

              const SizedBox(height: 12),

              // الصف الثاني: اسم العميل والمبلغ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'العميل',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invoice.customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'الإجمالي',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${invoice.summary.total.toStringAsFixed(2)} ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // الصف الثالث: معلومات إضافية
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // عدد الأصناف
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${invoice.items.length} صنف',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),

                  // طريقة الدفع
                  Row(
                    children: [
                      Icon(Icons.payment, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Text(
                        invoice.paymentMethod,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),

              // عرض معلومات الأقساط إذا كانت موجودة
              if (invoice.hasInstallments) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الأقساط',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '${invoice.installments.length - 1} أقساط',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'مدفوع: ${invoice.totalPaidInstallments.toStringAsFixed(2)} ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'معلق: ${invoice.totalPendingInstallments.toStringAsFixed(2)} ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (invoice.overdueInstallmentsCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'متأخر: ${invoice.overdueInstallmentsCount} أقساط',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (invoice.thereIsReturn)
                TextButton(
                  onPressed: () async {
                    final returnedInvoice = await _invoiceService.getInvoice(
                      groupId,
                      invoice.reInvoiceId,
                    );

                    if (returnedInvoice == null) return;

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InvoiceDetailPage(
                          invoice: returnedInvoice,
                          groupId: groupId,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.all(8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Color.fromARGB(
                      255,
                      139,
                      26,
                      156,
                    ).withOpacity(0.1),
                  ),
                  child: const Text(
                    'هذه الفاتورة مرتبطة بفاتورة مرتجعة',
                    style: TextStyle(
                      color: Color.fromARGB(255, 141, 26, 156),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (invoice.type == 'مرتجع')
                TextButton(
                  onPressed: () async {
                    final originalInvoiceId = await _invoiceService.getInvoice(
                      groupId,
                      invoice.originalInvoiceId,
                    );

                    if (originalInvoiceId == null) return;

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InvoiceDetailPage(
                          invoice: originalInvoiceId,
                          groupId: groupId,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.all(8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Color.fromARGB(
                      255,
                      17,
                      220,
                      48,
                    ).withOpacity(0.1),
                  ),
                  child: const Text(
                    'الفاتورة الأصليــــة',
                    style: TextStyle(
                      color: Color.fromARGB(255, 141, 26, 156),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (!isSelectionMode)
                Container(
                  //  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    spacing: 10,
                    children: [
                      /*  if (onEdit != null && invoice.type != 'مرتجع')
                        _actionButton(
                          text: 'تعديل',
                          icon: Icons.edit_rounded,
                          color: Colors.blue,
                          onTap: onEdit!,
                        ), */
                      if (onPrint != null)
                        _actionButton(
                          text: 'طباعة',
                          icon: Icons.print_rounded,
                          color: Colors.deepPurple,
                          onTap: onPrint!,
                        ),

                      if (onDelete != null && invoice.type != 'مرتجع')
                        _actionButton(
                          text: 'مسح',
                          icon: Icons.delete_rounded,
                          color: const Color.fromARGB(255, 122, 24, 17),
                          onTap: onDelete!,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// لوحة الفلترة (محدثة)
class FilterPanel extends StatefulWidget {
  final String selectedType;
  final String selectedPaymentMethod;
  final String selectedInstallmentStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(String, String, String, DateTime?, DateTime?) onApply;
  final VoidCallback onReset;

  const FilterPanel({
    super.key,
    required this.selectedType,
    required this.selectedPaymentMethod,
    required this.selectedInstallmentStatus,
    required this.startDate,
    required this.endDate,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late String _selectedType;
  late String _selectedPaymentMethod;
  late String _selectedInstallmentStatus;
  late DateTime? _startDate;
  late DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType;
    _selectedPaymentMethod = widget.selectedPaymentMethod;
    _selectedInstallmentStatus = widget.selectedInstallmentStatus;
    _startDate = widget.startDate;
    _endDate = widget.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            const Text(
              'تصفية الفواتير',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),

            const SizedBox(height: 24),

            // فلترة النوع
            Text(
              'نوع الفاتورة',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _buildTypeButton('الكل')),
                const SizedBox(width: 8),
                Expanded(child: _buildTypeButton('بيع')),
                const SizedBox(width: 8),
                Expanded(child: _buildTypeButton('شراء')),
              ],
            ),

            const SizedBox(height: 24),

            // فلترة طريقة الدفع
            Text(
              'طريقة الدفع',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 12),

            DropdownButton<String>(
              value: _selectedPaymentMethod,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 'الكل', child: Text('الكل')),
                const DropdownMenuItem(value: 'كاش', child: Text('كاش')),
                const DropdownMenuItem(value: 'شيك', child: Text('شيك')),
                const DropdownMenuItem(
                  value: 'تحويل بنكي',
                  child: Text('تحويل بنكي'),
                ),
                const DropdownMenuItem(
                  value: 'بطاقة ائتمان',
                  child: Text('بطاقة ائتمان'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value ?? 'الكل';
                });
              },
            ),

            const SizedBox(height: 24),

            // فلترة حالة الأقساط
            Text(
              'حالة الأقساط',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 12),

            DropdownButton<String>(
              value: _selectedInstallmentStatus,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 'الكل', child: Text('الكل')),
                const DropdownMenuItem(value: 'مدفوع', child: Text('مدفوع')),
                const DropdownMenuItem(value: 'معلق', child: Text('معلق')),
                const DropdownMenuItem(value: 'متأخر', child: Text('متأخر')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedInstallmentStatus = value ?? 'الكل';
                });
              },
            ),

            const SizedBox(height: 24),

            // فلترة التاريخ
            Text(
              'نطاق التاريخ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  // locale: const Locale('ar', 'SA'),
                );
                if (date != null) {
                  setState(() {
                    _startDate = date;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _startDate != null
                          ? DateFormat('dd/MM/yyyy', 'ar').format(_startDate!)
                          : 'من تاريخ',
                      style: TextStyle(
                        fontSize: 14,
                        color: _startDate != null
                            ? const Color(0xFF1F2937)
                            : Colors.grey[500],
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Color(0xFF1E3A8A),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  //  locale: const Locale('ar', 'SA'),
                );
                if (date != null) {
                  setState(() {
                    _endDate = date;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _endDate != null
                          ? DateFormat('dd/MM/yyyy', 'ar').format(_endDate!)
                          : 'إلى تاريخ',
                      style: TextStyle(
                        fontSize: 14,
                        color: _endDate != null
                            ? const Color(0xFF1F2937)
                            : Colors.grey[500],
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Color(0xFF1E3A8A),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // الأزرار
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onReset();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      foregroundColor: const Color(0xFF1F2937),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'إعادة تعيين',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(
                        _selectedType,
                        _selectedPaymentMethod,
                        _selectedInstallmentStatus,
                        _startDate,
                        _endDate,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'تطبيق',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            type,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ),
      ),
    );
  }
}

/// صفحة تفاصيل الفاتورة (محدثة مع عرض الأقساط)

class InvoiceDetailPage extends StatefulWidget {
  final Invoice invoice;
  final String groupId;

  const InvoiceDetailPage({
    super.key,
    required this.invoice,
    required this.groupId,
  });

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  final InvoiceService _invoiceService = InvoiceService();
  late Invoice _currentInvoice;

  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;
  }

  /// تحديث حالة القسط
  Future<void> _updateInstallmentStatus(
    int installmentNumber,
    String newStatus,
  ) async {
    final success = await _invoiceService.updateInstallmentStatus(
      widget.groupId,
      _currentInvoice.id!,
      installmentNumber,
      newStatus,
    );

    if (success) {
      final updatedInstallments = _currentInvoice.installments.map((inst) {
        if (inst.number == installmentNumber) {
          return inst.copyWith(status: newStatus);
        }
        return inst;
      }).toList();

      setState(() {
        _currentInvoice = _currentInvoice.copyWith(
          installments: updatedInstallments,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم تحديث حالة القسط بنجاح'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFF1E3A8A),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'بيع':
        return const Color(0xFF10B981);
      case 'شراء':
        return const Color(0xFF3B82F6);
      case 'صيانة':
        return const Color(0xFFF59E0B);
      case 'مرتجع':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'بيع':
        return Icons.shopping_cart_outlined;
      case 'شراء':
        return Icons.shopping_bag_outlined;
      case 'صيانة':
        return Icons.build_outlined;
      case 'مرتجع':
        return Icons.assignment_return_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(_currentInvoice.type);
    final typeLabel = _currentInvoice.type == 'مرتجع'
        ? _currentInvoice.returnType
        : _currentInvoice.type;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // AppBar متدرج مع تأثير زجاجي
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1E3A8A),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentInvoice.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'EEEE, dd MMMM yyyy',
                            'ar',
                          ).format(_currentInvoice.date),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: const Text(
                'تفاصيل الفاتورة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),

          // المحتوى الرئيسي
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // شريط الحالة العلوي
                  _buildStatusHeader(typeLabel, typeColor),

                  const SizedBox(height: 20),

                  // بطاقة المعلومات الأساسية
                  _buildAnimatedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          'المعلومات الأساسية',
                          Icons.info_outline,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'التاريخ',
                          value: DateFormat(
                            'dd/MM/yyyy',
                            'ar',
                          ).format(_currentInvoice.date),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.payment_outlined,
                          label: 'طريقة الدفع',
                          value: _currentInvoice.paymentMethod,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: _getTypeIcon(_currentInvoice.type),
                          label: 'نوع الفاتورة',
                          value: typeLabel,
                          valueColor: typeColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // بطاقة بيانات العميل
                  _buildAnimatedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          'بيانات العميل',
                          Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.person,
                          label: 'الاسم',
                          value: _currentInvoice.customerName,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.phone_outlined,
                          label: 'الهاتف',
                          value: _currentInvoice.customerPhone,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'العنوان',
                          value: _currentInvoice.customerAddress,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // بطاقة الأصناف
                  _buildAnimatedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          'الأصناف',
                          Icons.shopping_basket_outlined,
                        ),
                        const SizedBox(height: 16),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _currentInvoice.items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 24),
                          itemBuilder: (context, index) {
                            final item = _currentInvoice.items[index];
                            return _buildItemRow(item);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // بطاقة الملخص المالي
                  _buildAnimatedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          _currentInvoice.type == 'مرتجع'
                              ? 'الملخص المالي للمرتجع'
                              : 'الملخص المالي',
                          Icons.account_balance_wallet_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryRow(
                          label: 'الإجمالي الفرعي',
                          value:
                              '${_currentInvoice.summary.subTotal.toStringAsFixed(2)}',
                        ),
                        if (_currentInvoice.summary.discountValue > 0) ...[
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            label:
                                'الخصم (${_currentInvoice.summary.discountPercent.toStringAsFixed(1)}%)',
                            value:
                                '-${_currentInvoice.summary.discountValue.toStringAsFixed(2)}',
                            isDiscount: true,
                          ),
                        ],
                        if (_currentInvoice.summary.taxValue > 0) ...[
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            label:
                                'الضريبة (${_currentInvoice.summary.taxPercent.toStringAsFixed(1)}%)',
                            value:
                                '${_currentInvoice.summary.taxValue.toStringAsFixed(2)}',
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1),
                        ),
                        _buildTotalRow(
                          label: 'الإجمالي',
                          value:
                              '${_currentInvoice.summary.total.toStringAsFixed(2)}',
                          color: typeColor,
                        ),
                      ],
                    ),
                  ),

                  // جدول المرتجع
                  if (_currentInvoice.type == 'مرتجع') ...[
                    const SizedBox(height: 16),
                    _buildAnimatedCard(child: _buildReturnTable()),
                  ],

                  // الأقساط
                  if (_currentInvoice.hasInstallments) ...[
                    const SizedBox(height: 16),
                    _buildAnimatedCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle(
                                'الأقساط',
                                Icons.payments_outlined,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentInvoice.allInstallmentsPaid
                                      ? const Color(0xFF10B981).withOpacity(0.1)
                                      : const Color(
                                          0xFFF59E0B,
                                        ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _currentInvoice.allInstallmentsPaid
                                      ? 'مدفوع بالكامل'
                                      : 'جزئي',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _currentInvoice.allInstallmentsPaid
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // شريط التقدم
                          if (_currentInvoice.installments.isNotEmpty)
                            _buildInstallmentsProgress(),

                          const SizedBox(height: 16),

                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _currentInvoice.installments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final installment =
                                  _currentInvoice.installments[index];
                              return _buildInstallmentCard(installment);
                            },
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'إجمالي الأقساط',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_currentInvoice.installments.fold<double>(0, (sum, inst) => sum + inst.value).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // الملاحظات
                  if (_currentInvoice.notes != null &&
                      _currentInvoice.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildAnimatedCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('ملاحظات', Icons.notes_outlined),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              _currentInvoice.notes!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(String typeLabel, Color typeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getTypeIcon(_currentInvoice.type),
              color: typeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نوع الفاتورة',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 2),
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentInvoice.invoiceNumber,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[500]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(dynamic item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.quantity} × ${item.price.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${item.total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDiscount
                ? const Color(0xFFEF4444)
                : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentsProgress() {
    final total = _currentInvoice.installments.length;
    final paid = _currentInvoice.installments.where((i) => i.isPaid).length;
    final progress = total > 0 ? paid / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'التقدم',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            Text(
              '$paid / $total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0
                  ? const Color(0xFF10B981)
                  : const Color(0xFF1E3A8A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstallmentCard(Installment installment) {
    final statusColor = installment.isPaid
        ? const Color(0xFF10B981)
        : installment.isOverdue
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    final statusIcon = installment.isPaid
        ? Icons.check_circle
        : installment.isOverdue
        ? Icons.warning
        : Icons.schedule;

    return GestureDetector(
      onTap: () {
        if (!installment.isPaid) {
          _showInstallmentStatusDialog(installment);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    installment.type,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${installment.value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMMM yyyy', 'ar').format(installment.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                installment.statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInstallmentStatusDialog(Installment installment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.update,
                  size: 32,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تحديث حالة القسط ${installment.number}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اختر الحالة الجديدة للقسط',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              _buildStatusOption(
                context: context,
                label: 'مدفوع',
                color: const Color(0xFF10B981),
                icon: Icons.check_circle,
                onTap: () {
                  _updateInstallmentStatus(installment.number, 'تم');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              _buildStatusOption(
                context: context,
                label: 'معلق',
                color: const Color(0xFFF59E0B),
                icon: Icons.schedule,
                onTap: () {
                  _updateInstallmentStatus(installment.number, '!');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              _buildStatusOption(
                context: context,
                label: 'متأخر',
                color: const Color(0xFFEF4444),
                icon: Icons.warning,
                onTap: () {
                  _updateInstallmentStatus(installment.number, 'متأخر');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption({
    required BuildContext context,
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: color.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('تفاصيل المرتجع', Icons.assignment_return_outlined),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
                  children: [
                    _tableCell('البيان', isHeader: true),
                    _tableCell('القيمة', isHeader: true),
                  ],
                ),
                _buildTableRow(
                  'إجمالي الفاتورة الأصلية',
                  '${_currentInvoice.returnSummary!.totalBeforeReturn}',
                  valueColor: const Color(0xFF10B981),
                ),
                _buildTableRow(
                  'إجمالي المدفوع في الفاتورة الأصلية',
                  '${_currentInvoice.returnSummary!.totalPaidInstallments}',
                  valueColor: const Color(0xFFEF4444),
                ),
                _buildTableRow(
                  'إجمالي المرتجع',
                  '${_currentInvoice.returnSummary!.total}',
                  valueColor: const Color(0xFFEF4444),
                ),
                TableRow(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                  ),
                  children: [
                    _tableCell('الصافي بعد المرتجع', isBold: true),
                    _tableCell(
                      '${_currentInvoice.returnSummary!.netTotal}',
                      isBold: true,
                      color: _currentInvoice.returnSummary!.netTotal < 0.0
                          ? const Color.fromARGB(255, 175, 28, 112)
                          : const Color.fromARGB(255, 6, 88, 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value, {Color? valueColor}) {
    return TableRow(
      children: [
        _tableCell(label),
        _tableCell(value, color: valueColor),
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
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isHeader ? 14 : 13,
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.w500,
          color: isHeader ? Colors.white : (color ?? const Color(0xFF1F2937)),
        ),
      ),
    );
  }
}
