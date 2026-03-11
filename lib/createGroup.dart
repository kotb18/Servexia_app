import 'dart:convert';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:maintenance/JoinGroup.dart';
import 'package:maintenance/services/billing_service.dart';
import 'package:maintenance/workSpace.dart';
import 'package:shared_preferences/shared_preferences.dart';

List faceEmbeddingAdmin = [];

final BillingService billingService = BillingService();
String? _completePhoneNumber;
//String? _selectedCountryCode;

class Creategroup extends StatefulWidget {
  const Creategroup({super.key});
  static const String screenroute = 'createGroup';

  @override
  State<Creategroup> createState() => _CreategroupState();
}

class _CreategroupState extends State<Creategroup> {
  static String _localKey(String uid) => 'face_data_$uid';
  final _formKey = GlobalKey<FormState>();
  final egyptPhoneRegex = RegExp(r'^(?:\+20|0)?1[0125][0-9]{8}$');
  TextEditingController _areaController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _purposeController = TextEditingController();
  final _adminController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedArea = 'Egypt';
  bool _loading = false;

  // متغيرات الحالة (تم نقلها من النطاق العام إلى داخل الكلاس)
  bool isUsed = true;
  DateTime? expiredAt;
  String? status;

  // الحصول على معرف المستخدم الحالي بسهولة
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  final List<String> areas = [
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'الدقهلية',
    'البحر الأحمر',
    'البحيرة',
    'الفيوم',
    'الغربية',
    'الإسماعيلية',
    'المنوفية',
    'المنيا',
    'القليوبية',
    'الوادي الجديد',
    'الشرقية',
    'السويس',
    'أسوان',
    'أسيوط',
    'بني سويف',
    'بورسعيد',
    'دمياط',
    'جنوب سيناء',
    'كفر الشيخ',
    'الأقصر',
    'قنا',
    'شمال سيناء',
    'سوهاج',
    'مطروح',
  ];

  @override
  void initState() {
    _checkSubscriptionStatus();
    super.initState();
    faceEmbeddingAdmin.clear();
    billingService.init();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _adminController.text = user.displayName ?? 'Admin';
    }
    _areaController.text = 'Egypt';
    _completePhoneNumber = null;
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _purposeController.dispose();
    _adminController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    billingService.dispose();
    faceEmbeddingAdmin.clear();
    super.dispose();
  }

  /// 🔹 التحقق من حالة الاشتراك
  _checkSubscriptionStatus() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .then((doc) {
          if (!doc.exists) {
            if (mounted) setState(() => isUsed = false);
            return;
          }

          final data = doc.data() as Map<String, dynamic>;
          final List users = data['users'] ?? [];

          if (mounted) {
            setState(() {
              isUsed = users.contains(uid);
              // تصحيح: تحويل Timestamp من فايربيس إلى DateTime
              if (data['expiredAt'] != null) {
                expiredAt = (data['expiredAt'] as Timestamp).toDate();
              }
              status = data['status'];
            });
          }
        })
        .catchError((e) {
          debugPrint("Error fetching subscription: $e");
        });
  }

  /// 🔹 عرض نافذة المراجعة قبل الإنشاء
  void _showPreview() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مراجعة البيانات', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📌 المجموعة: ${_groupNameController.text}'),
            Text(
              '👤 الأدمن: ${_adminController.text.isEmpty ? 'admin' : _adminController.text}',
            ),
            Text('📍 المنطقة: $_selectedArea '),
            Text('📞 الهاتف: ${_completePhoneNumber ?? ''}'),
            if (_purposeController.text.isNotEmpty)
              Text('📝 الغرض: ${_purposeController.text}'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('تعديل'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('تأكيد الإنشاء'),
            onPressed: () {
              Navigator.pop(context);
              _handleGroupCreation();
            },
          ),
        ],
      ),
    );
  }

  /// 🔹 معالجة منطق إنشاء المجموعة (الاشتراك + التجربة)
  Future<void> _handleGroupCreation() async {
    await _checkSubscriptionStatus();
    setState(() => _loading = true);

    try {
      // 1. حالة انتهاء الاشتراك
      if (isUsed && expiredAt != null && expiredAt!.isBefore(DateTime.now())) {
        _showExpiredDialog();
        return;
      }

      // 2. حالة المستخدم الجديد (تجربة مجانية)
      if (!isUsed) {
        _showFreeTrialDialog();
        return;
      }
      print('111111111111111111111111111111111111111111');
      // 3. حالة الاشتراك الفعال
      await _executeCreationLogic();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showExpiredDialog() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: 'انتهت صلاحية اشتراكك',
      desc: 'يرجى الاشتراك مرة أخرى للاستمرار في استخدام التطبيق',
      btnCancelText: 'إلغاء',
      btnOkText: 'الاشتراك الآن',
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        billingService.buySubscription();
      },
    ).show();
  }

  void _showFreeTrialDialog() {
    AwesomeDialog(
      context: context,
      title: 'جرب لمدة شهر مجانا',
      desc: 'يمكنك تجربة التطبيق لمدة شهر مجانا.',
      dialogType: DialogType.info,
      btnOkText: 'ابدأ التجربة',
      btnOkOnPress: () async {
        setState(() => _loading = true);
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'users': FieldValue.arrayUnion([uid]),
          'expiredAt': DateTime.now().add(const Duration(days: 30)),
          'status': '0',
        }, SetOptions(merge: true));

        await _executeCreationLogic();
        setState(() => _loading = false);
      },
    ).show();
  }

  void _showError(String msg) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      title: "خطأ",
      desc: msg,
      btnOkOnPress: () {},
    ).show();
  }

  /// 🔹 الكود الفعلي لإنشاء المجموعة في قاعدة البيانات (تم توحيده لمنع التكرار)
  Future<void> _executeCreationLogic() async {
    final docRef = FirebaseFirestore.instance.collection('groups').doc();
    final String groupId = docRef.id;
    final String adminName = _adminController.text.trim().isNotEmpty
        ? _adminController.text.trim()
        : 'admin';
    final String? token = await FirebaseMessaging.instance.getToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey('$groupId $uid'),
      jsonEncode(faceEmbeddingAdmin),
    );
    FirebaseFirestore.instance
        .collection('faceEmbedding')
        .doc(groupId)
        .collection('users')
        .doc(uid)
        .set({
          'faceEmbedding': faceEmbeddingAdmin,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    // إنشاء وثيقة المجموعة
    await docRef.set({
      'docId': groupId,
      'name': _groupNameController.text.trim(),
      'adminId': uid,
      'admins': [uid],
      'adminName': adminName,
      'area': _selectedArea,
      'purpose': _purposeController.text.trim(),
      'members': [uid],
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'willDeleteAt': DateTime.now().add(const Duration(days: 100)),
    });

    // إنشاء وثيقة الفريق
    await FirebaseFirestore.instance.collection('teams').doc(groupId).set({
      'groupId': groupId,
      'admins': [uid],
      'adminToken': token,
      /*  'members': [
        {
          'name': adminName,
          'id': uid,
          'phone': _completePhoneNumber!,
          'job': 'مدير المجموعة',
          'joinedAt': DateTime.now(),
          'confirm': true,
          'photoURL': FirebaseAuth.instance.currentUser?.photoURL ?? '',
        },
      ], */
    });
    await FirebaseFirestore.instance
        .collection('teams')
        .doc(groupId)
        .collection('members')
        .doc(uid)
        .set({
          'name': adminName,
          'id': uid,
          'phone': _completePhoneNumber!,
          'job': 'مدير المجموعة',
          'joinedAt': DateTime.now(),
          'confirm': true,
          'photoURL': FirebaseAuth.instance.currentUser?.photoURL ?? '',
        });
    await FirebaseFirestore.instance.collection('attendance').doc(groupId).set({
      'groupId': groupId,
    });

    // الاشتراك في التنبيهات
    await FirebaseMessaging.instance.subscribeToTopic('${groupId}admin');

    if (!mounted) return;

    // الانتقال لصفحة مساحة العمل
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WorkspaceHomeScreen(workspaceId: groupId),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // الخلفية
          Positioned.fill(
            child: Image.asset(
              'images/22.jpeg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.grey[900]),
            ),
          ),

          // طبقة التظليل
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // محتوى الفورم
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Card(
                  elevation: 15,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'إنشاء مجموعة جديدة',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 25),

                          _buildTextField(
                            controller: _groupNameController,
                            label: 'اسم المجموعة',
                            icon: Icons.group_work,
                          ),
                          const SizedBox(height: 15),

                          _buildTextField(
                            controller: _adminController,
                            label: 'اسم الأدمن',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _areaController,
                            readOnly: true,
                            decoration: _inputDecoration(
                              'اختر منطقة العمل',
                              Icons.public,
                            ),
                            onTap: () {
                              showCountryPicker(
                                context: context,
                                showPhoneCode: false,
                                onSelect: (Country country) {
                                  setState(() {
                                    _selectedArea = country.name;
                                    _areaController.text = country.name;
                                  });
                                },
                              );
                            },
                            validator: (v) => v == null || v.isEmpty
                                ? 'اختر منطقة العمل'
                                : null,
                          ),

                          const SizedBox(height: 15),

                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: IntlPhoneField(
                              decoration: _inputDecoration(
                                'رقم الهاتف',
                                Icons.phone_android,
                              ),
                              initialCountryCode:
                                  'EG', // تقدر تحطه null لو مش عايز افتراضي
                              onChanged: (phone) {
                                _completePhoneNumber = phone.completeNumber;
                                // +201234567890
                                // _selectedCountryCode = phone.countryCode; // +20
                              },
                              validator: (phone) {
                                if (phone == null || phone.number.isEmpty) {
                                  return 'رقم الهاتف مطلوب';
                                }
                                if (!phone.isValidNumber()) {
                                  return 'رقم غير صحيح';
                                }
                                return null;
                              },
                            ),
                          ),

                          const SizedBox(height: 15),

                          _buildTextField(
                            controller: _purposeController,
                            label: 'الغرض (اختياري)',
                            icon: Icons.notes,
                            maxLines: 2,
                            required: false,
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.face),
                              label: Text(
                                faceEmbeddingAdmin.isEmpty
                                    ? 'التقاط بصمة الوجه'
                                    : 'تم تسجيل الوجه ✔',
                              ),
                              onPressed: () async {
                                final result =
                                    await Navigator.push<List<double>>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const FaceRegisterScreen(),
                                      ),
                                    );

                                if (result != null) {
                                  setState(() {
                                    faceEmbeddingAdmin = result;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              icon: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(
                                _loading ? 'جاري المعالجة...' : 'معاينة وإنشاء',
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _loading
                                  ? null
                                  : () {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      if (_completePhoneNumber == null) {
                                        AwesomeDialog(
                                          context: context,
                                          title: 'خطأ',
                                          desc: 'رقم الهاتف مطلوب',
                                          dialogType: DialogType.error,
                                        ).show();
                                        return;
                                      }
                                      if (faceEmbeddingAdmin.isEmpty) {
                                        _showError("بصمة الوجه مطلوبة");
                                        return;
                                      }
                                      if (_formKey.currentState!.validate()) {
                                        _showPreview();
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      label: Text(label),
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator:
          validator ??
          (required
              ? (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null
              : null),
      decoration: _inputDecoration(label, icon),
    );
  }
}
