import 'dart:convert';
import 'package:android_intent_plus/android_intent.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintenance/Subscruption/plan_selection_page.dart';
import 'package:maintenance/employeeDetailsPage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:maintenance/imageControl/platform_image.dart';

int? maxMembers;
int? currentTeamNumber;
List admins = [];
List<Map<String, dynamic>> membersList = [];

class TeamScreen extends StatefulWidget {
  final String groupId;
  final String adminId;
  final bool isAdmin;
  final bool isXadmin;

  const TeamScreen({
    super.key,
    required this.groupId,
    required this.adminId,
    required this.isAdmin,
    required this.isXadmin,
  });
  static const String screenroute = 'teamScreen';

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  bool get isAdmin => widget.isAdmin;

  /// Older member records may store an empty list instead of an image URL.
  String? _imageUrl(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return null;
  }

  Future<void> openGmailComposer(String email) async {
    final cleanEmail = email.trim();

    if (cleanEmail.isEmpty) return;

    // Web: فتح Gmail في تبويب جديد
    if (kIsWeb) {
      final gmailUrl = Uri.https('mail.google.com', '/mail/u/0/', {
        'view': 'cm',
        'fs': '1',
        'to': cleanEmail,
      });

      final opened = await launchUrl(gmailUrl, webOnlyWindowName: '_blank');

      if (!opened) {
        debugPrint('تعذر فتح Gmail في تبويب جديد');
      }

      return;
    }

    // Android: فتح تطبيق Gmail
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final gmailIntent = AndroidIntent(
          action: 'android.intent.action.SENDTO',
          data: Uri(scheme: 'mailto', path: cleanEmail).toString(),
          package: 'com.google.android.gm',
        );

        await gmailIntent.launch();
        return;
      } catch (error, stackTrace) {
        debugPrint('Gmail Android error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    // Fallback للأنظمة الأخرى
    final mailtoUri = Uri(scheme: 'mailto', path: cleanEmail);

    await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('فريق العمل'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.person_add),
              color: const Color.fromARGB(255, 5, 106, 9),
              onPressed: () async {
                await getMaxMembers();
                if (maxMembers != null &&
                    currentTeamNumber != null &&
                    currentTeamNumber! >= maxMembers!) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('حد الأعضاء'),
                      content: const Text(
                        'لقد وصلت إلى الحد الأقصى لعدد الأعضاء في الفريق. يرجى ترقية حسابك لزيادة الحد.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const FirestoreDynamicPlansPage(),
                              ),
                            );
                          },
                          child: const Text('حسنًا'),
                        ),
                      ],
                    ),
                  );
                } else {
                  _showInviteOptions();
                }
              },
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Text(
                'الأعضاء',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              widget.isAdmin
                  ? ElevatedButton.icon(
                      onPressed: () async {
                        await generateTeamMembersPdf(membersList);
                      },
                      icon: Icon(Icons.picture_as_pdf),
                      label: const Text('تقرير PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Colors.green,
                            width: 1.5,
                          ),
                        ),
                        elevation: 0,
                      ),
                    )
                  : SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 10),
          _memberTile(),
        ],
      ),
    );
  }

  Future<void> getMaxMembers() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) {
      return;
    }

    final data = doc.data();

    maxMembers = data!['maxMembers'];
  }

  Future<void> getAdmins() async {
    admins.clear();
    final doc = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.groupId)
        .get();
    if (!doc.exists) {
      return;
    }

    final data = doc.data();

    setState(() {
      admins = data!['admins'];
    });
  }

  @override
  initState() {
    super.initState();
    getAdmins();
    membersList.clear();
  }

  /// 👤 Member Tile
  Widget _memberTile() {
    print(widget.groupId);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.groupId)
          .collection('members')
          .where('confirm', isEqualTo: true)
          .orderBy('joinedAt', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final members = snap.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        final confirmedMembers = members
            .where((m) => m['confirm'] == true)
            .toList();
        membersList = confirmedMembers;
        currentTeamNumber = confirmedMembers.length;

        if (confirmedMembers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            ...confirmedMembers.map((member) {
              final faceImageUrl = _imageUrl(member['faceImageUrl']);
              final photoUrl = _imageUrl(member['photoURL']);
              final avatarUrl = faceImageUrl ?? photoUrl;
              final canDelete =
                  member['id'] != widget.adminId &&
                  member['id'] != uid &&
                  (admins.contains(uid) || admins.contains(member['id']));
              return InkWell(
                onTap: !widget.isAdmin
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeeDetailsPage(
                              employeeData: member,
                              isConfirmed: member['confirm'],
                              groupId: widget.groupId,
                              isAdmin: widget.isAdmin,
                            ),
                          ),
                        );
                      },
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.grey.shade300,
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? ClipOval(
                                      child: WebImage(
                                        src: avatarUrl,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.grey,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member['name']?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    member['job']?.toString() ?? 'عضو',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                if (member['id'] == widget.adminId)
                                  Icon(
                                    Icons.star,
                                    color: const Color.fromARGB(
                                      255,
                                      164,
                                      172,
                                      12,
                                    ),
                                  ),
                                IconButton(
                                  // ✅ كارت العضوية
                                  onPressed: () => _showMemberIdCard(member),
                                  icon: Icon(
                                    Icons.card_membership,
                                    color: const Color.fromARGB(
                                      255,
                                      49,
                                      30,
                                      215,
                                    ),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _actionButton(
                                icon: const Icon(
                                  Icons.call_rounded,
                                  color: Colors.blue,
                                ),
                                tooltip: 'اتصال',
                                backgroundColor: Colors.blue.withValues(
                                  alpha: 0.10,
                                ),
                                onPressed: () async {
                                  final phone = member['phone']?.toString();

                                  if (phone == null || phone.trim().isEmpty) {
                                    return;
                                  }

                                  final url = Uri(scheme: 'tel', path: phone);

                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  }
                                },
                              ),
                              _actionButton(
                                icon: Image.asset(
                                  'images/whatsapp.png',
                                  width: 21,
                                  height: 21,
                                ),
                                tooltip: 'واتساب',
                                backgroundColor: Colors.green.withValues(
                                  alpha: 0.10,
                                ),
                                onPressed: () {
                                  openWhatsApp(
                                    '${member['phone']}',
                                    'مرحباً ${member['name']}',
                                  );
                                },
                              ),
                              _actionButton(
                                icon: const Icon(
                                  Icons.email_rounded,
                                  color: Colors.orange,
                                ),
                                tooltip: 'Gmail',
                                backgroundColor: Colors.orange.withValues(
                                  alpha: 0.10,
                                ),
                                onPressed: () async {
                                  final email = member['userGmail']?.toString();

                                  if (email == null || email.trim().isEmpty) {
                                    return;
                                  }

                                  await openGmailComposer(email);
                                },
                              ),
                              if (canDelete)
                                _actionButton(
                                  icon: const Icon(
                                    Icons.person_remove_alt_1_rounded,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'حذف',
                                  backgroundColor: Colors.red.withValues(
                                    alpha: 0.10,
                                  ),
                                  onPressed: () {
                                    // حذف العضو
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 60),
          ],
        );
      },
    );
  }

  Widget _actionButton({
    required Widget icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(onPressed: onPressed, icon: icon),
      ),
    );
  }

  /// ➕ Invite Options
  void _showInviteOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('إنشاء QR Code'),
            onTap: _generateQRCode,
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  void _generateQRCode() {
    Navigator.pop(context);

    /// ⏳ صلاحية الـ QR (مثلاً 15 دقيقة)
    final expiresAt = DateTime.now()
        .add(const Duration(minutes: 15))
        .millisecondsSinceEpoch;

    final qrData = {
      "type": "group_invite",
      "groupId": widget.groupId,
      "expiresAt": expiresAt,
      'adminId': widget.adminId,
    };

    final qrString = jsonEncode(qrData);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('QR Code الدعوة'),
          content: SizedBox(
            width: 250,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: qrString,
                  version: QrVersions.auto,
                  size: 200,
                ),
                const SizedBox(height: 10),
                const Text(
                  'امسح هذا الرمز خلال 15 دقيقة للانضمام',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // 🪪 منطق كارت العضوية (ID Card)
  // ==========================================================================

  /// فتح كارت العضوية في Dialog احترافي
  void _showMemberIdCard(Map<String, dynamic> member) {
    final faceImageUrl = _imageUrl(member['faceImageUrl']);
    final photoUrl = _imageUrl(member['photoURL']);
    final avatarUrl = faceImageUrl ?? photoUrl;
    final avatarUrlPdf = faceImageUrl;

    final joinedAt = member['joinedAt'];
    String joinedDate = '---';
    if (joinedAt is Timestamp) {
      joinedDate = DateFormat('dd/MM/yyyy').format(joinedAt.toDate());
    } else if (joinedAt is int) {
      joinedDate = DateFormat(
        'dd/MM/yyyy',
      ).format(DateTime.fromMillisecondsSinceEpoch(joinedAt));
    }

    // بيانات الـ QR الخاصة بالعضو
    final memberQrData = jsonEncode({
      "type": "member_id",
      "groupId": widget.groupId,
      "memberId": member['id'],
      "name": member['name'],
    });

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF1E1E64), Color(0xFF31219E)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF31219E).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── الهيدر ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.badge_rounded,
                                color: Colors.amber,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'بطاقة عضوية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // زر إغلاق
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── الجسم الأبيض ───
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        // الصورة + الاسم + الوظيفة
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF31219E),
                                  width: 2.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 34,
                                backgroundColor: Colors.grey.shade200,
                                child: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? ClipOval(
                                        child: WebImage(
                                          src: avatarUrl,
                                          width: 68,
                                          height: 68,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 38,
                                        color: Colors.grey,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member['name']?.toString() ?? 'بدون اسم',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E1E64),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF31219E,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      member['job']?.toString() ?? 'عضو',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF31219E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // بيانات التواصل
                        _idCardInfoRow(
                          Icons.phone_rounded,
                          Colors.green,
                          'رقم الهاتف',
                          member['phone']?.toString() ?? '---',
                        ),
                        const SizedBox(height: 10),
                        _idCardInfoRow(
                          Icons.email_rounded,
                          Colors.orange,
                          'البريد الإلكتروني',
                          member['userGmail']?.toString() ?? '---',
                        ),
                        const SizedBox(height: 10),
                        _idCardInfoRow(
                          Icons.calendar_month_rounded,
                          Colors.blue,
                          'تاريخ الانضمام',
                          joinedDate,
                        ),

                        const SizedBox(height: 16),

                        // ─── QR + رقم العضو ───
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: QrImageView(
                                  data: memberQrData,
                                  version: QrVersions.auto,
                                  size: 74,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'رقم العضو',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${member['id']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E1E64),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'امسح الرمز للتحقق من العضوية',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── أزرار الأسفل ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        // زرار طباعة / مشاركة PDF
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _printMemberIdCard(
                                member,
                                avatarUrlPdf,
                                joinedDate,
                              );
                            },
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: const Text('طباعة PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: const Color(0xFF1E1E64),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // زرار إغلاق
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('إغلاق'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// صف بيانات داخل الكارت
  Widget _idCardInfoRow(
    IconData icon,
    Color iconColor,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// طباعة كارت العضوية PDF
  Future<void> _printMemberIdCard(
    Map<String, dynamic> member,
    String? avatarUrlPdf,
    String joinedDate,
  ) async {
    final pdf = pw.Document();

    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    // تحميل صورة العضو إن وجدت
    pw.ImageProvider? avatarImage;
    if (avatarUrlPdf != null && avatarUrlPdf.isNotEmpty) {
      try {
        avatarImage = await networkImage(avatarUrlPdf);
      } catch (_) {
        avatarImage = null;
      }
    } else {
      // تحميل صورة افتراضية من الأصول
      final defaultImage = await rootBundle.load('images/person_icon.png');
      avatarImage = pw.MemoryImage(defaultImage.buffer.asUint8List());
    }

    final memberQrData = jsonEncode({
      "type": "member_id",
      "groupId": widget.groupId,
      "memberId": member['id'],
      "name": member['name'],
    });

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColor.fromHex('#31219E'),
                  width: 2,
                ),
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Column(
                children: [
                  // الهيدر
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#1E1E64'),
                      borderRadius: const pw.BorderRadius.vertical(
                        top: pw.Radius.circular(14),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'بطاقة عضوية',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          'فريق العمل',
                          style: const pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 16),

                  // الصورة والاسم
                  pw.Row(
                    children: [
                      pw.SizedBox(width: 16),
                      pw.Container(
                        width: 70,
                        height: 70,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(
                            color: PdfColor.fromHex('#31219E'),
                            width: 2,
                          ),
                          image: avatarImage != null
                              ? pw.DecorationImage(
                                  image: avatarImage,
                                  fit: pw.BoxFit.cover,
                                )
                              : null,
                          color: PdfColors.grey200,
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              member['name']?.toString() ?? 'بدون اسم',
                              style: pw.TextStyle(
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#1E1E64'),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              member['job']?.toString() ?? 'عضو',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromHex('#31219E'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 14),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),

                  // البيانات
                  _pdfInfoRow(
                    'رقم الهاتف',
                    member['phone']?.toString() ?? '---',
                  ),
                  _pdfInfoRow(
                    'البريد الإلكتروني',
                    member['userGmail']?.toString() ?? '---',
                  ),
                  _pdfInfoRow('تاريخ الانضمام', joinedDate),
                  _pdfInfoRow('رقم العضو', '${member['id']}'),

                  pw.SizedBox(height: 12),

                  // QR
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: memberQrData,
                      width: 80,
                      height: 80,
                    ),
                  ),

                  pw.SizedBox(height: 12),

                  pw.Text(
                    'تاريخ الإصدار: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),

                  pw.SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'بطاقة_عضو_${member['name']}.pdf',
    );
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

void openWhatsApp(String phoneNumber, String message) async {
  final Uri url = Uri.parse(
    'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
  );
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    throw 'تعذر فتح واتساب';
  }
}

Future<void> removeMemberFromGroupAndTeam({
  required String groupId,
  required String memberId,
}) async {
  print('ahmed kotb');
  final firestore = FirebaseFirestore.instance;

  final teamRef = firestore.collection('teams').doc(groupId);
  final groupRef = firestore.collection('groups').doc(groupId);

  final batch = firestore.batch();

  // 🔹 جلب بيانات التيم
  final teamSnap = await teamRef.get();
  if (teamSnap.exists) {
    final membersRef = teamRef.collection('members').doc(memberId);
    batch.delete(membersRef);
  }
  final faceEmbeddingRef = firestore
      .collection('faceEmbedding')
      .doc(groupId)
      .collection('users')
      .doc(memberId);
  batch.delete(faceEmbeddingRef);

  // 🔹 جلب بيانات الجروب
  final groupSnap = await groupRef.get();
  if (groupSnap.exists) {
    final data = groupSnap.data()!;
    final List members = List.from(data['members'] ?? []);

    members.remove(memberId);

    batch.update(groupRef, {'members': members});
  }

  await batch.commit();
}

Future<void> generateTeamMembersPdf(
  List<Map<String, dynamic>> membersList,
) async {
  final pdf = pw.Document();

  final arabicFont = await PdfGoogleFonts.cairoRegular();
  final arabicFontBold = await PdfGoogleFonts.cairoBold();

  String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
      build: (context) {
        return [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "تقرير أعضاء الفريق",
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          "تاريخ التقرير: $todayDate",
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      "إجمالي الأعضاء: ${membersList.length}",
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(3),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blueGrey100,
                      ),
                      children: [
                        _buildCell("رقم الهاتف", isHeader: true),
                        _buildCell("الوظيفة", isHeader: true),
                        _buildCell("الاسم", isHeader: true),
                      ],
                    ),
                    ...membersList.map((member) {
                      return pw.TableRow(
                        children: [
                          _buildCell(member['phone']?.toString() ?? "---"),
                          _buildCell(member['job'] ?? "---"),
                          _buildCell(member['name'] ?? "---"),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ];
      },
      footer: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 20),
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
    name: 'تقرير_أعضاء_الفريق_$todayDate.pdf',
  );
  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'تقرير_أعضاء_الفريق_$todayDate.pdf',
  );
}

pw.Widget _buildCell(String text, {bool isHeader = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(
        fontSize: isHeader ? 12 : 11,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
