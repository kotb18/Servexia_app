import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maintenance/homePage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> aa = FirebaseMessaging.instance.getToken();
String? creatorId;
String? planId;

class WorkspaceHomeScreen extends StatefulWidget {
  final String workspaceId;
  final String country;
  static const String screenroute = 'workspaceHome';
  const WorkspaceHomeScreen({
    super.key,
    required this.workspaceId,
    required this.country,
  });

  @override
  State<WorkspaceHomeScreen> createState() => _WorkspaceHomeScreenState();
}

class _WorkspaceHomeScreenState extends State<WorkspaceHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _isDarkMode = false;
  bool _isListView = false;

  String get _displayPreferencePrefix =>
      'workspace_home_${Uri.encodeComponent(widget.workspaceId)}_';
  String get _darkModePreferenceKey => '${_displayPreferencePrefix}dark_mode';
  String get _listViewPreferenceKey => '${_displayPreferencePrefix}list_view';

  List<Color> get _headerGradientColors => _isDarkMode
      ? const [Color(0xFF123B5D), Color(0xFF0F766E)]
      : const [Color(0xFF42A5F5), Color(0xFF1E88E5)];
  Map<String, dynamic>? workspaceData;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? deviceToken;
  Future<void> getDeviceToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    setState(() {
      deviceToken = token;
    });
    print("Device FCM Token: $deviceToken");
  }

  final Map<String, bool> permissions = {
    'المخازن': false,
    'إضافة صنف مخزني': false,
    'الفواتير والمشتريات': false,
    'العملاء والموردين': false,
    'المتجر الإليكتروني': false,
    'الأصول والمعدات': false,
    'إضافة أصل أو معدة': false,
    'إضافة مهمة': false,
    'إنهاء المهام': false,
    'طلبات الانضمام': false,
    'الحضور والانصراف': false,
  };
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _permissionsSubscription;

  void _listenToPermissions() {
    print('Listening to permissions: ${widget.workspaceId}');

    _permissionsSubscription = FirebaseFirestore.instance
        .collection('employees_permissions')
        .doc(widget.workspaceId)
        .collection('items')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen(
          (doc) {
            if (!mounted) return;

            if (doc.exists && doc.data() != null) {
              final data = doc.data()!;

              setState(() {
                permissions.forEach((key, value) {
                  if (data.containsKey(key)) {
                    permissions[key] = data[key] ?? false;
                  }
                });
              });
            }
          },
          onError: (error) {
            debugPrint('Error loading permissions: $error');
          },
        );
  }

  @override
  void initState() {
    super.initState();
    print('cccccccccccccccccccc${widget.workspaceId}');
    print('bbbbbbbbbbbbbbbbbbbbbb${widget.country}');
    _listenToPermissions(); // Load existing permissions
    _loadDisplayPreferences();
    _initializeAnimations();
    _loadWorkspace();
    getDeviceToken(); // Call the method to get the device token
  }

  Future<void> _loadDisplayPreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _isDarkMode = preferences.getBool(_darkModePreferenceKey) ?? false;
        _isListView = preferences.getBool(_listViewPreferenceKey) ?? false;
      });
    } catch (error) {
      debugPrint('Failed to load display preferences: $error');
    }
  }

  Future<void> _saveDisplayPreference(String key, bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, value);
    } catch (error) {
      debugPrint('Failed to save display preference: $error');
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _permissionsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.workspaceId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          workspaceData = doc.data();
          creatorId = workspaceData!['adminId'] ?? '';
          _loading = false;
        });
        final doc2 = await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorId)
            .get();

        if (!doc2.exists) {
          return;
        }
        setState(() {
          final data2 = doc2.data();
          planId = data2!['id'] ?? 'main';
          print('llllllllllllllllllllllll$planId');
        });
      } else {
        setState(() {
          _loading = false;
        });
        _showErrorSnackbar('لم يتم العثور على بيانات المساحة');
      }
    } catch (e) {
      debugPrint('Load workspace error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _showErrorSnackbar('حدث خطأ في تحميل البيانات');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 3)),
      );
    }

    if (workspaceData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'لم يتم العثور على بيانات المجموعة',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadWorkspace,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة محاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final data = workspaceData!;
    final bool isAdmin = data['admins'][0] == uid ? true : false;

    final baseTheme = Theme.of(context);
    final pageTheme = _isDarkMode
        ? ThemeData.dark(useMaterial3: baseTheme.useMaterial3).copyWith(
            colorScheme:
                ColorScheme.fromSeed(
                  seedColor: const Color(0xFF0F9D91),
                  brightness: Brightness.dark,
                ).copyWith(
                  surface: const Color(0xFF172536),
                  onSurface: const Color(0xFFF1F5F9),
                ),
            scaffoldBackgroundColor: const Color(0xFF0B1220),
            canvasColor: const Color(0xFF0B1220),
            cardColor: const Color(0xFF172536),
          )
        : baseTheme;

    return Theme(
      data: pageTheme,
      child: PopScope(
        canPop: false, // ممنوع يرجع بالرجوع الافتراضي
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.go('/home?isAdmin=$isAdmin');
        },
        child: Scaffold(
          backgroundColor: _isDarkMode
              ? const Color(0xFF0B1220)
              : const Color(0xFFF3F6FB),
          body: SafeArea(
            child: Column(
              children: [
                /// 🔷 HEADER
                _buildHeader(data),
                const SizedBox(height: 16),

                /// 📊 DASHBOARD
                Expanded(child: _buildDashboard(isAdmin)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16, left: 8, right: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _isDarkMode
                ? const Color(0xFF7DD3FC)
                : const Color(0xFF286EBD),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _headerGradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: _headerGradientColors.last.withValues(alpha: 0.32),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  final isAdmin = data['admins'][0] == uid;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => Homepage(isAdmin: isAdmin),
                    ),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['name'] ?? 'مساحة العمل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'إعدادات العرض',
                onPressed: _showDisplaySettings,
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (data['admins'][0] == uid)
            InkWell(
              onTap: () {
                _handleEditeGroupName(
                  data,
                  TextEditingController(text: data['name']?.toString() ?? ''),
                  context,
                );
              },
              child: Text(
                'لتعديل اسم المجموعة اضغط هنا.',
                style: TextStyle(
                  color: const Color.fromARGB(255, 187, 210, 222),
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.blue,
                  decorationThickness: 2,
                ),
              ),
            ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data['area'] ?? 'غير محدد',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'نشطة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleEditeGroupName(
    Map<String, dynamic> data,
    TextEditingController name,
    BuildContext dialogContext,
  ) {
    showDialog(
      context: dialogContext,
      builder: (dialogContext) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'تغيير اسم المجموعة',
                textAlign: TextAlign.center,
              ),
              content: TextField(
                controller: name,
                autofocus: true,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'اسم المجموعة',
                  hintText: 'اكتب اسم المجموعة',
                  prefixIcon: const Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: () {
                  name.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: name.text.length,
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('إلغاء'),
                ),

                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (name.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('من فضلك أدخل اسم المجموعة'),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            isLoading = true;
                          });

                          try {
                            final newName = name.text.trim();

                            await FirebaseFirestore.instance
                                .collection('groups')
                                .doc(data['docId'])
                                .update({'name': newName});

                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            setState(() {
                              isLoading = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('حدث خطأ أثناء الحفظ: $e'),
                              ),
                            );
                          }
                        },
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isLoading ? 'جاري الحفظ...' : 'حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDashboard(bool isAdmin) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (permissions['المخازن'] == true ||
                  permissions['إضافة صنف مخزني'] == true ||
                  permissions['الفواتير والمشتريات'] == true ||
                  permissions['العملاء والموردين'] == true ||
                  permissions['المتجر الإليكتروني'] == true)
                _buildSectionHeader('إدارة المخازن والمبيعات'),
              _buildDashboardCards(
                maxCrossAxisExtent: 220,
                children: [
                  // Admin Cards for Inventory and Sales
                  if (permissions['المخازن'] == true)
                    _buildDashboardCard(
                      icon: Icons.warehouse,
                      title: 'المخازن',
                      color: const Color.fromARGB(255, 14, 9, 141),
                      onTap: () => _goTo(
                        '/store/${Uri.encodeComponent(widget.workspaceId)}?country=${Uri.encodeComponent(widget.country)}',
                      ),
                    ),
                  if (permissions['إضافة صنف مخزني'] == true)
                    _buildDashboardCard(
                      icon: Icons.warehouse_outlined,
                      title: 'إضافة صنف مخزني',
                      color: const Color.fromARGB(255, 9, 72, 233),
                      onTap: () => _goTo(
                        '/add-inventory/${widget.workspaceId}?isFromWarehouseScreen=true',
                      ),
                    ),
                  if (permissions['الفواتير والمشتريات'] == true)
                    _buildDashboardCard(
                      icon: Icons.receipt_long,
                      title: 'الفواتير والمشتريات',
                      color: const Color.fromARGB(255, 66, 121, 3),
                      onTap: () => _goTo(
                        '/invoice?groupId=${widget.workspaceId}&isFromWorkSpace=true&type=بيع',
                      ),
                    ),
                  if (permissions['العملاء والموردين'] == true)
                    _buildDashboardCard(
                      icon: Icons.account_balance_wallet,
                      title: 'العملاء والموردين',
                      color: const Color.fromARGB(255, 7, 108, 162),
                      onTap: () =>
                          _goTo('/customers-suppliers/${widget.workspaceId}'),
                    ),
                ],
              ),

              SizedBox(height: 10),

              if (permissions['المتجر الإليكتروني'] == true)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: _headerGradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _headerGradientColors.last.withValues(
                          alpha: 0.28,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        _goTo('/store-dashboard/${widget.workspaceId}');
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.store, color: Colors.white, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'المتجـــر الإليكتروني',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              _buildSectionHeader('إدارة الصيانة والموارد البشرية'),
              _buildDashboardCards(
                maxCrossAxisExtent: kIsWeb ? 180 : 220,
                children: [
                  // Admin Cards for Maintenance and HR
                  if (permissions['الأصول والمعدات'] == true)
                    _buildDashboardCard(
                      icon: Iconsax.building_4,
                      title: 'الأصول والمعدات',
                      color: const Color.fromARGB(255, 126, 6, 98),
                      onTap: () => _goTo('/assets/${widget.workspaceId}'),
                    ),
                  if (permissions['إضافة أصل أو معدة'] == true)
                    _buildDashboardCard(
                      icon: Icons.precision_manufacturing,
                      title: 'إضافة أصل أو معدة',
                      color: const Color.fromARGB(255, 139, 10, 194),
                      onTap: () => _goTo('/add-asset/${widget.workspaceId}'),
                    ),
                  // Common Cards
                  _buildDashboardCard(
                    icon: Icons.assignment,
                    title: 'المهام والأعطال',
                    color: Colors.blue,
                    onTap: () => _goTo(
                      '/tasks/${widget.workspaceId}?isAdmin=$isAdmin&isFinishTasks=${permissions['إنهاء المهام']}',
                    ),
                  ),
                  // Admin Add Task Card
                  if (permissions['إضافة مهمة'] == true)
                    _buildDashboardCard(
                      icon: Icons.add_circle,
                      title: 'إضافة مهمة',
                      color: const Color.fromARGB(255, 97, 12, 108),
                      onTap: () {
                        _goTo('/add-task?groupId=${widget.workspaceId}');
                        print(
                          '111111111111111111111 ${'aa'}',
                        ); // Debug: Print FCM token
                      },
                    ),
                  _buildDashboardCard(
                    icon: Icons.handyman,
                    title: 'الابلاغ عن الاعطال',
                    color: const Color.fromARGB(255, 126, 34, 34),
                    onTap: () => _goTo('/add-report/${widget.workspaceId}'),
                  ),
                  _buildDashboardCard(
                    icon: Icons.group,
                    title: 'الفريق',
                    color: Colors.green,
                    onTap: () => _goTo(
                      '/team/${widget.workspaceId}?adminId=${Uri.encodeQueryComponent((workspaceData!['adminId'] ?? '').toString())}&isXadmin=${workspaceData!['adminId'] == uid}&isAdmin=$isAdmin',
                    ),
                  ),
                  if (permissions['الحضور والانصراف'] == true)
                    _buildDashboardCard(
                      icon: Icons.badge,
                      title: 'الحضور والانصراف',
                      color: const Color.fromARGB(255, 6, 104, 160),
                      onTap: () => _goTo(
                        '/attendance/${widget.workspaceId}?isAdmin=$isAdmin',
                      ),
                    ),
                  // Admin Join Requests Card with Badge
                  if (permissions['طلبات الانضمام'] == true)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('teams')
                          .doc(widget.workspaceId)
                          .collection('members')
                          .where(
                            'confirm',
                            isEqualTo: false,
                          ) // فلترة من السيرفر 🔥
                          .snapshots(),
                      builder: (context, snapshot) {
                        int notificationCount = 0;

                        if (snapshot.hasData) {
                          notificationCount = snapshot.data!.docs.length;
                        }

                        return _buildDashboardCard(
                          icon: Icons.person_add,
                          title: 'طلبات الانضمام',
                          color: const Color.fromARGB(255, 16, 10, 194),
                          badgeCount: notificationCount,
                          onTap: () =>
                              _goTo('/admin-approval/${widget.workspaceId}'),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCards({
    required List<Widget> children,
    required double maxCrossAxisExtent,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (_isListView) {
      return Column(
        children: [
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(height: 86, child: child),
            ),
        ],
      );
    }
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.12,
      ),
      children: children,
    );
  }

  void _showDisplaySettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final dark = _isDarkMode;
          const lightText = Color(0xFF172033);
          const darkText = Color(0xFFF1F5F9);
          const mutedLight = Color(0xFF64748B);
          const mutedDark = Color(0xFFCBD5E1);
          final panelColor = dark ? const Color(0xFF172536) : Colors.white;
          final titleColor = dark ? darkText : lightText;
          final mutedColor = dark ? mutedDark : mutedLight;
          final accentColor = dark
              ? const Color(0xFF67E8F9)
              : const Color(0xFF286EBD);
          final sheetTheme = dark
              ? ThemeData.dark(useMaterial3: true).copyWith(
                  colorScheme:
                      ColorScheme.fromSeed(
                        seedColor: const Color(0xFF0F9D91),
                        brightness: Brightness.dark,
                      ).copyWith(
                        surface: panelColor,
                        onSurface: darkText,
                        primary: accentColor,
                      ),
                )
              : ThemeData.light(useMaterial3: true).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF286EBD),
                    brightness: Brightness.light,
                  ),
                );

          return Theme(
            data: sheetTheme,
            child: Container(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF2B4055)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'إعدادات العرض',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          dark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: accentColor,
                        ),
                        title: Text(
                          'الوضع الداكن',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          dark ? 'مظهر داكن مريح للعين' : 'مظهر فاتح وواضح',
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                        activeColor: accentColor,
                        value: dark,
                        onChanged: (value) {
                          setState(() => _isDarkMode = value);
                          setSheetState(() {});
                          unawaited(
                            _saveDisplayPreference(
                              _darkModePreferenceKey,
                              value,
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 8,
                        color: dark
                            ? const Color(0xFF2B4055)
                            : const Color(0xFFE2E8F0),
                      ),
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        groupValue: _isListView,
                        activeColor: accentColor,
                        secondary: Icon(
                          Icons.grid_view_rounded,
                          color: _isListView ? mutedColor : accentColor,
                        ),
                        title: Text(
                          'عرض شبكي',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'بطاقات في شبكة',
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _isListView = value);
                          setSheetState(() {});
                          unawaited(
                            _saveDisplayPreference(
                              _listViewPreferenceKey,
                              value,
                            ),
                          );
                        },
                      ),
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        groupValue: _isListView,
                        activeColor: accentColor,
                        secondary: Icon(
                          Icons.view_list_rounded,
                          color: _isListView ? accentColor : mutedColor,
                        ),
                        title: Text(
                          'عرض قائمة',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'بطاقات ممتدة لسهولة القراءة',
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _isListView = value);
                          setSheetState(() {});
                          unawaited(
                            _saveDisplayPreference(
                              _listViewPreferenceKey,
                              value,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _goTo(String location) => context.push(location);

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final dark = _isDarkMode;
    final accentColor = dark
        ? HSLColor.fromColor(
            color,
          ).withSaturation(0.78).withLightness(0.72).toColor()
        : color;
    final iconSize = _isListView ? 24.0 : 32.0;
    final iconPadding = _isListView ? 11.0 : 16.0;

    final iconBadge = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.all(iconPadding),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: dark ? 0.20 : 0.13),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: iconSize, color: accentColor),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -5,
            right: -7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dark ? const Color(0xFF172536) : Colors.white,
                  width: 2,
                ),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );

    return Card(
      color: dark ? const Color(0xFF172536) : Colors.white,
      elevation: dark ? 2 : 4,
      shadowColor: accentColor.withValues(alpha: dark ? 0.16 : 0.18),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark ? const Color(0xFF2B4055) : const Color(0xFFE8EDF5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: accentColor.withValues(alpha: 0.12),
        child: Padding(
          padding: EdgeInsets.all(_isListView ? 12 : 16),
          child: _isListView
              ? Row(
                  children: [
                    iconBadge,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: dark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: dark ? const Color(0xFF94A3B8) : Colors.black38,
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconBadge,
                    const SizedBox(height: 13),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: dark ? const Color(0xFFF1F5F9) : Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/* Widget _buildDashboardCard2({
  required IconData icon,
  required String title,
  required Color color,
  required VoidCallback onTap,
  int? badgeCount,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 40, color: color),
              if (badgeCount != null && badgeCount > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}
 */
