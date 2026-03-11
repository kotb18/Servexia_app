import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/addTask.dart';
// import 'package:maintenance/addTask.dart'; // Assuming this is not directly needed for the UI redesign

class AddReportPage extends StatefulWidget {
  final String groupId;
  static const String screenroute = 'reportPage';

  const AddReportPage({super.key, required this.groupId});

  @override
  State<AddReportPage> createState() => _AddReportPageState();
}

class _AddReportPageState extends State<AddReportPage> {
  final _descController = TextEditingController();

  String? selectedPriority = "عادي";
  String? selectedAssetId;
  String? selectedAssetName;
  String? selectedSite;
  String? selectedLocation;
  String? selectedNo;

  bool loading = false;

  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // Placeholder for sendTopicNotification - replace with actual implementation

  Future<void> submitReport() async {
    if (selectedAssetId == null || _descController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("اكمل البيانات أولاً")));
      return;
    }

    setState(() => loading = true);

    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.groupId)
          .collection('members')
          .doc(uid)
          .get();

      final name = memberDoc['name'];
      final job = memberDoc['job'];

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.groupId)
          .set({'groupId': widget.groupId}, SetOptions(merge: true));

      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.groupId)
          .collection('items')
          .doc();

      await taskRef.set({
        'id': taskRef.id,
        'title': 'ابلاغ عن عطل',
        'description': _descController.text.trim(),
        'priority': selectedPriority,
        'assignedTo': [
          {'name': name, 'id': uid, 'job': job},
        ],
        'assets': [
          {
            'assetId': selectedAssetId,
            'site': selectedSite,
            'location': selectedLocation,
            'name': selectedAssetName,
            'number': selectedNo,
          },
        ],
        'assetIds': [selectedAssetId],
        'taskDateTime': FieldValue.serverTimestamp(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isReport': true,
        'comments': [],
      });
      await sendTopicNotification(
        topic: widget.groupId,
        title: 'بلاغ بعطل',
        body: 'بلاغ بعطل  ${_descController.text.trim()}',
      );
    } catch (e) {
      print('Error submitting report: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء إرسال البلاغ: $e')));
    } finally {
      setState(() => loading = false);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("بلاغ عطل جديد"),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle("تفاصيل المعدة"),
            const SizedBox(height: 10),
            _buildFiltersCard(),

            const SizedBox(height: 20),

            if (selectedAssetId != null) ...[
              _buildSectionTitle("ملخص المعدة المختارة"),
              const SizedBox(height: 10),
              _buildSummaryBox(),
              const SizedBox(height: 20),
            ],

            _buildSectionTitle("وصف البلاغ ودرجة الخطورة"),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: "وصف العطل بالتفصيل",
                hintText: "الرجاء وصف العطل الذي واجهته هنا...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: selectedPriority,
              decoration: InputDecoration(
                labelText: "درجة الخطورة",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
              items: const [
                DropdownMenuItem(value: "عادي", child: Text("عادي")),
                DropdownMenuItem(value: "عاجل", child: Text("عاجل")),
                DropdownMenuItem(value: "طارئ", child: Text("طارئ")),
              ],
              onChanged: (value) {
                setState(() => selectedPriority = value);
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor, // Use primary color for button
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 5,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "إرسال البلاغ",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSiteDropdown(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: selectedSite != null
                  ? Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildLocationDropdown(),
                      ],
                    )
                  : const SizedBox.shrink(), // Use SizedBox.shrink() for better performance
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: selectedLocation != null
                  ? Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildAssetNameDropdown(),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: selectedAssetName != null
                  ? Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildAssetNumberDropdown(),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return DropdownButtonFormField(
            decoration: InputDecoration(labelText: "لا توجد مواقع متاحة"),
            items: [],
            onChanged: null,
          );
        }

        final sites = snap.data!.docs
            .map((e) => e['site'] as String)
            .toSet()
            .toList();

        return DropdownButtonFormField<String>(
          value: selectedSite,
          decoration: InputDecoration(
            labelText: "اختر الموقع",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          hint: const Text("اختر الموقع"),
          items: sites
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            setState(() {
              selectedSite = v;
              selectedLocation = null;
              selectedAssetName = null;
              selectedAssetId = null;
              selectedNo = null;
            });
          },
        );
      },
    );
  }

  Widget _buildLocationDropdown() {
    if (selectedSite == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .where('site', isEqualTo: selectedSite)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return DropdownButtonFormField(
            decoration: InputDecoration(labelText: "لا توجد أماكن متاحة"),
            items: [],
            onChanged: null,
          );
        }

        final locations = snap.data!.docs
            .map((e) => e['location'] as String)
            .toSet()
            .toList();

        return DropdownButtonFormField<String>(
          value: selectedLocation,
          decoration: InputDecoration(
            labelText: "اختر المكان",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          hint: const Text("اختر المكان"),
          items: locations
              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
              .toList(),
          onChanged: (v) {
            setState(() {
              selectedLocation = v;
              selectedAssetName = null;
              selectedAssetId = null;
              selectedNo = null;
            });
          },
        );
      },
    );
  }

  Widget _buildAssetNameDropdown() {
    if (selectedSite == null || selectedLocation == null)
      return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .where('site', isEqualTo: selectedSite)
          .where('location', isEqualTo: selectedLocation)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return DropdownButtonFormField(
            decoration: InputDecoration(labelText: "لا توجد معدات متاحة"),
            items: [],
            onChanged: null,
          );
        }

        final names = snap.data!.docs
            .map((e) => e['name'] as String)
            .toSet()
            .toList();

        return DropdownButtonFormField<String>(
          value: selectedAssetName,
          decoration: InputDecoration(
            labelText: "اختر اسم المعدة",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          hint: const Text("اختر اسم المعدة"),
          items: names
              .map((n) => DropdownMenuItem(value: n, child: Text(n)))
              .toList(),
          onChanged: (v) {
            setState(() {
              selectedAssetName = v;
              selectedAssetId = null;
              selectedNo = null;
            });
          },
        );
      },
    );
  }

  Widget _buildAssetNumberDropdown() {
    if (selectedSite == null ||
        selectedLocation == null ||
        selectedAssetName == null)
      return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .where('site', isEqualTo: selectedSite)
          .where('location', isEqualTo: selectedLocation)
          .where('name', isEqualTo: selectedAssetName)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return DropdownButtonFormField(
            decoration: InputDecoration(labelText: "لا توجد أرقام معدات متاحة"),
            items: [],
            onChanged: null,
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedAssetId,
          decoration: InputDecoration(
            labelText: "اختر رقم المعدة",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          hint: const Text("اختر رقم المعدة"),
          items: snap.data!.docs.map((doc) {
            return DropdownMenuItem(
              value: doc.id,
              child: Text(doc['number'] ?? 'بدون رقم'),
            );
          }).toList(),
          onChanged: (v) {
            final selectedDoc = snap.data!.docs.firstWhere(
              (doc) => doc.id == v,
            );

            setState(() {
              selectedAssetId = v;
              selectedNo = selectedDoc['number'] ?? 'بدون رقم';
            });
          },
        );
      },
    );
  }

  Widget _buildSummaryBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(
            "الموقع:",
            selectedSite ?? 'غير محدد',
            Icons.location_on,
          ),
          _buildSummaryRow(
            "المكان:",
            selectedLocation ?? 'غير محدد',
            Icons.place,
          ),
          _buildSummaryRow(
            "اسم المعدة:",
            selectedAssetName ?? 'غير محدد',
            Icons.build,
          ),
          _buildSummaryRow("رقم المعدة:", selectedNo ?? 'غير محدد', Icons.tag),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 8),
          Text('$label $value', style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
