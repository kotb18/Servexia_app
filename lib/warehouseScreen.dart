import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/wareHouseItemeMovement.dart';

class StoreScreen extends StatefulWidget {
  final String groupId;
  const StoreScreen({super.key, required this.groupId});
  static const String screenroute = 'StoreScreen';

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String? selectedLocation; // null = لم يتم اختيار فلتر
  String searchText = '';
  bool deletedItems = false;
  final searchController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
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
                          }).toList(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// سويتش المحذوفات
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
                        final id = doc.id;

                        return GestureDetector(
                          onTap: () async {
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
                                          Text(
                                            data['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
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
                                                    BorderRadius.circular(8),
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
                                      Text(
                                        '${data['quantity']} ${data['unit']}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
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
