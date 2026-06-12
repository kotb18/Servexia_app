import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/invoicePage.dart';
import 'package:maintenance/wareHouseItemeMovement.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

List<Map<String, dynamic>> itemsList = [];
String buttonText = '';
List<Map> items = [];
bool isSelected = false;
List<int> selectedIndex = [];
List<double> counters = [];

class StoreScreen extends StatefulWidget {
  final String groupId;
  final bool isFromInvoice;
  final bool deletedItems;
  final String invoiceType;
  final String customerId;
  const StoreScreen({
    super.key,
    required this.groupId,
    required this.isFromInvoice,
    required this.deletedItems,
    required this.invoiceType,
    required this.customerId,
  });
  static const String screenroute = 'StoreScreen';

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String? selectedLocation = 'all'; // null = لم يتم اختيار فلتر
  String searchText = '';
  bool deletedItems = false;
  final searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// تحميل المواقع
  Future<List<String>> loadLocations() async {
    final snap = await FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.groupId)
        .collection('items')
        .where('deleted', isEqualTo: false)
        .get();

    final set = <String>{};
    for (var doc in snap.docs) {
      if (doc['location'] != null && doc['location'].toString().isNotEmpty) {
        set.add(doc['location']);
      }
    }
    return set.toList()..sort();
  }

  /// Query البحث
  Query<Map<String, dynamic>> itemsQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.groupId)
        .collection('items')
        .where('deleted', isEqualTo: false);

    /// لو لم يتم اختيار فلتر → لا تعرض بيانات
    if (selectedLocation == null) {
      return q.where('name', isEqualTo: '__EMPTY__');
    }

    /// فلتر الموقع
    if (selectedLocation != 'all') {
      q = q.where('location', isEqualTo: selectedLocation);
    }

    /// البحث
    if (searchText.isNotEmpty) {
      q = q.orderBy('name').startAt([searchText]).endAt(['$searchText\uf8ff']);
    } else {
      q = q.orderBy('name');
    }

    return q;
  }

  Query<Map<String, dynamic>> itemsQueryDeleted() {
    return FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.groupId)
        .collection('items')
        .where('deleted', isEqualTo: true)
        .orderBy('name');
  }

  TextEditingController itemNameController = TextEditingController();
  TextEditingController itemQuantityController = TextEditingController();
  TextEditingController itemPriceController = TextEditingController();
  TextEditingController itemBuyController = TextEditingController();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    counters = List.generate(20, (_) => 0);
    if (widget.deletedItems) {
      items.clear();
      selectedIndex.clear();
    }
    if (items.isEmpty) {
      selectedIndex.clear();
      buttonText = ' اضافة ${selectedIndex.length} عنصر';
    }

    print(selectedIndex);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    searchController.dispose();
    itemNameController.dispose();
    itemQuantityController.dispose();
    itemPriceController.dispose();
    itemBuyController.dispose();
    selectedIndex.clear();
    // items.clear();
    counters.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (widget.isFromInvoice) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoicePage(
                  groupId: widget.groupId,
                  itemsSale:
                      (widget.invoiceType == 'بيع' ||
                          widget.invoiceType == 'عرض سعر')
                      ? items
                      : [],
                  itemsPurchase: widget.invoiceType == 'شراء' ? items : [],
                  name: '',
                  phone: '',
                  address: '',
                  customerId: widget.customerId,
                  isFromConstCustomers: false,
                  isFromWorkSpace: false,
                  type: widget.invoiceType,
                  isFormStore: false,
                ),
              ),
            );
          } else {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );

            try {
              // جلب البيانات الحالية بناءً على الفلتر المختار بدقة
              final query = !deletedItems ? itemsQuery() : itemsQueryDeleted();
              final snapshot = await query.get();

              // تحويل المستندات إلى قائمة من الخرائط (Maps)
              final List<Map<String, dynamic>> currentItems = snapshot.docs
                  .map((doc) => doc.data())
                  .toList();

              // إغلاق مؤشر التحميل
              Navigator.pop(context);

              if (currentItems.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا توجد بيانات لتصديرها')),
                );
                return;
              }

              // توليد الـ PDF باستخدام القائمة النظيفة
              generateInventoryPdf(currentItems);
            } catch (e) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('حدث خطأ أثناء جلب البيانات: $e')),
              );
            }
          }
          // إظهار مؤشر تحميل بسيط
        },
        label: widget.isFromInvoice
            ? Text(
                buttonText,
                style: TextStyle(
                  color: (widget.isFromInvoice && items.isNotEmpty)
                      ? Colors.white
                      : null,
                ),
              )
            : Text('تقرير PDF'),
        backgroundColor: (widget.isFromInvoice && items.isNotEmpty)
            ? Colors.blueAccent
            : null,
        icon: widget.isFromInvoice
            ? Icon(
                Icons.cached,
                color: (widget.isFromInvoice && items.isNotEmpty)
                    ? Colors.white
                    : null,
              )
            : Icon(Icons.picture_as_pdf),
      ),
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'المخزن',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔎 Search
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                enabled: !deletedItems && selectedLocation != null,
                decoration: const InputDecoration(
                  hintText: 'ابحث باسم الصنف...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    searchText = value.trim();
                  });
                },
              ),
            ),

            const SizedBox(height: 15),

            /// الفلاتر
            FutureBuilder<List<String>>(
              future: loadLocations(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox();
                }

                final locations = snap.data!;

                return Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          /// الكل
                          ChoiceChip(
                            label: const Text('الكل'),
                            selected: selectedLocation == 'all',
                            onSelected: (_) {
                              setState(() {
                                selectedLocation = 'all';
                                deletedItems = false;
                                searchText = '';
                              });
                            },
                          ),

                          const SizedBox(width: 8),

                          ...locations.map((loc) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(loc),
                                selected: selectedLocation == loc,
                                onSelected: (_) {
                                  setState(() {
                                    selectedLocation = loc;
                                    deletedItems = false;
                                    searchText = '';
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// سويتش المحذوفات
                    if (!widget.isFromInvoice)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'عرض الأصناف المحذوفة',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Switch(
                            value: deletedItems,
                            onChanged: (val) {
                              setState(() {
                                deletedItems = val;
                                searchText = '';
                                searchController.clear();
                                if (val) {
                                  selectedLocation = null;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 15),

            /// القائمة
            Expanded(
              child:
                  (selectedLocation == null &&
                      searchText.isEmpty &&
                      !deletedItems)
                  ? _buildEmptySearch()
                  : FirestorePagination(
                      key: ValueKey(
                        '$selectedLocation-$searchText-$deletedItems',
                      ),
                      limit: 10,
                      query: !deletedItems ? itemsQuery() : itemsQueryDeleted(),
                      viewType: ViewType.list,
                      onEmpty: Center(
                        child: Text(
                          !deletedItems
                              ? 'لا توجد أصناف'
                              : 'لا توجد أصناف محذوفة',
                        ),
                      ),
                      bottomLoader: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      itemBuilder: (context, docs, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        itemsList.add(data);
                        final id = doc.id;
                        isSelected = selectedIndex.contains(index);
                        if (items.isNotEmpty) {
                          items.where((item) => item['id'] == id).forEach((
                            item,
                          ) {
                            counters[index] = item['quantity'];
                          });
                        }
                        double selectedQuantity = 0.0;
                        selectedQuantity = counters[index];
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                if (widget.isFromInvoice) {
                                  setState(() {
                                    if (!selectedIndex.contains(index)) {
                                      items.add({
                                        'id': id,
                                        'isInventoryItem': true,
                                        'name': data['name'],
                                        'quantity': counters[index] > 0
                                            ? counters[index]
                                            : 1.0,
                                        'unit': data['unit'],
                                        'sku': data['sku'] ?? '',
                                        'price': data['price'] ?? 0,
                                        'location': data['location'],
                                        'notes': data['notes'],
                                        'createdAt':
                                            FieldValue.serverTimestamp(),
                                        'deleted': false,

                                        'coast':
                                            itemBuyController.text.isNotEmpty
                                            ? double.tryParse(
                                                itemBuyController.text,
                                              )
                                            : 0.0,
                                      });
                                      selectedIndex.add(index);
                                      buttonText =
                                          ' اضافة ${selectedIndex.length} عنصر';
                                    }

                                    counters[index]++;
                                    items
                                        .where((item) => item['id'] == id)
                                        .forEach((item) {
                                          item['quantity'] = counters[index] > 0
                                              ? counters[index]
                                              : 1;
                                        });
                                  });
                                } else {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          InventoryItemDetailsScreenRefactored(
                                            groupId: widget.groupId,
                                            itemId: id,
                                            deletedItems: deletedItems,
                                          ),
                                    ),
                                  );
                                }
                              },
                              onLongPress: () async {
                                if (widget.isFromInvoice) {
                                  itemQuantityController =
                                      TextEditingController(text: '1');
                                  itemPriceController = TextEditingController(
                                    text: data['price']?.toString() ?? '0',
                                  );
                                  showDialog(
                                    context: context,
                                    builder: (context) => Form(
                                      key: _formKey,
                                      child: AlertDialog(
                                        title: const Text(
                                          'هل تريد إضافة هذا الصنف إلى الفاتورة؟',
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '${data['name']} - ',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                    ), // اللون الأساسي
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        '${data['quantity']} ${data['unit']}',
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ), // اللون المختلف
                                                  ),
                                                ],
                                              ),
                                            ),
                                            TextFormField(
                                              controller:
                                                  itemQuantityController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText:
                                                    widget.invoiceType == 'بيع'
                                                    ? 'الكمية المراد بيعها'
                                                    : 'الكمية المراد إضافتها',
                                                labelStyle: TextStyle(
                                                  color:
                                                      widget.invoiceType ==
                                                          'بيع'
                                                      ? Colors.green
                                                      : Colors.blue,
                                                ),
                                              ),
                                              onTap: () {
                                                itemQuantityController
                                                    .selection = TextSelection(
                                                  baseOffset: 0,
                                                  extentOffset:
                                                      itemQuantityController
                                                          .text
                                                          .length,
                                                );
                                              },
                                              validator: (value) {
                                                if (widget.invoiceType ==
                                                    'بيع') {
                                                  // تأكد أن القيمة مش فاضية
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'من فضلك أدخل الكمية';
                                                  }

                                                  // تحويل النص إلى رقم
                                                  final enteredQuantity =
                                                      double.tryParse(value);
                                                  if (enteredQuantity == null) {
                                                    return 'أدخل قيمة رقمية صحيحة';
                                                  }

                                                  // المقارنة مع الكمية المخزنية
                                                  if (enteredQuantity >
                                                      data['quantity']) {
                                                    return 'لا يمكن بيع كمية أكبر من الكمية المخزنية';
                                                  }
                                                }
                                                return null; // يعني مفيش خطأ
                                              },
                                            ),
                                            if (widget.invoiceType == 'شراء')
                                              TextFormField(
                                                controller: itemBuyController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'سعر الشراء للفاتورة',
                                                    ),
                                                onTap: () {
                                                  itemBuyController.selection =
                                                      TextSelection(
                                                        baseOffset: 0,
                                                        extentOffset:
                                                            itemBuyController
                                                                .text
                                                                .length,
                                                      );
                                                },
                                              ),
                                            TextFormField(
                                              controller: itemPriceController,

                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'سعر الوحدة',
                                              ),
                                              onTap: () {
                                                itemPriceController.selection =
                                                    TextSelection(
                                                      baseOffset: 0,
                                                      extentOffset:
                                                          itemPriceController
                                                              .text
                                                              .length,
                                                    );
                                              },
                                            ),
                                          ],
                                        ),

                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('إلغاء'),
                                          ),
                                          ElevatedButton(
                                            child: const Text('إضافة'),
                                            onPressed: () {
                                              if (_formKey.currentState!
                                                  .validate()) {
                                                setState(() {
                                                  if (selectedIndex.contains(
                                                    index,
                                                  )) {
                                                    items.removeWhere(
                                                      (item) =>
                                                          item['id'] == id,
                                                    );
                                                    selectedIndex.remove(index);
                                                  }
                                                  selectedIndex.add(index);
                                                  buttonText =
                                                      ' اضافة ${selectedIndex.length} عنصر';
                                                });
                                                items.add({
                                                  'id': id,
                                                  'isInventoryItem': true,
                                                  'name': data['name'],
                                                  'quantity':
                                                      itemQuantityController
                                                          .text
                                                          .isNotEmpty
                                                      ? double.tryParse(
                                                          itemQuantityController
                                                              .text,
                                                        )
                                                      : 1,
                                                  'unit': data['unit'],
                                                  'sku': data['sku'] ?? '',
                                                  'price':
                                                      double.tryParse(
                                                        itemPriceController
                                                            .text,
                                                      ) ??
                                                      0,

                                                  'location': data['location'],
                                                  'notes': data['notes'],
                                                  'createdAt':
                                                      FieldValue.serverTimestamp(),
                                                  'deleted': false,

                                                  'coast':
                                                      itemBuyController
                                                          .text
                                                          .isNotEmpty
                                                      ? double.tryParse(
                                                          itemBuyController
                                                              .text,
                                                        )
                                                      : 0.0,
                                                });
                                                setState(() {
                                                  items
                                                      .where(
                                                        (item) =>
                                                            item['id'] == id,
                                                      )
                                                      .forEach((item) {
                                                        item['quantity'] =
                                                            itemQuantityController
                                                                .text
                                                                .isNotEmpty
                                                            ? double.tryParse(
                                                                itemQuantityController
                                                                    .text,
                                                              )
                                                            : 1.0;
                                                      });
                                                });
                                                Navigator.pop(context);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  /*  Navigator.pop(context, {
                                    'id': id,
                                    'name': data['name'],
                                    'quantity': data['quantity'],
                                    'unit': data['unit'],
                                    'sku': data['sku'] ?? '',
                                  }); */
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.inventory_2),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  data['name'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (data['deleted'] == true)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'محذوف',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                '${data['quantity']} ${data['unit']}',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              Text(
                                                '   -   ${data['price']}',
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          data['location'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (selectedQuantity > 0 && widget.isFromInvoice)
                              Positioned(
                                top: 0,
                                left: 0,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedIndex.remove(index);

                                      items.removeWhere(
                                        (item) => item['id'] == id,
                                      );

                                      buttonText =
                                          ' اضافة ${selectedIndex.length} عنصر';

                                      counters[index] = 0;
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                      '${selectedQuantity > 0 ? selectedQuantity : 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.search, size: 60, color: Colors.grey),
        SizedBox(height: 10),
        Text(
          'اختر "الكل" أو موقع المخزن لعرض الأصناف',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

Future<void> generateInventoryPdf(List<Map<String, dynamic>> itemsList) async {
  final pdf = pw.Document();

  // تحميل الخطوط العربية
  final arabicFont = await PdfGoogleFonts.cairoRegular();
  final arabicFontBold = await PdfGoogleFonts.cairoBold();

  String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
      // الهيدر يظهر في بداية كل صفحة جديدة تلقائياً
      header: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 15),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "تقرير الأصناف المخزنية",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    "تاريخ التقرير: $todayDate",
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.Text(
                "إجمالي الأصناف: ${itemsList.length}",
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      // بناء محتوى التقرير
      build: (context) {
        return [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey100,
              ),
              headerHeight: 30,
              cellHeight: 25,
              cellAlignment: pw.Alignment.centerRight,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              // ترتيب الأعمدة من اليمين لليسار (الاسم أولاً)
              headers: [
                'ملاحظات',
                'المخزن',
                'الكمية',
                'الوحدة',
                'كود الصنف',
                'اسم الصنف',
              ],
              data: itemsList
                  .map(
                    (item) => [
                      item['notes']?.toString() ?? "---",
                      item['location']?.toString() ?? "---",
                      item['quantity']?.toString() ?? "0",
                      item['unit']?.toString() ?? "---",
                      item['sku']?.toString() ?? "---",
                      item['name']?.toString() ?? "---",
                    ],
                  )
                  .toList(),
              // إعدادات إضافية لضمان استقرار الجدول عبر الصفحات
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(2.5),
              },
            ),
          ),
        ];
      },
      // تذييل الصفحة
      footer: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            "صفحة ${context.pageNumber} من ${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ),
      ),
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'تقرير_المخزن_$todayDate.pdf',
  );
  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'تقرير_المخزن_$todayDate.pdf',
  );
}
