import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maintenance/advanced.dart';
import 'package:maintenance/invoicePage.dart';
import 'models.dart';
import 'services.dart';

/// صفحة MyInvoices الرئيسية (محدثة مع دعم الأقساط والـ Pagination)
class MyInvoicesPage extends StatefulWidget {
  final String groupId;
  final bool isSelectionMode;

  const MyInvoicesPage({
    super.key,
    required this.groupId,
    required this.isSelectionMode,
  });

  @override
  State<MyInvoicesPage> createState() => _MyInvoicesPageState();
}

class _MyInvoicesPageState extends State<MyInvoicesPage> {
  final InvoiceService _invoiceService = InvoiceService();
  late Stream<List<Invoice>> _invoicesStream;

  String _selectedType = 'الكل';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPaymentMethod = 'الكل';
  String _selectedInstallmentStatus = 'الكل';

  // للـ Pagination
  final List<Invoice> _allInvoices = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _invoicesStream = _invoiceService.getInvoices(widget.groupId);
  }

  /// تصفية الفواتير بناءً على الخيارات المختارة
  List<Invoice> _filterInvoices(List<Invoice> invoices) {
    return invoices.where((invoice) {
      // فلترة النوع
      if (_selectedType != 'الكل' && invoice.type != _selectedType) {
        return false;
      }

      // فلترة البحث
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final invoiceNumberMatches = invoice.invoiceNumber
            .toLowerCase()
            .contains(query);
        final customerNameMatches = invoice.customerName.toLowerCase().contains(
          query,
        );
        if (!invoiceNumberMatches && !customerNameMatches) {
          return false;
        }
      }

      // فلترة التاريخ
      if (_startDate != null &&
          invoice.date.isBefore(
            DateTime(_startDate!.year, _startDate!.month, _startDate!.day),
          )) {
        return false;
      }
      if (_endDate != null &&
          invoice.date.isAfter(
            DateTime(_endDate!.year, _endDate!.month, _endDate!.day + 1),
          )) {
        return false;
      }

      // فلترة طريقة الدفع
      if (_selectedPaymentMethod != 'الكل' &&
          invoice.paymentMethod != _selectedPaymentMethod) {
        return false;
      }

      // فلترة حالة الأقساط
      if (_selectedInstallmentStatus != 'الكل' && invoice.hasInstallments) {
        if (_selectedInstallmentStatus == 'مدفوع' &&
            !invoice.allInstallmentsPaid) {
          return false;
        }
        if (_selectedInstallmentStatus == 'معلق' &&
            invoice.allInstallmentsPaid) {
          return false;
        }
        if (_selectedInstallmentStatus == 'متأخر' &&
            invoice.overdueInstallmentsCount == 0) {
          return false;
        }
      }
      if ((widget.isSelectionMode && invoice.type == 'صيانة') ||
          (widget.isSelectionMode && invoice.type == 'مرتجع') ||
          (widget.isSelectionMode && invoice.type == 'عرض سعر')) {
        return false;
      }

      return true;
    }).toList();
  }

  /// تحميل المزيد من الفواتير (Pagination)
  Future<void> _loadMoreInvoices() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    final nextPage = await _invoiceService.getNextPage(
      widget.groupId,
      _lastDocument,
    );

    if (nextPage.isEmpty) {
      setState(() {
        _hasMoreData = false;
      });
    } else {
      setState(() {
        _allInvoices.addAll(nextPage);
        _lastDocument = null; // يتم تحديثه من الـ Stream
      });
    }

    setState(() {
      _isLoadingMore = false;
    });
  }

  /// فتح صفحة تفاصيل الفاتورة
  void _editInvoice(Invoice invoice) {
    final editItems0 = invoice.items;
    List<Map<String, dynamic>> editItems = [];
    for (var item in editItems0) {
      editItems.add({
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'originalItem': true, // Mark as from original invoice
        //  'id': item.itemId ?? '',
      });
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => InvoicePage(
          invoice: invoice, // Pass the invoice for editing
          itemsSale: editItems,
          itemsPurchase: editItems,
          groupId: widget.groupId,
          isEditMode: true,
          name: invoice.customerName,
          type: invoice.type,
          phone: invoice.customerPhone,
          address: invoice.customerAddress,
          isFromConstCustomers: true,
          isFromWorkSpace: false,
          customerId: invoice.customerId,
        ),
      ),
    );
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
              onPressed: () => Navigator.of(context).pop(false), // User cancels
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // User confirms
              child: const Text('حذف'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed != null && confirmed) {
        if (invoice.id != null) {
          final success = await _invoiceService.deleteInvoice(
            widget.groupId,
            invoice.id!,
          );
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم حذف الفاتورة بنجاح.')),
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('فشل حذف الفاتورة.')));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن حذف فاتورة بدون معرف.')),
          );
        }
      }
    });
  }

  void _printInvoice(Invoice invoice) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'وظيفة الطباعة للفاتورة رقم ${invoice.invoiceNumber} غير مطبقة بعد.',
        ),
      ),
    );
    // TODO: Implement actual print invoice logic, potentially using a package like 'printing' or 'pdf'
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

  /// فتح لوحة الفلترة
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
        backgroundColor: const Color(0xFF1E3A8A),
        title: Text(
          !widget.isSelectionMode ? 'فواتيري' : 'اختر فاتورة للإرتجاع',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _openFilterPanel,
          ),
        ],
      ),
      body: Column(
        children: [
          !widget.isSelectionMode
              ? ElevatedButton.icon(
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
                )
              : SizedBox.shrink(),
          // شريط البحث
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
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A)),
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

          // عرض الفلاتر المفعلة
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
                      onDeleted: () {
                        setState(() {
                          _selectedType = 'الكل';
                        });
                      },
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (_selectedPaymentMethod != 'الكل')
                    Chip(
                      label: Text(_selectedPaymentMethod),
                      onDeleted: () {
                        setState(() {
                          _selectedPaymentMethod = 'الكل';
                        });
                      },
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (_selectedInstallmentStatus != 'الكل')
                    Chip(
                      label: Text(_selectedInstallmentStatus),
                      onDeleted: () {
                        setState(() {
                          _selectedInstallmentStatus = 'الكل';
                        });
                      },
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
                      onDeleted: () {
                        setState(() {
                          _startDate = null;
                        });
                      },
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
                      onDeleted: () {
                        setState(() {
                          _endDate = null;
                        });
                      },
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

          // قائمة الفواتير
          Expanded(
            child: StreamBuilder<List<Invoice>>(
              stream: _invoicesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'حدث خطأ: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }

                final invoices = snapshot.data ?? [];
                final filteredInvoices = _filterInvoices(invoices);

                if (filteredInvoices.isEmpty) {
                  return Center(
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
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredInvoices.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filteredInvoices.length) {
                      if (_hasMoreData) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: _isLoadingMore
                                ? const CircularProgressIndicator(
                                    color: Color(0xFF1E3A8A),
                                  )
                                : ElevatedButton(
                                    onPressed: _loadMoreInvoices,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E3A8A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('تحميل المزيد'),
                                  ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    final invoice = filteredInvoices[index];
                    return InvoiceCard(
                      invoice: invoice,
                      isSelectionMode: widget.isSelectionMode,
                      onTap: () => _openInvoiceDetails(invoice),
                      onEdit: () => _editInvoice(invoice),
                      onDelete: () => _deleteInvoice(invoice),
                      onPrint: () => _printInvoice(invoice),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة الفاتورة (محدثة مع عرض الأقساط)
class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  final bool isSelectionMode;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    required this.isSelectionMode,
    this.onEdit,
    this.onDelete,
    this.onPrint,
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
    //  final isSale = invoice.isSale;
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
                      if (onEdit != null)
                        _actionButton(
                          text: 'تعديل',
                          icon: Icons.edit_rounded,
                          color: Colors.blue,
                          onTap: onEdit!,
                        ),

                      if (onPrint != null)
                        _actionButton(
                          text: 'طباعة',
                          icon: Icons.print_rounded,
                          color: Colors.deepPurple,
                          onTap: onPrint!,
                        ),

                      if (onDelete != null)
                        _actionButton(
                          text: 'مسح',
                          icon: Icons.delete_rounded,
                          color: Colors.red,
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
      // تحديث الفاتورة المحلية
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
        const SnackBar(content: Text('تم تحديث حالة القسط بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color typeColor;
    String typeLabel;
    typeLabel = _currentInvoice.type == 'مرتجع'
        ? _currentInvoice.returnType
        : _currentInvoice.type;
    typeColor = _currentInvoice.type == 'بيع'
        ? const Color(0xFF10B981)
        : _currentInvoice.type == 'شراء'
        ? Colors.blue
        : _currentInvoice.type == 'صيانة'
        ? const Color.fromARGB(255, 222, 157, 18)
        : _currentInvoice.type == 'مرتجع'
        ? Colors.red
        : const Color(0xFF8B5CF6);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        title: const Text(
          'تفاصيل الفاتورة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        /*  actions: [   
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {},
          ),
        ], */
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة المعلومات الأساسية
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currentInvoice.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
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
                    Text(
                      DateFormat(
                        'EEEE, dd MMMM yyyy',
                        'ar',
                      ).format(_currentInvoice.date),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'طريقة الدفع: ${_currentInvoice.paymentMethod}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // بطاقة بيانات العميل
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بيانات العميل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('الاسم', _currentInvoice.customerName),
                    _buildDetailRow('الهاتف', _currentInvoice.customerPhone),
                    _buildDetailRow('العنوان', _currentInvoice.customerAddress),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // بطاقة الأصناف
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الأصناف',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentInvoice.items.length,
                      itemBuilder: (context, index) {
                        final item = _currentInvoice.items[index];
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${item.total.toStringAsFixed(2)} ',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ],
                            ),
                            if (index < _currentInvoice.items.length - 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Divider(
                                  color: Colors.grey[200],
                                  height: 1,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // بطاقة الملخص المالي
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الملخص المالي',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      'الإجمالي الفرعي',
                      '${_currentInvoice.summary.subTotal.toStringAsFixed(2)} ',
                    ),
                    if (_currentInvoice.summary.discountValue > 0)
                      _buildSummaryRow(
                        'الخصم (${_currentInvoice.summary.discountPercent.toStringAsFixed(1)}%)',
                        '-${_currentInvoice.summary.discountValue.toStringAsFixed(2)} ',
                        isDiscount: true,
                      ),
                    if (_currentInvoice.summary.taxValue > 0)
                      _buildSummaryRow(
                        'الضريبة (${_currentInvoice.summary.taxPercent.toStringAsFixed(1)}%)',
                        '${_currentInvoice.summary.taxValue.toStringAsFixed(2)} ',
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: Colors.grey[200], height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الإجمالي',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          '${_currentInvoice.summary.total.toStringAsFixed(2)} ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // عرض الأقساط إذا كانت موجودة
            if (_currentInvoice.hasInstallments) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الأقساط',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _currentInvoice.installments.length,
                        itemBuilder: (context, index) {
                          final installment =
                              _currentInvoice.installments[index];
                          return _buildInstallmentCard(installment);
                        },
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey[200], height: 1),
                      const SizedBox(height: 12),
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
                                '${_currentInvoice.installments.fold<double>(0, (sum, inst) => sum + inst.value).toStringAsFixed(2)} ',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'الحالة',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentInvoice.allInstallmentsPaid
                                    ? 'مدفوع بالكامل'
                                    : 'جزئي',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _currentInvoice.allInstallmentsPaid
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_currentInvoice.notes != null &&
                _currentInvoice.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ملاحظات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentInvoice.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentCard(Installment installment) {
    final statusColor = installment.isPaid
        ? const Color(0xFF10B981)
        : installment.isOverdue
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    return GestureDetector(
      onTap: () {
        if (!installment.isPaid) {
          _showInstallmentStatusDialog(installment);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
          color: statusColor.withOpacity(0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
                    '${installment.value.toStringAsFixed(2)} - ${installment.type}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMMM yyyy', 'ar').format(installment.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
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
      builder: (context) => AlertDialog(
        title: Text('تحديث حالة القسط ${installment.number}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('مدفوع'),
              onTap: () {
                _updateInstallmentStatus(installment.number, 'تم');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('معلق'),
              onTap: () {
                _updateInstallmentStatus(installment.number, '!');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('متأخر'),
              onTap: () {
                _updateInstallmentStatus(installment.number, 'متأخر');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDiscount ? const Color(0xFFEF4444) : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
