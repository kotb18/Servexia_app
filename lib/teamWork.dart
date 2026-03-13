import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

int? maxMembers;
int? currentTeamNumber;
List admins = [];

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
          const Text(
            'الأعضاء',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _memberTile(),
        ],
      ),
    );
  }

  getVariables() async {
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

  getAdmins() async {
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
                        if (isAdmin && member['id'] != widget.adminId)
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
                                      onPressed: () {
                                        removeMemberFromGroupAndTeam(
                                          groupId: widget.groupId,
                                          memberId: member['id'],
                                        );
                                        Navigator.pop(context);
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
                          ),
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

removeMemberFromGroupAndTeam({
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
    final data = teamSnap.data()!;
    final List members = List.from(data['members'] ?? []);

    members.removeWhere((m) => m['id'] == memberId);

    batch.update(teamRef, {'members': members});
  }

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
