import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

List assetIds = [];
String? selectedAssetId;
List<dynamic> constDesc = [];

class AddTaskScreen extends StatefulWidget {
  final String groupId;
  final bool fromConstTasks;
  final TextEditingController title;
  final TextEditingController description;
  const AddTaskScreen({
    super.key,
    required this.groupId,
    required this.fromConstTasks,
    required this.title,
    required this.description,
  });
  static const String screenroute = 'addTask';

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descController = TextEditingController();

  bool loading = false;

  // أعضاء الفريق
  List<Map<String, dynamic>> members = [];
  final Set<String> selectedMembers = {};

  // اختيار المعدات
  String? selectedSite;
  String? selectedLocation;
  String? selectedAssetName;
  final List<Map<String, dynamic>> selectedAssets = [];

  // تاريخ ووقت المهمة
  DateTime? taskDateTime;

  @override
  void initState() {
    super.initState();
    assetIds.clear();
    selectedAssetId = null;
    _loadMembers();
  }

  // 1. دالة لجلب الاقتراحات من Firebase
  Future<List<String>> getTaskSuggestions() async {
    try {
      // جلب المستند الخاص بالمجموعة
      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.groupId)
          .get();

      if (snap.exists && snap.data() != null) {
        Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
        List<dynamic> constTasks = data['constTasks'] ?? [];
        constDesc = constTasks
            .map((e) => e['description'].toString())
            .toSet()
            .toList();

        // استخراج العناوين فقط وتحويلها لقائمة نصوص فريدة
        return constTasks.map((e) => e['title'].toString()).toSet().toList();
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
    }
    return [];
  }

  // 2. تحديث حقل "اسم المهمة" داخل الـ BottomSheet أو الـ Dialog
  Widget _buildTaskTitleField({
    String? Function(String?)? validator,
    Function()? onTap,
  }) {
    return FutureBuilder<List<String>>(
      future: getTaskSuggestions(),
      builder: (context, snapshot) {
        List<String> suggestions = snapshot.data ?? [];
        print(
          '000000000000000000000000000000000000000000000000000000000000000000000000 $suggestions',
        );
        return Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            // تصفية الاقتراحات بناءً على ما يكتبه المستخدم
            return suggestions.where((String option) {
              return option.contains(textEditingValue.text);
            });
          },
          onSelected: (String selection) {
            titleController.text = selection;
            int index = suggestions.indexOf(selection);
            if (index != -1 && index < constDesc.length) {
              descController.text = constDesc[index];
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            // ربط الكنترولر الخاص بك
            controller.text = titleController.text;
            controller.addListener(() {
              titleController.text = controller.text;
            });

            return TextFormField(
              controller: widget.fromConstTasks ? widget.title : controller,
              focusNode: focusNode,
              validator: validator,
              onTap: onTap,
              style: TextStyle(color: Colors.blue),
              decoration: InputDecoration(
                labelText: 'اسم المهمة',
                prefixIcon: const Icon(
                  Icons.task_alt,
                  color: Color(0xFF1A237E),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: suggestions.isNotEmpty
                    ? const Icon(Icons.arrow_drop_down, color: Colors.grey)
                    : null,
              ),
            );
          },
          // تصميم قائمة الاقتراحات التي تظهر تحت الحقل
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topRight, // ليتناسب مع اللغة العربية
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width:
                      MediaQuery.of(context).size.width - 40, // نفس عرض الحقل
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(
                          option,
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadMembers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.groupId)
        .collection('members')
        .get();

    final list = snapshot.docs.map((doc) => doc.data()).toList();

    setState(() {
      members = list
          .where((m) => m['confirm'] == true)
          .map<Map<String, dynamic>>(
            (m) => {'id': m['id'], 'name': m['name'], 'job': m['job']},
          )
          .toList();
    });
  }

  /// اختيار تاريخ ووقت المهمة
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E88E5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1E88E5)),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    setState(() {
      taskDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedMembers.isEmpty) {
      _snack('اختر عضو واحد على الأقل');
      return;
    }

    if (assetIds.isEmpty) {
      _snack('اختر المعدة ');
      return;
    }

    if (taskDateTime == null) {
      _snack('اختر تاريخ ووقت المهمة');
      return;
    }

    setState(() => loading = true);
    try {
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
        'title': widget.fromConstTasks
            ? widget.title.text.trim()
            : titleController.text.trim(),
        'description': widget.fromConstTasks
            ? widget.description.text.trim()
            : descController.text.trim(),
        'assignedTo': members
            .where((m) => selectedMembers.contains(m['id']))
            .toList(),
        'assets': selectedAssets,
        'assetIds': assetIds,
        'taskDateTime': Timestamp.fromDate(taskDateTime!),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isReport': false,
        'comments': [],
      });

      await sendTopicNotification(
        topic: widget.groupId,
        title: 'مهمة جديدة',
        body:
            'تم إضافة مهمة جديدة: ${widget.fromConstTasks ? widget.title.text.trim() : titleController.text.trim()}',
      );

      if (mounted && widget.fromConstTasks) {
        Navigator.pop(context);
        Navigator.pop(context);
      } else if (mounted)
        Navigator.pop(context);
    } catch (e) {
      _snack('حدث خطأ أثناء الحفظ');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E88E5), size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Function() onTap,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      onTap: onTap,
      style: TextStyle(color: Colors.blue),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _membersDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('المكلفون بالمهمة', Icons.people_outline),
        InkWell(
          onTap: () async {
            final selected = await showDialog<Set<String>>(
              context: context,
              builder: (context) {
                final tempSelected = Set<String>.from(selectedMembers);
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  title: const Text(
                    'اختر أعضاء المهمة',
                    textAlign: TextAlign.center,
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: StatefulBuilder(
                      builder: (context, setDialogState) {
                        return ListView(
                          shrinkWrap: true,
                          children: members.map((m) {
                            return CheckboxListTile(
                              activeColor: const Color(0xFF1E88E5),
                              value: tempSelected.contains(m['id']),
                              title: Text(m['name']),
                              subtitle: Text(
                                m['job'] ?? '',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onChanged: (v) {
                                setDialogState(() {
                                  if (v == true) {
                                    tempSelected.add(m['id']);
                                  } else {
                                    tempSelected.remove(m['id']);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, tempSelected),
                      child: const Text(
                        'تأكيد',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            );

            if (selected != null) {
              setState(() {
                selectedMembers.clear();
                selectedMembers.addAll(selected);
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_add_alt_1, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedMembers.isEmpty
                        ? 'اختر الأعضاء'
                        : members
                              .where((m) => selectedMembers.contains(m['id']))
                              .map((m) => m['name'])
                              .join(', '),
                    style: TextStyle(
                      color: selectedMembers.isEmpty
                          ? Colors.grey.shade600
                          : Colors.black87,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'إضافة مهمة جديدة',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ConstTasksManager(groupId: widget.groupId),
                          ),
                        );
                        //  await getTaskSuggestions();
                      },
                      label: Text('المهام الثابتة'),
                    ),
                    const SizedBox(height: 10),
                    _buildTaskTitleField(
                      validator: (v) =>
                          v == null || v.isEmpty ? 'أدخل العنوان' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: widget.fromConstTasks
                          ? widget.description
                          : descController,
                      label: 'وصف المهمة',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    _membersDropdown(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),
                    _sectionTitle(
                      'المعدات المرتبطة',
                      Icons.settings_suggest_outlined,
                    ),
                    _siteDropdown(),
                    if (selectedSite != null) ...[
                      const SizedBox(height: 12),
                      _locationDropdown(),
                    ],
                    if (selectedLocation != null) ...[
                      const SizedBox(height: 12),
                      _assetNameDropdown(),
                    ],
                    if (selectedAssetName != null) ...[
                      const SizedBox(height: 12),
                      _buildAssetNumberDropdown(),
                    ],
                    const SizedBox(height: 12),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),
                    _sectionTitle('التوقيت', Icons.calendar_month_outlined),
                    InkWell(
                      onTap: _pickDateTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Color(0xFF1E88E5),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              taskDateTime == null
                                  ? 'اختر تاريخ ووقت المهمة'
                                  : DateFormat(
                                      'yyyy/MM/dd - hh:mm a',
                                    ).format(taskDateTime!),
                              style: TextStyle(
                                fontSize: 15,
                                color: taskDateTime == null
                                    ? Colors.grey.shade600
                                    : Colors.black87,
                                fontWeight: taskDateTime == null
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.edit_calendar,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _saveTask,
                        child: const Text(
                          'حفظ المهمة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _siteDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();

        final sites = snap.data!.docs
            .map((e) => e['site'] as String)
            .toSet()
            .toList();

        return _customDropdown(
          hint: 'اختر الموقع',
          value: selectedSite,
          items: sites,
          onChanged: (v) {
            setState(() {
              selectedSite = v;
              selectedLocation = null;
              selectedAssetName = null;
              selectedAssets.clear();
              assetIds.clear();
            });
          },
        );
      },
    );
  }

  Widget _locationDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .where('site', isEqualTo: selectedSite)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final locations = snap.data!.docs
            .map((e) => e['location'] as String)
            .toSet()
            .toList();

        return _customDropdown(
          hint: 'اختر المكان',
          value: selectedLocation,
          items: locations,
          onChanged: (v) {
            setState(() {
              selectedLocation = v;
              selectedAssetName = null;
              selectedAssets.clear();
              assetIds.clear();
            });
          },
        );
      },
    );
  }

  Widget _assetNameDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assets')
          .doc(widget.groupId)
          .collection('items')
          .where('site', isEqualTo: selectedSite)
          .where('location', isEqualTo: selectedLocation)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final names = snap.data!.docs
            .map((e) => e['name'] as String)
            .toSet()
            .toList();

        return _customDropdown(
          hint: 'اختر اسم المعدة',
          value: selectedAssetName,
          items: names,
          onChanged: (v) {
            setState(() {
              selectedAssetName = v;
              selectedAssets.clear();
              assetIds.clear();
            });
          },
        );
      },
    );
  }

  Widget _buildAssetNumberDropdown() {
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
        if (!snap.hasData) return const SizedBox();

        final docs = snap.data!.docs;

        return DropdownButtonFormField<String>(
          decoration: _dropdownDecoration('اختر رقم المعدة'),
          initialValue: selectedAssetId,
          items: docs.map((doc) {
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(doc['number']?.toString() ?? 'بدون رقم'),
            );
          }).toList(),
          onChanged: (String? v) {
            if (v == null) return;
            final selectedDoc = docs.firstWhere((doc) => doc.id == v);
            setState(() {
              selectedAssetId = v;
              assetIds
                ..clear()
                ..add(v);
              selectedAssets
                ..clear()
                ..add({
                  'assetId': selectedDoc.id,
                  'site': selectedDoc['site'],
                  'location': selectedDoc['location'],
                  'name': selectedDoc['name'],
                  'number': selectedDoc['number'],
                });
            });
          },
        );
      },
    );
  }

  Widget _customDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: _dropdownDecoration(hint),
      initialValue: value,
      items: items
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
      ),
    );
  }
}

// --- FCM Functions (Keep original logic) ---

Future<String> getAccessToken() async {
  const serviceAccount = {
    "client_email":
        "firebase-adminsdk-fbsvc@maintenance-b7282.iam.gserviceaccount.com",
    "private_key":
        "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC9cKtKpsZcrdxM\nq1nXAX9lK64kvOk2r8SELU2IghVhInV7aPDruKyUbM0Fr2hyrEBKw+QgFHg7W4GR\nSstTirBrAelDWTVI2ARhnkNuHfPyAQMQni918S4tbqTB4On0ZqiSiQ7lit134tQF\n7bQ5FzbG9RkTA58nn0NpcZtA0dUc8HisY9yLma5IjixAlSJv87iDBXb+CYt0V/+T\nAL+Fm1soZ267Y6dXORL4bJYqmFcwEctJiAsYqSTgkiBdOulYV29ZFCq9C3JXtA4/\nHGW8xq976gaykoVQ2vzyReYNR8fIizRk/mWY/auF763MhSdKFpFSnTWvDm9lFRSQ\nAwiPLGcpAgMBAAECggEAHRaCxriq9qofjIo3BkONmyxE1hFHwgTlKOKH6DEJNVwE\nLAnmDFvT7Ap0xK21XP5D9Pb1PVPHTl3znCqe49oE0rl9ZsD45JF+wrp5YhwpS/yJ\nyvBvGy4ISCOYGsj9Q3DL64wuBGL5NKJYqfxg0u9UkuIpknjY5E2ZHUS7cQ2HKqUi\nQgVbKd+Vx2qy2AjVyp3L+3CoJ3PslTE7NvsS9uT2+1T/LDbizN2ufGK4OyDmg4Wc\n/y1qP/MYHQa+pM+lsO7i+0OLuV5EDVBUB4OT/nVwY6HYm2lzgr21/UUztmCNYQ8Z\nyfOGXH4uQYcXJX0U/VLXRzbrBbUpnWAMlochXyYLsQKBgQDlrNOebzmGkMsIOVj8\ngDmFYa/cn/4Wlemk/Fv7dkKVVIa6CShdowLXAC6n2FvnMKpsC83tYRe8FmwKCLbh\nrEtPKCvuf36cvpmkef/8jjmLc7yoVW7qCFNGHdxrW6nKbeqyB72tDoTXFvgXOaNl\nIxYzTr2B3jNp6QOYNTeSLLuTJQKBgQDTJ0Jd7httA/40hR5wYxTgi/ymjNoTvK1i\nFniNkaAb4fjPU4Sa1mqBAuvfQ8hxASfpgumgasg6+DlG9O5n+NxToFhfuyV2STz6\nHncds4OHRUCExXDEahrdS4qaLGhx+siHoQQqljYbmIbffqbG5jX0FSr4+HXj6nw7\nV2sf7uiGtQKBgEvRC2JnkPPM5FjopWlk4pgXMTiBUB0gi6o87BhMZ5pn9rl+wGZ4\noz1aAAzELUJaHEfida4AuRcLx8pgKg7BE3Mj7ayjRaZ0fL+AznIOeQyBvitLWHvF\nF8gzn0mJTrlWI311dLWl71AZcvgnvLpsJK33NjOiqBI0K02Zc6i7P4hJAoGAeNwX\n2LvZZuTKNDWd3qZX5M87pfkpOfLdKy/BgQbBpjQJvmIHnLjt7TpG2Fxr9oK63aXZ\nI8D7KwW5gyve6hQ/yH4XF3R/VN1G0cNuWsnNlzfEXjrE+SfiiJgclXKltdfdwAQh\n5l5kShdb28EapO5QI42aMzfEAtjMkwrOflC5N6ECgYAJBqWDPTuQJR6lG8LC2fNQ\nODtFJGGhxk/YA7JI4JWjE7RimVT7rphnoSMqUusQiis4UkvP4zGYWda5Bq170J25\nzannFLP/fTkPL8gDWOHOFTqU93VSmqVHAKVQbllXcuVHgehfv5zct9KoVAXoQONG\nKYjV1i62aKLsRCFtlC35Rg==\n-----END PRIVATE KEY-----\n",
    "token_uri": "https://oauth2.googleapis.com/token",
  };

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final jwt = JWT({
    "iss": serviceAccount['client_email'],
    "scope": "https://www.googleapis.com/auth/firebase.messaging",
    "aud": serviceAccount['token_uri'],
    "iat": now,
    "exp": now + 3600,
  });

  final signedJwt = jwt.sign(
    RSAPrivateKey(serviceAccount['private_key']!),
    algorithm: JWTAlgorithm.RS256,
  );

  final response = await http.post(
    Uri.parse(serviceAccount['token_uri']!),
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: {
      "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
      "assertion": signedJwt,
    },
  );

  final data = jsonDecode(response.body);
  if (data['access_token'] == null) {
    throw Exception("Failed to get access token: ${response.body}");
  }
  return data['access_token'];
}

Future<void> sendTopicNotification({
  required String topic,
  required String title,
  required String body,
}) async {
  print(
    "Sending notification to topic: $topic with title: $title and body: $body",
  );
  final accessToken = await getAccessToken();
  print("Obtained access token: $accessToken");
  final url = Uri.parse(
    "https://fcm.googleapis.com/v1/projects/maintenance-b7282/messages:send",
  );

  await http.post(
    url,
    headers: {
      "Authorization": "Bearer $accessToken",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "message": {
        "topic": topic,
        "notification": {"title": title, "body": body},
        "data": {"route": "home"},
        "android": {
          "priority": "HIGH", // ملاحظة: يجب أن تكون HIGH وليس high
          "notification": {"channel_id": "high_importance_channel"},
        },
      },
    }),
  );
}

Future<void> sendNotificationToDevice({
  required String deviceToken, // FCM Device Token
  required String title,
  required String body,
  // الـ Access Token اللي حصلت عليه
}) async {
  print('111111111111111111111111111111111');
  final url = Uri.parse(
    "https://fcm.googleapis.com/v1/projects/maintenance-b7282/messages:send",
  );

  final payload = {
    "message": {
      "token": deviceToken, // هنا نستخدم token بدل topic
      "notification": {"title": title, "body": body},
      "android": {
        "priority": "HIGH", // ملاحظة: يجب أن تكون HIGH وليس high
        "notification": {"channel_id": "high_importance_channel"},
      },
      "data": {"route": "home"},
    },
  };
  final accessToken = await getAccessToken();
  final response = await http.post(
    url,
    headers: {
      "Authorization": "Bearer $accessToken",
      "Content-Type": "application/json",
    },
    body: jsonEncode(payload),
  );

  print("FCM Response Status: ${response.statusCode}");
  print("FCM Response Body: ${response.body}");
}

class ConstTasksManager extends StatefulWidget {
  final String groupId;
  const ConstTasksManager({super.key, required this.groupId});

  @override
  State<ConstTasksManager> createState() => _ConstTasksManagerState();
}

class _ConstTasksManagerState extends State<ConstTasksManager> {
  final TextEditingController editTitleController = TextEditingController();
  final TextEditingController editDescController = TextEditingController();
  final constTitleController = TextEditingController();
  final constDescController = TextEditingController();

  // 1. دالة حذف مهمة من المصفوفة
  Future<void> deleteTask(Map<String, dynamic> task) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل أنت متأكد أنك تريد حذف هذه المهمة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('tasks')
                    .doc(widget.groupId)
                    .update({
                      'constTasks': FieldValue.arrayRemove([task]),
                    });
                Navigator.pop(context);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 2. دالة تعديل مهمة (حذف القديمة وإضافة الجديدة المعدلة)
  Future<void> updateTask(Map<String, dynamic> oldTask) async {
    final newTask = {
      'title': editTitleController.text.trim(),
      'description': editDescController.text.trim(),
    };

    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference docRef = FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.groupId);

    batch.update(docRef, {
      'constTasks': FieldValue.arrayRemove([oldTask]),
    });
    batch.update(docRef, {
      'constTasks': FieldValue.arrayUnion([newTask]),
    });

    await batch.commit();
  }

  // 3. واجهة التعديل (BottomSheet)
  void showEditSheet(Map<String, dynamic> task) {
    editTitleController.text = task['title'];
    editDescController.text = task['description'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تعديل المهمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: editTitleController,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: editDescController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await updateTask(task);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'حفظ التعديلات',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void addConstTask() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // للسماح للوحة بالارتفاع مع لوحة المفاتيح
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                20, // تجنب تداخل الكيبورد
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // شريط علوي صغير للجمالية
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'إضافة مهمة ثابتة جديدة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 20),

                // حقل اسم المهمة
                TextField(
                  controller: constTitleController,
                  decoration: InputDecoration(
                    labelText: 'اسم المهمة',
                    hintText: 'مثال: فحص يومي للمعدات',
                    prefixIcon: const Icon(
                      Icons.task_alt,
                      color: Color(0xFF1A237E),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1A237E),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // حقل وصف المهمة
                TextField(
                  controller: constDescController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'وصف المهمة',
                    prefixIcon: const Icon(
                      Icons.description_outlined,
                      color: Color(0xFF1A237E),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1A237E),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // أزرار التحكم
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (constTitleController.text.isEmpty) return;

                          await FirebaseFirestore.instance
                              .collection('tasks')
                              .doc(widget.groupId)
                              .set(
                                {
                                  'constTasks': FieldValue.arrayUnion([
                                    {
                                      'title': constTitleController.text.trim(),
                                      'description': constDescController.text
                                          .trim(),
                                    },
                                  ]),
                                },
                                SetOptions(merge: true),
                              ); // استخدام merge لعدم مسح البيانات القديمة

                          constTitleController.clear();
                          constDescController.clear();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'تأكيد الإضافة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المهام الثابتة'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              addConstTask();
            },
            label: Text('اضافة مهمة ثابتة'),
            icon: Icon(Icons.add_box_outlined),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 74, 87, 227),
              foregroundColor: const Color(0xFFffffff),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .doc(widget.groupId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('لا توجد مهام ثابتة حالياً'));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data == null || !data.containsKey('constTasks')) {
                  return const Center(child: Text('لا توجد مهام ثابتة حالياً'));
                }

                final List<dynamic> tasks =
                    (data['constTasks'] as List<dynamic>?) ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index] as Map<String, dynamic>;
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: InkWell(
                        onTap: () async {
                          await Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => AddTaskScreen(
                                groupId: widget.groupId,
                                fromConstTasks: true,
                                title: TextEditingController(
                                  text: task['title'],
                                ),
                                description: TextEditingController(
                                  text: task['description'],
                                ),
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          title: Text(
                            task['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(task['description']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => showEditSheet(task),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => deleteTask(task),
                              ),
                            ],
                          ),
                        ),
                      ),
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
