import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:url_launcher/url_launcher.dart';
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
    required this.isEditMode,
  });

  final String groupId;
  final bool isFromInvoice;
  final String invoiceType;
  final List<Map> itemsSale;
  final List<Map> itemsPruchase;
  final bool isEditMode;

  static const String screenroute = '/customersSuppliers';

  @override
  State<CustomersSuppliers> createState() => _CustomersSuppliersState();
}

class _CustomersSuppliersState extends State<CustomersSuppliers> {
  final _searchController = TextEditingController();
  List<PartyModel> list = [];
  String searchText = '';
  PartyType? filterType;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  CollectionReference<Map<String, dynamic>> get _persons => FirebaseFirestore
      .instance
      .collection('customersSuppliers')
      .doc(widget.groupId)
      .collection('persons');

  @override
  void initState() {
    super.initState();
    _listenToData();
  }

  void _listenToData() {
    _subscription = _persons
        .orderBy('name')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.docs.map((doc) {
            final d = doc.data();
            return PartyModel(
              id: doc.id,
              name: (d['name'] ?? '').toString(),
              phone: (d['phone'] ?? '').toString(),
              address: (d['address'] ?? '').toString(),
              type: d['type'] == 'customer'
                  ? PartyType.customer
                  : PartyType.supplier,
              notes: (d['notes'] ?? '').toString(),
            );
          }).toList();

          if (mounted) setState(() => list = data);
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<PartyModel> get filteredList {
    final search = searchText.trim().toLowerCase();
    return list.where((party) {
      final matchesSearch =
          party.name.toLowerCase().contains(search) ||
          party.phone.toLowerCase().contains(search) ||
          party.address.toLowerCase().contains(search);
      final matchesType = filterType == null || party.type == filterType;
      return matchesSearch && matchesType;
    }).toList();
  }

  Future<void> _showPartySheet({PartyModel? party}) async {
    final isEditing = party != null;
    final name = TextEditingController(text: party?.name ?? '');
    final address = TextEditingController(text: party?.address ?? '');
    final notes = TextEditingController(text: party?.notes ?? '');
    // يتم تخزين الرقم كاملًا بصيغة دولية، مثل: +201012345678.
    String completePhone = party?.phone ?? '';
    PartyType type = party?.type ?? PartyType.customer;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isEditing ? 'تعديل البيانات' : 'إضافة عميل / مورد',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _input(name, 'الاسم', Icons.person_outline),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: IntlPhoneField(
                      initialCountryCode: 'EG',
                      initialValue: party?.phone.isNotEmpty == true
                          ? party!.phone
                          : null,
                      decoration: _fieldDecoration(
                        'رقم الموبايل',
                        Icons.phone_outlined,
                      ).copyWith(hintText: '10xxxxxxxx'),
                      onChanged: (phoneNumber) {
                        completePhone = phoneNumber.completeNumber;
                      },
                    ),
                  ),
                  _input(address, 'العنوان', Icons.location_on_outlined),
                  _input(
                    notes,
                    'ملاحظات',
                    Icons.notes_outlined,
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<PartyType>(
                    value: type,
                    decoration: _fieldDecoration(
                      'النوع',
                      Icons.category_outlined,
                    ),
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
                    onChanged: (value) {
                      if (value != null) setModalState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      icon: Icon(isEditing ? Icons.save_outlined : Icons.add),
                      label: Text(isEditing ? 'حفظ التعديلات' : 'حفظ البيانات'),
                      onPressed: () async {
                        if (name.text.trim().isEmpty) return;
                        Navigator.pop(context);
                        await _saveParty(
                          party: party,
                          name: name.text,
                          phone: completePhone,
                          address: address.text,
                          notes: notes.text,
                          type: type,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );

    // لا يتم استدعاء dispose هنا؛ لأن الـBottomSheet قد يكون ما زال في
    // مرحلة الإغلاق وإعادة بناء الـTextField. ستُجمع الكنترولرات تلقائيًا
    // بعد انتهاء استخدام الـBottomSheet، وتجنب ذلك خطأ "used after disposed".
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xfff8fafc),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xff2563eb), width: 1.5),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: _fieldDecoration(label, icon),
      ),
    );
  }

  Future<void> _saveParty({
    PartyModel? party,
    required String name,
    required String phone,
    required String address,
    required String notes,
    required PartyType type,
  }) async {
    final data = {
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'type': type == PartyType.customer ? 'customer' : 'supplier',
      'notes': notes.trim(),
      if (party == null) 'createdAt': Timestamp.now(),
    };

    if (party == null) {
      await _persons.add(data);
    } else {
      await _persons.doc(party.id).update(data);
    }

    await FirebaseFirestore.instance
        .collection('customersSuppliers')
        .doc(widget.groupId)
        .set({
          'lastUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Widget _filterChip(String text, PartyType? type) {
    final selected = filterType == type;
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => setState(() => filterType = type),
      selectedColor: const Color(0xffdbeafe),
      labelStyle: TextStyle(
        color: selected ? const Color(0xff1d4ed8) : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? Colors.transparent : Colors.grey.shade300,
      ),
    );
  }

  Future<void> _openLink(String value, {required bool whatsapp}) async {
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    final uri = whatsapp
        ? Uri.parse('https://wa.me/${digits.replaceFirst('+', '')}')
        : Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(.25)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(PartyModel item) {
    final isCustomer = item.type == PartyType.customer;
    final accent = isCustomer
        ? const Color(0xff059669)
        : const Color(0xffea580c);
    final hasPhone = item.phone.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openParty(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: accent.withOpacity(.12),
                    child: Icon(
                      isCustomer ? Icons.person : Icons.storefront,
                      color: accent,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.phone.isEmpty ? 'لا يوجد رقم هاتف' : item.phone,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        if (item.address.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(.11),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCustomer ? 'عميل' : 'مورد',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_horiz),
                        onSelected: (value) {
                          if (value == 'edit') _showPartySheet(party: item);
                          if (value == 'delete') _confirmDelete(item);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('تعديل')),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (hasPhone) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _actionButton(
                      icon: Icons.phone_outlined,
                      label: 'اتصال',
                      color: const Color(0xff2563eb),
                      onPressed: () => _openLink(item.phone, whatsapp: false),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.chat_outlined,
                      label: 'واتساب',
                      color: const Color(0xff16a34a),
                      onPressed: () => _openLink(item.phone, whatsapp: true),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.edit_outlined,
                      label: 'تعديل',
                      color: const Color(0xff7c3aed),
                      onPressed: () => _showPartySheet(party: item),
                    ),
                  ],
                ),
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _showPartySheet(party: item),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('إضافة رقم / تعديل البيانات'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openParty(PartyModel item) async {
    if (widget.isFromInvoice) {
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
            isFormStore: false,
            isEditMode: widget.isEditMode,
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
  }

  Future<void> _confirmDelete(PartyModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف ${item.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _persons.doc(item.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff5f7fb),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: const Text(
            'العملاء والموردين',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'إضافة',
              onPressed: () => _showPartySheet(),
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showPartySheet(),
          icon: const Icon(Icons.add),
          label: const Text('إضافة جديد'),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff1d4ed8), Color(0xff2563eb)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة جهات التعامل',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'تابع بيانات العملاء والموردين بسهولة',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.groups_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => searchText = value),
                decoration:
                    _fieldDecoration(
                      'ابحث بالاسم أو الهاتف أو العنوان',
                      Icons.search,
                    ).copyWith(
                      suffixIcon: searchText.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => searchText = '');
                              },
                            ),
                    ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    _filterChip('الكل', null),
                    _filterChip('عملاء', PartyType.customer),
                    _filterChip('موردين', PartyType.supplier),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'لا توجد بيانات مطابقة',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredList.length,
                        itemBuilder: (_, index) =>
                            _buildCard(filteredList[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
