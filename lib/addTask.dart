import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

List assetIds = [];
String? selectedAssetId;

class AddTaskScreen extends StatefulWidget {
  final String groupId;
  const AddTaskScreen({super.key, required this.groupId});
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
          .set({'groupId': widget.groupId});

      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.groupId)
          .collection('items')
          .doc();

      await taskRef.set({
        'id': taskRef.id,
        'title': titleController.text.trim(),
        'description': descController.text.trim(),
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
        body: 'تم إضافة مهمة جديدة: ${titleController.text.trim()}',
      );

      if (mounted) Navigator.pop(context);
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
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
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
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: titleController,
                      label: 'عنوان المهمة',
                      icon: Icons.title,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'أدخل العنوان' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: descController,
                      label: 'وصف المهمة',
                      icon: Icons.description_outlined,
                      maxLines: 3,
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
          value: selectedAssetId,
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
      value: value,
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
  final accessToken = await getAccessToken();
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
        "android": {"priority": "high"},
      },
    }),
  );
}
