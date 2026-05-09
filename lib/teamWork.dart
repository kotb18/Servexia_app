import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

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
              onPressed: () {
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
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إغلاق'),
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
          /*  widget.isXadmin ? _adminTile(widget.adminId) : SizedBox.shrink(),
          const SizedBox(height: 20), */
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
                        backgroundColor: Colors.green.withOpacity(0.1),
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

  Future<void> getVariables() async {
    final doc = await FirebaseFirestore.instance
        .collection('variables')
        .doc('kotb')
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
    getVariables();
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
          children: confirmedMembers.map((member) {
            return Card(
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
                    /// -------- Top Row (Avatar + Name) --------
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage:
                              member['photoURL'] != null &&
                                  member['photoURL'].toString().isNotEmpty
                              ? NetworkImage(member['photoURL'])
                              : null,
                          child:
                              member['photoURL'] == null ||
                                  member['photoURL'].toString().isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member['name'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                member['job'] ?? 'عضو',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        isAdmin && !admins.contains(member['id'])
                            ? IconButton(
                                onPressed: () async {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      content: const Text(
                                        'هل تريد بالفعل إضافة العضو كمسؤول؟ تنبيه: سيتمكن المسؤول من الحصول على جميع ميزاتك.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            await FirebaseFirestore.instance
                                                .collection('groups')
                                                .doc(widget.groupId)
                                                .update({
                                                  'admins':
                                                      FieldValue.arrayUnion([
                                                        member['id'],
                                                      ]),
                                                });
                                            await FirebaseFirestore.instance
                                                .collection('teams')
                                                .doc(widget.groupId)
                                                .update({
                                                  'admins':
                                                      FieldValue.arrayUnion([
                                                        member['id'],
                                                      ]),
                                                });
                                            await getAdmins();
                                            setState(() {});
                                            Navigator.pop(context);
                                            setState(() {});
                                          },
                                          child: const Text('تأكيد'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.star_border_outlined,
                                  // color: const Color.fromARGB(255, 164, 172, 12),
                                ),
                                // label: const Text('اضافته كمسؤول'),
                              )
                            : isAdmin &&
                                  member['id'] != uid &&
                                  admins.contains(member['id']) &&
                                  member['id'] != widget.adminId
                            ? IconButton(
                                onPressed: () async {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      content: const Text(
                                        'هل تريد ازالة العضو كمسؤول؟',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            await FirebaseFirestore.instance
                                                .collection('groups')
                                                .doc(widget.groupId)
                                                .update({
                                                  'admins':
                                                      FieldValue.arrayRemove([
                                                        member['id'],
                                                      ]),
                                                });
                                            await FirebaseFirestore.instance
                                                .collection('teams')
                                                .doc(widget.groupId)
                                                .update({
                                                  'admins':
                                                      FieldValue.arrayRemove([
                                                        member['id'],
                                                      ]),
                                                });
                                            await getAdmins();
                                            setState(() {});
                                            Navigator.pop(context);
                                            setState(() {});
                                          },
                                          child: const Text('تأكيد'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.star,
                                  color: const Color.fromARGB(
                                    255,
                                    164,
                                    172,
                                    12,
                                  ),
                                ),
                                // label: const Text('اضافته كمسؤول'),
                              )
                            : (admins.isNotEmpty &&
                                  admins.contains(member['id']))
                            ? Icon(
                                Icons.star,
                                color: const Color.fromARGB(255, 164, 172, 12),
                              )
                            : SizedBox.shrink(),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Divider(height: 1),

                    /// -------- Actions --------
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      children: [
                        /// WhatsApp
                        TextButton.icon(
                          onPressed: () {
                            openWhatsApp(
                              '${member['phone']}',
                              'مرحباً ${member['name']}',
                            );
                          },
                          icon: Image.asset('images/whatsapp.png', width: 18),
                          label: const Text('واتساب'),
                        ),

                        /// Call
                        TextButton.icon(
                          onPressed: () async {
                            final url = Uri(
                              scheme: 'tel',
                              path: member['phone'],
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text('اتصال'),
                        ),

                        /// Remove (Admin only)
                        if ((member['id'] != widget.adminId &&
                                member['id'] != uid &&
                                admins.contains(uid)) ||
                            member['id'] != widget.adminId &&
                                (member['id'] != uid &&
                                    admins.contains(member['id'])))
                          TextButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  content: const Text(
                                    'هل تريد بالفعل مسح العضو؟',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('إلغاء'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await removeMemberFromGroupAndTeam(
                                          groupId: widget.groupId,
                                          memberId: member['id'],
                                        );
                                        await getAdmins();
                                        setState(() {});
                                        Navigator.pop(context);
                                        setState(() {});
                                      },
                                      child: const Text('تأكيد'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.person_remove_alt_1,
                              color: Colors.red,
                              size: 18,
                            ),
                            label: const Text('حذف'),
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
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
          /*   ListTile(
            leading: const Icon(Icons.link),
            title: const Text('إنشاء رابط دعوة'),
            onTap: _generateInviteLink,
          ), */
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

  /*  void _generateInviteLink() {
    Navigator.pop(context);
    final link = 'https://yourapp.com/join/${widget.groupId}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Invite Link: $link')));
  } */

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
                  data: qrString, // ✅ QR مؤقت
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

  await FirebaseMessaging.instance.unsubscribeFromTopic(groupId);
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

  // تحميل الخطوط العربية
  final arabicFont = await PdfGoogleFonts.cairoRegular();
  final arabicFontBold = await PdfGoogleFonts.cairoBold();

  // تاريخ اليوم للتقرير
  String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageFormat:
          PdfPageFormat.a4, // وضعية طولية (Portrait) مناسبة لعدد أعمدة أقل
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
      build: (context) {
        return [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // الهيدر: العنوان وتاريخ اليوم
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

                // جدول الأعضاء (الاسم، الوظيفة، الهاتف)
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2), // الاسم (أقصى اليمين)
                    1: const pw.FlexColumnWidth(2), // الوظيفة
                    2: const pw.FlexColumnWidth(3), // رقم الهاتف (أقصى اليسار)
                  },
                  children: [
                    // صف العناوين
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
                    // صفوف البيانات
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
      // تذييل الصفحة بالعربية
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

  // عرض للطباعة أو الحفظ
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'تقرير_أعضاء_الفريق_$todayDate.pdf',
  );
  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'تقرير_أعضاء_الفريق_$todayDate.pdf',
  );
}

// دالة مساعدة لبناء الخلية
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
