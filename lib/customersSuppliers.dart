import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/invoicePage.dart';
import 'package:maintenance/myInvoices.dart';

enum PartyType { customer, supplier }

class PartyModel {
  String id;
  String name;
  String phone;
  String address;
  PartyType type;
  String notes;

  PartyModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.type,
    required this.notes,
  });
}

class CustomersSuppliers extends StatefulWidget {
  const CustomersSuppliers({
    super.key,
    required this.groupId,
    required this.isFromInvoice,
    required this.invoiceType,
    required this.itemsSale,
    required this.itemsPruchase,
  });
  final String groupId;
  final bool isFromInvoice;
  final String invoiceType;
  final List<Map> itemsSale;
  final List<Map> itemsPruchase;
  static const String screenroute = '/customersSuppliers';

  @override
  State<CustomersSuppliers> createState() => _CustomersSuppliersState();
}

class _CustomersSuppliersState extends State<CustomersSuppliers> {
  List<PartyModel> list = [];
  String searchText = '';
  PartyType? filterType;

  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _listenToData();
  }

  void _listenToData() {
    _subscription = FirebaseFirestore.instance
        .collection('customersSuppliers')
        .doc(widget.groupId)
        .collection('persons')
        .orderBy('name')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          print("🔥 Firestore Updated: ${snapshot.docs.length}");
          final data = snapshot.docs.map((doc) {
            final d = doc.data();
            print(doc.id);
            return PartyModel(
              id: doc.id,
              name: d['name'] ?? '',
              phone: d['phone'] ?? '',
              address: d['address'] ?? '',
              type: d['type'] == 'customer'
                  ? PartyType.customer
                  : PartyType.supplier,
              notes: d['notes'] ?? '',
            );
          }).toList();

          setState(() => list = data);
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<PartyModel> get filteredList {
    return list.where((p) {
      final search = searchText.toLowerCase();

      final matchesSearch =
          p.name.toLowerCase().contains(search) ||
          p.phone.toLowerCase().contains(search);

      final matchesType = filterType == null || p.type == filterType;

      return matchesSearch && matchesType;
    }).toList();
  }

  // ================= ADD =================
  void showAddDialog() {
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final notes = TextEditingController();

    PartyType type = PartyType.customer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (_, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      'إضافة عميل / مورد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    _input(name, 'الاسم', TextInputType.text),
                    _input(phone, 'الموبايل', TextInputType.phone),
                    _input(address, 'العنوان', TextInputType.text),

                    DropdownButtonFormField(
                      initialValue: type,
                      items: const [
                        DropdownMenuItem(
                          value: PartyType.customer,
                          child: Text('عميل'),
                        ),
                        DropdownMenuItem(
                          value: PartyType.supplier,
                          child: Text('مورد'),
                        ),
                      ],
                      onChanged: (v) => setModalState(() => type = v!),
                      decoration: const InputDecoration(labelText: 'النوع'),
                    ),

                    _input(notes, 'ملاحظات', TextInputType.multiline),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      onPressed: () async {
                        if (name.text.isEmpty) return;
                        Navigator.pop(context);
                        await FirebaseFirestore.instance
                            .collection('customersSuppliers')
                            .doc(widget.groupId)
                            .collection('persons')
                            .add({
                              'name': name.text,
                              'phone': phone.text,
                              'address': address.text,
                              'type': type == PartyType.customer
                                  ? 'customer'
                                  : 'supplier',
                              'notes': notes.text,
                              'createdAt': Timestamp.now(),
                            });
                      },
                      child: const Text('حفظ'),
                    ),

                    const SizedBox(height: 50),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _input(TextEditingController c, String label, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ================= UI =================

  Widget buildFilters() {
    return Wrap(
      spacing: 8,
      children: [
        _chip('الكل', null),
        _chip('عملاء', PartyType.customer),
        _chip('موردين', PartyType.supplier),
      ],
    );
  }

  Widget _chip(String text, PartyType? type) {
    final selected = filterType == type;

    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) {
        setState(() => filterType = type);
      },
    );
  }

  Widget buildCard(PartyModel item) {
    final isCustomer = item.type == PartyType.customer;

    return InkWell(
      onTap: () async {
        if (widget.isFromInvoice) {
          print("Selected ${item.id} for invoice");
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => InvoicePage(
                groupId: widget.groupId,
                itemsSale: widget.itemsSale,
                itemsPurchase: widget.itemsPruchase,
                name: item.name,
                phone: item.phone,
                address: item.address,
                customerId: item.id,
                isFromConstCustomers: true,
                isFromWorkSpace: false,
                type: widget.invoiceType,
              ),
            ),
          );
        } else {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MyInvoicesPage(
                customerId: item.id,
                customerName: item.name,
                groupId: widget.groupId,
                isSelectionMode: false,
                onInvoiceSelected: null,
                isFromCustomerScreen: true,
              ),
            ),
          );
        }
      },
      child: Stack(
        children: [
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: isCustomer ? Colors.green : Colors.orange,
                child: Icon(
                  isCustomer ? Icons.person : Icons.store,
                  color: Colors.white,
                ),
              ),
              title: Text(item.name),
              subtitle: Text('${item.phone} • ${item.address}'),
              trailing: Text(
                isCustomer ? 'عميل' : 'مورد',
                style: TextStyle(
                  color: isCustomer ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // ❌ زر الحذف (X)
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              onTap: () => confirmDelete(item),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 144, 31, 23),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(5),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void confirmDelete(PartyModel item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف ${item.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await deleteParty(item.id);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> deleteParty(String id) async {
    await FirebaseFirestore.instance
        .collection('customersSuppliers')
        .doc(widget.groupId)
        .collection('persons')
        .doc(id)
        .delete();
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العملاء والموردين')),

      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        child: const Icon(Icons.add),
      ),

      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'بحث بالاسم او الهاتف...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (v) => setState(() => searchText = v),
            ),

            const SizedBox(height: 10),

            buildFilters(),

            const SizedBox(height: 10),

            Expanded(
              child: filteredList.isEmpty
                  ? const Center(child: Text('لا يوجد بيانات'))
                  : ListView.builder(
                      itemCount: filteredList.length,
                      itemBuilder: (_, i) => buildCard(filteredList[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
