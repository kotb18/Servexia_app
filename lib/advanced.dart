import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';

/// صفحة الإحصائيات
class StatisticsPage extends StatelessWidget {
  final String groupId;

  const StatisticsPage({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final invoiceService = InvoiceService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        title: const Text(
          'الإحصائيات',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<InvoiceStatistics>(
        future: invoiceService.getStatistics(groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }

          final stats = snapshot.data ?? InvoiceStatistics();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AdvancedSearchPage(groupId: groupId),
                      ),
                    );
                  },
                  label: const Text('البحث المتقدم'),
                  icon: const Icon(Icons.search),
                ),
                // بطاقة الملخص العام
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
                          'الملخص العام',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow(
                          'إجمالي الفواتير',
                          stats.totalInvoices.toString(),
                          Icons.receipt_long,
                          const Color(0xFF1E3A8A),
                        ),
                        _buildStatRow(
                          'إجمالي المبيعات',
                          stats.totalSales.toStringAsFixed(2),
                          Icons.trending_up,
                          const Color(0xFF10B981),
                        ),
                        _buildStatRow(
                          'إجمالي المشتريات',
                          stats.totalPurchases.toStringAsFixed(2),
                          Icons.trending_down,
                          const Color(0xFFEF4444),
                        ),
                        _buildStatRow(
                          'الربح/الخسارة',
                          stats.profit.toStringAsFixed(2),
                          Icons.attach_money,
                          stats.profit >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // بطاقة المبيعات
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
                          'المبيعات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow(
                          'عدد فواتير البيع',
                          stats.salesCount.toString(),
                          Icons.shopping_cart,
                          const Color(0xFF10B981),
                        ),
                        _buildStatRow(
                          'إجمالي المبيعات',
                          stats.totalSales.toStringAsFixed(2),
                          Icons.attach_money,
                          const Color(0xFF10B981),
                        ),
                        _buildStatRow(
                          'متوسط فاتورة البيع',
                          stats.averageSaleAmount.toStringAsFixed(2),
                          Icons.bar_chart,
                          const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // بطاقة المشتريات
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
                          'المشتريات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow(
                          'عدد فواتير الشراء',
                          stats.purchasesCount.toString(),
                          Icons.shopping_bag,
                          const Color(0xFFEF4444),
                        ),
                        _buildStatRow(
                          'إجمالي المشتريات',
                          stats.totalPurchases.toStringAsFixed(2),
                          Icons.attach_money,
                          const Color(0xFFEF4444),
                        ),
                        _buildStatRow(
                          'متوسط فاتورة الشراء',
                          stats.averagePurchaseAmount.toStringAsFixed(2),
                          Icons.bar_chart,
                          const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// صفحة البحث المتقدم
class AdvancedSearchPage extends StatefulWidget {
  final String groupId;

  const AdvancedSearchPage({Key? key, required this.groupId}) : super(key: key);

  @override
  State<AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

class _AdvancedSearchPageState extends State<AdvancedSearchPage> {
  final InvoiceService _invoiceService = InvoiceService();
  late InvoiceFilter _filter;
  List<Invoice> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filter = InvoiceFilter();
  }

  Future<void> _performSearch() async {
    setState(() {
      _isSearching = true;
    });

    final results = await _invoiceService.searchInvoices(
      widget.groupId,
      _filter,
    );

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        title: const Text(
          'البحث المتقدم',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة خيارات البحث
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
                      'خيارات البحث',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // نوع الفاتورة
                    Text(
                      'نوع الفاتورة',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String?>(
                      value: _filter.type,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('الكل'),
                        ),
                        const DropdownMenuItem(
                          value: 'بيع',
                          child: Text('بيع'),
                        ),
                        const DropdownMenuItem(
                          value: 'شراء',
                          child: Text('شراء'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filter = _filter.copyWith(type: value);
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // نطاق المبلغ
                    Text(
                      'نطاق المبلغ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'من',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _filter = _filter.copyWith(
                                  minAmount: double.tryParse(value),
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'إلى',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _filter = _filter.copyWith(
                                  maxAmount: double.tryParse(value),
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // أزرار البحث
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _filter = InvoiceFilter();
                                _searchResults = [];
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              foregroundColor: const Color(0xFF1F2937),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('إعادة تعيين'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _performSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('بحث'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // نتائج البحث
            if (_isSearching)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
              )
            else if (_searchResults.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'لم يتم العثور على نتائج',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تم العثور على ${_searchResults.length} نتيجة',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final invoice = _searchResults[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        child: ListTile(
                          title: Text(invoice.invoiceNumber),
                          subtitle: Text(invoice.customerName),
                          trailing: Text(
                            invoice.summary.total.toStringAsFixed(2),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// أداة تصدير الفواتير
class ExportInvoicesWidget extends StatelessWidget {
  final List<Invoice> invoices;

  const ExportInvoicesWidget({Key? key, required this.invoices})
    : super(key: key);

  /// تصدير الفواتير إلى CSV
  String _generateCSV() {
    StringBuffer csv = StringBuffer();

    // رأس الجدول
    csv.writeln(
      'رقم الفاتورة,النوع,اسم العميل,الهاتف,العنوان,الإجمالي,التاريخ',
    );

    // البيانات
    for (final invoice in invoices) {
      csv.writeln(
        '${invoice.invoiceNumber},'
        '${invoice.type},'
        '${invoice.customerName},'
        '${invoice.customerPhone},'
        '${invoice.customerAddress},'
        '${invoice.summary.total},'
        '${invoice.date.toIso8601String()}',
      );
    }

    return csv.toString();
  }

  /// تصدير الفواتير إلى JSON
  String _generateJSON() {
    final jsonList = invoices.map((invoice) => invoice.toJson()).toList();
    return jsonList.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تصدير الفواتير',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // تصدير إلى CSV
                final csv = _generateCSV();
                // يمكن حفظ الملف أو مشاركته
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تصدير الفواتير إلى CSV')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('تصدير إلى CSV'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // تصدير إلى JSON
                final json = _generateJSON();
                // يمكن حفظ الملف أو مشاركته
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تصدير الفواتير إلى JSON')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                foregroundColor: const Color(0xFF1F2937),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('تصدير إلى JSON'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}
