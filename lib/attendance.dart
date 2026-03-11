import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:maintenance/JoinGroup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

String? groupId0;
List<double> faceEmbeddingLive = [];

class DailyAttendanceScreen extends StatefulWidget {
  final String groupId;
  const DailyAttendanceScreen({super.key, required this.groupId});
  static const String screenroute = 'dailyAttendance';

  @override
  State<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends State<DailyAttendanceScreen> {
  List<Map<String, dynamic>> members = [];
  bool loading = false;
  Map<String, Map<String, dynamic>> todaysAttendance = {};
  User? currentUser;

  // ألوان مخصصة للتصميم
  final Color primaryColor = const Color(0xFF1A237E); // أزرق داكن
  final Color accentColor = const Color(0xFF3949AB);
  final Color successColor = const Color(0xFF4CAF50);
  final Color warningColor = const Color(0xFFFFA000);

  @override
  void initState() {
    groupId0 = widget.groupId;
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    _requestLocationPermission();
    _loadMembers();
    _loadTodaysAttendance();
    loadFaceEmbedding();
    print(loadFaceEmbedding());
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('من فضلك فعّل خدمة الموقع GPS', isError: true);
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar(
          'تم رفض إذن الموقع، لا يمكن تسجيل الحضور بدون الموقع',
          isError: true,
        );
        return;
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          textAlign: TextAlign.right,
        ),
        backgroundColor: isError ? Colors.redAccent : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _loadMembers() async {
    setState(() => loading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.groupId)
          .collection('members')
          .where('confirm', isEqualTo: true)
          .orderBy('joinedAt', descending: false)
          .get();

      setState(() {
        members = snapshot.docs.map<Map<String, dynamic>>((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'],
            'job': data['job'],
            'photoURL': data['photoURL'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      _showSnackBar('خطأ في تحميل الأعضاء: $e', isError: true);
    } finally {
      setState(() => loading = false);
    }
  }

  String convertArabicNumbersToEnglish(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    for (int i = 0; i < arabic.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
    }
    return input;
  }

  DateTime convertStringToDate(String value) {
    // استخدم RegExp لاستخراج التاريخ
    final match = RegExp(r'[\d٠-٩]{4}/[\d٠-٩]{2}/[\d٠-٩]{2}').firstMatch(value);
    if (match != null) {
      String dateStr = convertArabicNumbersToEnglish(match.group(0)!);
      return DateFormat('yyyy/MM/dd').parse(dateStr);
    }
    throw Exception('Invalid date format');
  }

  String selectedItem = storedEmbeddingDynamic![0];
  DateTime result1 = DateTime.now();

  void showDropdownMenu(BuildContext context, TapDownDetails details) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final result = await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: storedEmbeddingDynamic!.map((item) {
        return PopupMenuItem(value: item, child: Text(item));
      }).toList(),
    );

    if (result != null) {
      setState(() {
        selectedItem = result.toString();
        result1 = convertStringToDate(selectedItem);
      });

      _loadTodaysAttendance();
    }
  }

  Future<void> _loadTodaysAttendance() async {
    //  final today = DateTime.now();
    final startOfDay = DateTime(result1.year, result1.month, result1.day);

    final snap = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.groupId)
        .collection('records')
        .where('date', isEqualTo: startOfDay)
        .get();

    final Map<String, Map<String, dynamic>> map = {};
    for (var doc in snap.docs) {
      map[doc['memberId']] = doc.data();
    }

    setState(() {
      todaysAttendance = map;
    });
  }

  Future<void> _checkIn(Map<String, dynamic> member) async {
    final List<dynamic>? storedEmbeddingDynamic = await loadFaceEmbedding();
    final result = await Navigator.push<List<double>>(
      context,
      MaterialPageRoute(builder: (_) => const FaceRegisterScreen()),
    );

    if (result != null) {
      setState(() {
        faceEmbeddingLive = result;
      });
    }
    double similarity = cosineSimilarity(
      storedEmbeddingDynamic!,
      faceEmbeddingLive,
    );

    if (similarity >= 0.8) {
      print("✔ حضور مؤكد");
    } else {
      print("✖ وجه غير مطابق");
      return;
    }
    setState(() => loading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String addressIn = placemarks.isNotEmpty
          ? [
              placemarks.first.street,
              placemarks.first.subLocality,
              placemarks.first.locality,
              placemarks.first.administrativeArea,
              placemarks.first.country,
            ].where((e) => e != null && e.isNotEmpty).join('، ')
          : 'موقع غير معروف';

      DateTime today = DateTime.now();
      DateTime dateOnly = DateTime(today.year, today.month, today.day);

      final docId = "${member['id']}_${dateOnly.toIso8601String()}";
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(widget.groupId)
          .set({'groupId': widget.groupId});
      final attendanceRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc(widget.groupId)
          .collection('records')
          .doc(docId);

      final data = {
        'memberId': member['id'],
        'name': member['name'],
        'photoURL': member['photoURL'] ?? '',
        'date': dateOnly,
        'checkInTime': Timestamp.now(),
        'checkInLat': position.latitude,
        'checkInLng': position.longitude,
        'locationIn': addressIn,
        'expiredAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      };

      await attendanceRef.set(data);

      setState(() {
        todaysAttendance[member['id']] = data;
      });
      _showSnackBar('تم تسجيل الدخول بنجاح');
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء تسجيل الدخول: $e', isError: true);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _checkOut(Map<String, dynamic> member) async {
    final List<dynamic>? storedEmbeddingDynamic = await loadFaceEmbedding();
    final result = await Navigator.push<List<double>>(
      context,
      MaterialPageRoute(builder: (_) => const FaceRegisterScreen()),
    );

    if (result != null) {
      setState(() {
        faceEmbeddingLive = result;
      });
    }
    double similarity = cosineSimilarity(
      storedEmbeddingDynamic!,
      faceEmbeddingLive,
    );

    if (similarity >= 0.8) {
      print("✔ حضور مؤكد");
      faceEmbeddingLive.clear();
    } else {
      print("✖ وجه غير مطابق");
      _showSnackBar("✖ وجه غير مطابق");
      faceEmbeddingLive.clear();
      return;
    }
    setState(() => loading = true);
    try {
      final today = DateTime.now();
      final dateOnly = DateTime(today.year, today.month, today.day);
      final docId = "${member['id']}_${dateOnly.toIso8601String()}";
      final docRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc(widget.groupId)
          .collection('records')
          .doc(docId);

      final doc = await docRef.get();
      if (!doc.exists) {
        _showSnackBar('لم يتم تسجيل الدخول بعد', isError: true);
        return;
      }
      if (doc.data()!['checkOutTime'] != null) {
        _showSnackBar('تم تسجيل الخروج بالفعل', isError: true);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      String addressOut = placemarks.isNotEmpty
          ? [
              placemarks.first.street,
              placemarks.first.subLocality,
              placemarks.first.locality,
              placemarks.first.administrativeArea,
              placemarks.first.country,
            ].where((e) => e != null && e.isNotEmpty).join('، ')
          : 'موقع غير معروف';

      final checkInTime = doc.data()!['checkInTime'] as Timestamp;
      final checkOutTime = Timestamp.now();
      final duration = checkOutTime.toDate().difference(checkInTime.toDate());

      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      String workDuration = '${hours} ساعة و ${minutes} دقيقة';

      await docRef.update({
        'checkOutTime': checkOutTime,
        'checkOutLat': position.latitude,
        'checkOutLng': position.longitude,
        'workDuration': workDuration,
        'locationOut': addressOut,
      });

      setState(() {
        todaysAttendance[member['id']] = {
          ...todaysAttendance[member['id']]!,
          'checkOutTime': checkOutTime,
          'checkOutLat': position.latitude,
          'checkOutLng': position.longitude,
          'workDuration': workDuration,
          'locationOut': addressOut,
        };
      });
      _showSnackBar('تم تسجيل الخروج بنجاح. مدة العمل: $minutes دقيقة');
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء تسجيل الخروج: $e', isError: true);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    /*  final todayString = DateFormat(
      'EEEE， yyyy/MM/dd',
      'ar',
    ).format(DateTime.now()); */
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'سجل الحضور اليومي',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadMembers();
                await _loadTodaysAttendance();
              },
              child: Column(
                children: [
                  GestureDetector(
                    onTapDown: (details) {
                      showDropdownMenu(context, details);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            selectedItem,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✅ هنا لازم Expanded عشان ListView تاخد المساحة المتاحة
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final attendanceData = todaysAttendance[member['id']];
                        final checkedIn = attendanceData != null;
                        final checkedOut =
                            attendanceData?['checkOutTime'] != null;

                        return _buildMemberCard(
                          member,
                          attendanceData,
                          checkedIn,
                          checkedOut,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMemberCard(
    Map<String, dynamic> member,
    Map<String, dynamic>? attendanceData,
    bool checkedIn,
    bool checkedOut,
  ) {
    String checkInTimeStr = '';
    String checkOutTimeStr = '';

    if (checkedIn) {
      final tsIn = attendanceData!['checkInTime'];
      if (tsIn != null && tsIn is Timestamp) {
        checkInTimeStr = DateFormat('hh:mm a').format(tsIn.toDate());
      }
      final tsOut = attendanceData['checkOutTime'];
      if (tsOut != null && tsOut is Timestamp) {
        checkOutTimeStr = DateFormat('hh:mm a').format(tsOut.toDate());
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // شريط جانبي ملون حسب الحالة
              Container(
                width: 6,
                color: checkedOut
                    ? successColor
                    : (checkedIn ? warningColor : Colors.grey[300]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            backgroundImage: member['photoURL'] != ''
                                ? NetworkImage(member['photoURL'])
                                : null,
                            child: member['photoURL'] == ''
                                ? Icon(
                                    Icons.person,
                                    color: primaryColor,
                                    size: 30,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                Text(
                                  member['job'] ?? 'موظف',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // أيقونة الحالة
                          if (checkedOut)
                            Icon(
                              Icons.check_circle,
                              color: successColor,
                              size: 28,
                            )
                          else if (checkedIn)
                            Icon(
                              Icons.access_time_filled,
                              color: warningColor,
                              size: 28,
                            ),
                        ],
                      ),
                      if (checkedIn) ...[
                        const Divider(height: 20),
                        InkWell(
                          onTap: () {
                            openGoogleMaps(
                              attendanceData['checkInLat'],
                              attendanceData['checkInLng'],
                            );
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'الدخول: ${attendanceData!['locationIn']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontFamily: 'Cairo',
                                  ),
                                  /*  maxLines: 1,
                                  overflow: TextOverflow.ellipsis, */
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (checkedOut)
                          InkWell(
                            onTap: () {
                              openGoogleMaps(
                                attendanceData['checkOutLat'],
                                attendanceData['checkOutLng'],
                              );
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'الخروج: ${attendanceData['locationOut']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTimeInfo(
                              'وقت الدخول',
                              checkInTimeStr,
                              Icons.login,
                              Colors.blue,
                            ),
                            if (checkedOut)
                              _buildTimeInfo(
                                'وقت الخروج',
                                checkOutTimeStr,
                                Icons.logout,
                                Colors.orange,
                              ),
                            if (attendanceData['workDuration'] != null)
                              _buildTimeInfo(
                                'المدة',
                                '${attendanceData['workDuration']}',
                                Icons.timer,
                                Colors.purple,
                              ),
                          ],
                        ),
                      ],
                      // أزرار التحكم (تظهر فقط للمستخدم الحالي)
                      if (member['id'] == currentUser?.uid &&
                          !checkedOut &&
                          selectedItem == storedEmbeddingDynamic![0]) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => checkedIn
                                ? _checkOut(member)
                                : _checkIn(member),
                            icon: Icon(checkedIn ? Icons.logout : Icons.login),
                            label: Text(
                              checkedIn
                                  ? 'تسجيل الخروج الآن'
                                  : 'تسجيل الدخول الآن',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: checkedIn
                                  ? warningColor
                                  : primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        Text(
          time,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}

List<dynamic>? storedEmbeddingDynamic = [
  DateFormat('EEEE， yyyy/MM/dd', 'ar').format(DateTime.now()),
  DateFormat(
    'EEEE， yyyy/MM/dd',
    'ar',
  ).format(DateTime.now().subtract(Duration(days: 1))),
  DateFormat(
    'EEEE， yyyy/MM/dd',
    'ar',
  ).format(DateTime.now().subtract(Duration(days: 2))),
  DateFormat(
    'EEEE， yyyy/MM/dd',
    'ar',
  ).format(DateTime.now().subtract(Duration(days: 3))),
  DateFormat(
    'EEEE， yyyy/MM/dd',
    'ar',
  ).format(DateTime.now().subtract(Duration(days: 4))),
  DateFormat(
    'EEEE， yyyy/MM/dd',
    'ar',
  ).format(DateTime.now().subtract(Duration(days: 5))),
  DateFormat(
    'EEEE， yyyy/MM/dd',
    'ar',
  ).format(DateTime.now().subtract(Duration(days: 6))),
];

/// ================================
/// 📥 تحميل بصمة الوجه (Local → Firebase)
/// ================================
Future<List<dynamic>?> loadFaceEmbedding() async {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// 🔑 Key خاص بكل مستخدم
  String _localKey(String uid) => 'face_data_$uid';
  final user = _auth.currentUser;
  if (user == null) return null;

  final prefs = await SharedPreferences.getInstance();
  final localData = prefs.getString(_localKey('$groupId0 ${user.uid}'));

  // ✅ 1. لو موجود محليًا
  if (localData != null) {
    final List decoded = jsonDecode(localData);
    return decoded.map((e) => e.toDouble()).toList();
  }

  // ☁️ 2. مش موجود محليًا → Firebase
  final doc = await _firestore
      .collection('faceEmbedding')
      .doc(groupId0)
      .collection('users')
      .doc(user.uid)
      .get();

  if (!doc.exists || doc.data()?['faceEmbedding'] == null) {
    return null;
  }

  final List cloudData = doc['faceEmbedding'];

  final embedding = cloudData.map((e) => (e as num).toDouble()).toList();

  // 💾 خزنه محليًا
  await prefs.setString(
    _localKey('$groupId0 ${user.uid}'),
    jsonEncode(embedding),
  );

  return embedding;
}

double cosineSimilarity(List<dynamic> v1, List<dynamic> v2) {
  double dot = 0.0;
  double norm1 = 0.0;
  double norm2 = 0.0;

  for (int i = 0; i < v1.length; i++) {
    dot += v1[i] * v2[i];
    norm1 += v1[i] * v1[i];
    norm2 += v2[i] * v2[i];
  }

  return dot / (sqrt(norm1) * sqrt(norm2));
}

Future<void> openGoogleMaps(double lat, double lng) async {
  final Uri googleMapsUrl = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
  );

  if (await canLaunchUrl(googleMapsUrl)) {
    await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not open Google Maps';
  }
}
