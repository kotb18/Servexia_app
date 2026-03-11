import 'dart:math' as math;
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:maintenance/JoinGroup.dart';
import 'package:maintenance/admin/mainAdmin.dart';
import 'package:maintenance/createGroup.dart';
import 'package:maintenance/signIn.dart';
import 'package:maintenance/workSpace.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:maintenance/services/billing_service.dart';
import 'package:in_app_review/in_app_review.dart';

List<QueryDocumentSnapshot<Object?>> groups = [];
final BillingService billingService = BillingService();
bool isLoading = false;

final InAppReview inAppReview = InAppReview.instance;
Future<void> showRateDialog(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();

  // لو اتعرض قبل كده، نطلع
  final bool dialogShown = prefs.getBool('rate_dialog_shown') ?? false;

  if (dialogShown) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('رأيك يهمنا ❤️'),
        content: const Text('هل التطبيق مفيد ليك؟'),
        actions: [
          TextButton(
            child: const Text('لا'),
            onPressed: () async {
              await prefs.setBool('rate_dialog_shown', true);
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            child: const Text('نعم ⭐'),
            onPressed: () async {
              await prefs.setBool('rate_dialog_shown', true);
              Navigator.pop(context);

              if (await inAppReview.isAvailable()) {
                inAppReview.requestReview();
              }
            },
          ),
        ],
      );
    },
  );
}

String uid = FirebaseAuth.instance.currentUser!.uid;
int? maxGroup;
int? maxMembers;
int? maxAssets;
int? maxWarehouseItems;
int? currentGroupsCount;

// Constants for Modern UI
class AppColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color backgroundStart = Color(0xFF0F172A);
  static const Color backgroundEnd = Color(0xFF1E293B);
  static const Color cardColor = Color(0xFF1E293B);
  static const Color accentColor = Color(0xFF10B981);
  static const Color glassWhite = Color(0x1FFFFFFF);
}

class Homepage extends StatefulWidget {
  const Homepage({super.key, required this.isAdmin});
  static const String screenroute = 'homePage';
  final bool isAdmin;

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool isMainAdmin = false;
  String? token = '';
  getVariables() async {
    final doc = await FirebaseFirestore.instance
        .collection('variables')
        .doc('kotb')
        .get();

    if (!doc.exists) {
      return;
    }

    final data = doc.data();

    maxGroup = data!['maxGroup'];
  }

  @override
  void initState() {
    super.initState();
    billingService.init();
    groups.clear;
    getVariables();
    if (FirebaseAuth.instance.currentUser!.email ==
        'aahmedkotb2498@gmail.com') {
      isMainAdmin = true;
    }

    getToken();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  getToken() async {
    token = await FirebaseMessaging.instance.getToken();
  }

  // static String _localKey(String uid) => 'face_data_$uid';
  @override
  void dispose() {
    _controller.dispose();
    billingService.dispose();
    super.dispose();
  }

  void createGroup() =>
      Navigator.of(context).pushNamed(Creategroup.screenroute);
  void joinGroup() =>
      Navigator.of(context).pushNamed(JoinGroupScreen.screenroute);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      drawer: _buildModernDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.backgroundStart, AppColors.backgroundEnd],
                ),
              ),
              child: SafeArea(
                child: CustomScrollView(
                  slivers: [
                    _buildModernAppBar(),
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              const HexagonImage(
                                imagePath: 'images/2.png',
                                size: 160.0,
                              ),
                              const SizedBox(height: 30),
                              _buildQuickActions(),
                              const SizedBox(height: 30),
                              _buildSectionTitle("مجموعاتك النشطة"),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildGroupsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Text(
        "Servexia",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 30,
        ),
      ),
      centerTitle: true,
      /*  actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
          ),
          onPressed: () {},
        ),
      ], */
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              title: "إنشاء مجموعة",
              icon: Icons.add_business_rounded,
              color: AppColors.primary,
              onTap: () {
                if (currentGroupsCount != null &&
                    currentGroupsCount! >= maxGroup!) {
                  AwesomeDialog(
                    context: context,
                    dialogType: DialogType.warning,
                    animType: AnimType.bottomSlide,
                    title: 'لقد وصلت إلى الحد الأقصى للمجموعات',
                    /*  desc:
              'لا يمكنك إنشاء مجموعات جديدة. يرجى الترقية للاستمتاع بخدمات إضافية.', */
                  ).show();
                  return;
                } else {
                  createGroup();
                }
              },
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _buildActionButton(
              title: "انضمام لمجموعة",
              icon: Icons.group_add_rounded,
              color: AppColors.accentColor,
              onTap: () {
                if (currentGroupsCount != null &&
                    currentGroupsCount! >= maxGroup!) {
                  AwesomeDialog(
                    context: context,
                    dialogType: DialogType.warning,
                    animType: AnimType.bottomSlide,
                    title: 'لقد وصلت إلى الحد الأقصى للمجموعات',
                    /*  desc:
              'لا يمكنك إنشاء مجموعات جديدة. يرجى الترقية للاستمتاع بخدمات إضافية.', */
                  ).show();
                  return;
                } else {
                  joinGroup();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (isMainAdmin)
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, MainAdmin.screenroute);
              },
              child: Text(
                'main admin',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final groups = snapshot.data!.docs;
        currentGroupsCount = groups.length;
        print("Current Groups Count: $currentGroupsCount");
        if (groups.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                "لا توجد مجموعات حالياً",
                style: TextStyle(color: Colors.white.withOpacity(0.4)),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _ModernGroupTile(
              groupId: groups[index].id,
              uid: uid,
              billingService: billingService,
            ),
            childCount: groups.length,
          ),
        );
      },
    );
  }

  Widget _buildModernDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    return Drawer(
      backgroundColor: AppColors.backgroundStart,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.transparent),
            currentAccountPicture: CircleAvatar(
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null ? const Icon(Icons.person) : null,
            ),
            accountName: Text(user?.displayName ?? 'مستخدم Servexia'),
            accountEmail: Text(user?.email ?? ''),
          ),
          _buildDrawerItem(Icons.feedback_outlined, 'الاقتراحات والشكاوى', () {
            _showFeedbackDialog(context);
          }),

          _buildDrawerItem(Icons.share, 'مشاركة التطبيق', () {
            Share.share(
              'جرب تطبيق Servexia لإدارة الصيانة 👷‍♂️🔧\n'
              'حمّل التطبيق من هنا:\n'
              'https://play.google.com/store/apps/details?id=com.masry.maintenance',
              sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
            );
          }),
          _buildDrawerItem(Icons.privacy_tip_outlined, "سياسة الخصوصية", () {
            launchUrl(
              Uri.parse('https://sites.google.com/view/servexia-policy'),
            );
          }),
          _buildDrawerItem(Icons.info_outline, 'عن التطبيق', () {
            _showAboutDialog(context);
          }),
          Spacer(),
          _buildDrawerItem(Icons.logout_rounded, "تسجيل الخروج", () async {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('تأكيد تسجيل الخروج'),
                  content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                      },
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        /*  final prefs = await SharedPreferences.getInstance();
            for (var groupId in groups) {
              await prefs.remove(_localKey('$groupId $uid'));
            } */

                        Navigator.of(
                          context,
                        ).pushReplacementNamed(Login.screenroute);
                      },
                      child: const Text(
                        'تسجيل الخروج',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                );
              },
            );
          }, color: Colors.redAccent),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('الاقتراحات والشكاوى', textAlign: TextAlign.right),
          content: TextField(
            controller: feedbackController,
            maxLines: 5,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'اكتب اقتراحك أو شكواك هنا...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('إرسال', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                if (feedbackController.text.trim().isEmpty) return;

                await FirebaseFirestore.instance.collection('feedback').add({
                  'userId': FirebaseAuth.instance.currentUser?.uid,
                  'email': FirebaseAuth.instance.currentUser?.email,
                  'message': feedbackController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال رسالتك بنجاح 🙏')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color color = Colors.white70,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

class _ModernGroupTile extends StatefulWidget {
  final String groupId;
  final String uid;
  final BillingService billingService;

  const _ModernGroupTile({
    required this.groupId,
    required this.uid,
    required this.billingService,
  });

  @override
  State<_ModernGroupTile> createState() => _ModernGroupTileState();
}

class _ModernGroupTileState extends State<_ModernGroupTile> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final group = snapshot.data!.data() as Map<String, dynamic>;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_center_rounded,
                color: AppColors.primary,
              ),
            ),
            title: Text(
              group['name'] ?? 'مجموعة',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              group['area'] ?? '',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white24,
              size: 18,
            ),
            onTap: () => _handleTap(context, group),
            onLongPress: () async {
              if (group['adminId'] == widget.uid) {
                await showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text(
                        'تأكيد الحذف',
                        style: TextStyle(color: Colors.red),
                      ),
                      content: const Text(
                        'هل أنت متأكد من رغبتك في حذف المجموعة؟ سيؤدي ذلك الى مسح جميع البيانات داخل هذه المجموعة.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await deleteGroupBatch(widget.groupId);
                          },
                          child: const Text(
                            'حذف',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    );
                  },
                );
              } else {
                await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text(
                      'تأكيد المغادرة',
                      style: TextStyle(color: Colors.red),
                    ),
                    content: const Text(
                      'هل أنت متأكد من رغبتك في مغادرة المجموعة؟',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await removeMemberFromGroupAndTeam(
                            groupId: widget.groupId,
                            memberId: widget.uid,
                          );
                          await FirebaseMessaging.instance.unsubscribeFromTopic(
                            widget.groupId,
                          );
                          Navigator.of(context).pop(false);
                        },
                        child: const Text(
                          'مغادرة',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  void _handleTap(BuildContext context, Map<String, dynamic> group) async {
    setState(() {
      isLoading = true;
    });
    // Subscription Logic from original code
    final adminId = group['adminId'];
    final adminDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(adminId)
        .get();
    final expiredAt = (adminDoc.data()?['expiredAt'] as Timestamp?)?.toDate();
    final bool isAdmin = adminId == widget.uid;

    if (expiredAt != null && expiredAt.isBefore(DateTime.now())) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: adminId == widget.uid
            ? 'انتهت صلاحية اشتراكك'
            : 'تم تعليق المجموعة',
        desc: adminId == widget.uid
            ? 'يرجى التجديد للاستمرار'
            : 'تواصل مع المشرف لتجديد الاشتراك',
        btnCancelText: adminId == widget.uid ? 'إلغاء' : null,
        btnOkText: adminId == widget.uid ? 'تجديد الاشتراك' : 'حسنا',
        btnOkOnPress: isAdmin
            ? () {
                widget.billingService.buySubscription();
                print('11111122222333333444455555');
              }
            : () {},
        btnCancelOnPress: adminId == widget.uid ? () {} : null,
      ).show();
      return;
    }

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WorkspaceHomeScreen(workspaceId: group['docId']),
      ),
      (route) => route.isFirst,
    );
    setState(() {
      isLoading = false;
    });
    // ignore: use_build_context_synchronously
    showRateDialog(context);
  }
}

// Keep original Hexagon widgets but with better styling
class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 2;
    path.moveTo(centerX, centerY - radius);
    for (int i = 1; i <= 6; i++) {
      final angle = 2 * math.pi / 6 * i - math.pi / 2;
      path.lineTo(
        centerX + radius * math.cos(angle),
        centerY + radius * math.sin(angle),
      );
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HexagonImage extends StatelessWidget {
  final String imagePath;
  final double size;
  const HexagonImage({super.key, required this.imagePath, this.size = 150.0});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipPath(
        clipper: HexagonClipper(),
        child: Image.asset(imagePath, fit: BoxFit.cover),
      ),
    );
  }
}

removeMemberFromGroupAndTeam({
  required String groupId,
  required String memberId,
}) async {
  print('ahmed kotb');
  final firestore = await FirebaseFirestore.instance;
  await firestore
      .collection('faceEmbedding')
      .doc(groupId)
      .collection('users')
      .doc(uid)
      .delete();

  final teamRef = firestore
      .collection('teams')
      .doc(groupId)
      .collection('members')
      .doc(uid);
  final groupRef = firestore.collection('groups').doc(groupId);

  final batch = firestore.batch();
  batch.delete(teamRef);

  // 🔹 جلب بيانات التيم

  // 🔹 جلب بيانات الجروب
  final groupSnap = await groupRef.get();
  if (groupSnap.exists) {
    final data = groupSnap.data()!;
    final List members = List.from(data['members'] ?? []);

    members.remove(memberId);

    batch.update(groupRef, {'members': members});
    if (data['admins'] != null && (data['admins'] as List).contains(memberId)) {
      final List admins = List.from(data['admins']);
      admins.remove(memberId);
      batch.update(groupRef, {'admins': admins});
    }
  }
  await FirebaseMessaging.instance.unsubscribeFromTopic(groupId);
  await batch.commit();
}

Future<void> deleteGroupBatch(String groupId) async {
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();

  // ===== groups =====
  final groupRef = firestore.collection('groups').doc(groupId);
  batch.delete(groupRef);

  // ===== teams =====
  final teamRef = firestore.collection('teams').doc(groupId);

  final teamsSnapshot = await teamRef.collection('members').get();

  for (final item in teamsSnapshot.docs) {
    batch.delete(item.reference);
  }

  batch.delete(teamRef);
  //=========face =======
  final faceRef = firestore.collection('faceEmbedding').doc(groupId);

  final faceSnapshot = await faceRef.collection('users').get();

  for (final item in faceSnapshot.docs) {
    batch.delete(item.reference);
  }

  // ===== tasks =====
  final tasksRef = firestore.collection('tasks').doc(groupId);
  final taskItemsSnapshot = await tasksRef.collection('items').get();

  for (final item in taskItemsSnapshot.docs) {
    final worksSnapshot = await item.reference.collection('works').get();

    for (final work in worksSnapshot.docs) {
      batch.delete(work.reference);
    }

    batch.delete(item.reference);
  }
  batch.delete(tasksRef);

  // ===== assets =====
  final assetsRef = firestore.collection('assets').doc(groupId);
  final assetItemsSnapshot = await assetsRef.collection('items').get();

  for (final item in assetItemsSnapshot.docs) {
    final worksSnapshot = await item.reference.collection('works').get();

    for (final work in worksSnapshot.docs) {
      batch.delete(work.reference);
    }

    batch.delete(item.reference);
  }
  batch.delete(assetsRef);
  /////////////warehouse///////////////
  final warehouseRef = firestore.collection('inventory').doc(groupId);
  final warehouseItemsSnapshot = await warehouseRef.collection('items').get();

  for (final item in warehouseItemsSnapshot.docs) {
    final worksSnapshot = await item.reference.collection('movements').get();

    for (final work in worksSnapshot.docs) {
      batch.delete(work.reference);
    }

    batch.delete(item.reference);
  }
  batch.delete(warehouseRef);

  // ===== attendance =====
  final attendanceRef = firestore.collection('attendance').doc(groupId);

  final recordsSnapshot = await attendanceRef.collection('records').get();

  for (final record in recordsSnapshot.docs) {
    batch.delete(record.reference);
  }

  batch.delete(attendanceRef);

  // ===== COMMIT =====
  await batch.commit();
}

void _showAboutDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'AboutApp',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'عن التطبيق',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          elevation: 0,
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.build_circle,
                      size: 80,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'تطبيق إدارة الصيانة',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'هذا التطبيق مخصص لإدارة فرق الصيانة بكفاءة عالية، متابعة الأصول والمعدات، تسجيل المهام والأنشطة، تتبع الحضور والانصراف، وتوثيق أعمال الصيانة والتكاليف بطريقة منظمة وسهلة الاستخدام.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 32),
                Divider(color: Colors.grey.shade300, thickness: 1),
                const SizedBox(height: 24),
                const Text(
                  'تم التطوير بواسطة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Al_Ostaz',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '01111995883',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'إغلاق',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, __, child) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}
