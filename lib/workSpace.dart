import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maintenance/Store/store_dashboard_screen.dart';
import 'package:maintenance/addAsset.dart';
import 'package:maintenance/addAwarehouseItem.dart';
import 'package:maintenance/addTask.dart';
import 'package:maintenance/assets.dart';
import 'package:maintenance/attendance.dart';
import 'package:maintenance/homePage.dart';
import 'package:maintenance/invoicePage.dart';
import 'package:maintenance/joinReq.dart';
import 'package:maintenance/customersSuppliers.dart';
import 'package:maintenance/reportPage.dart';
import 'package:maintenance/tasks.dart';
import 'package:maintenance/teamWork.dart';
import 'package:maintenance/warehouseScreen.dart';

Future<String?> aa = FirebaseMessaging.instance.getToken();

class WorkspaceHomeScreen extends StatefulWidget {
  final String workspaceId;
  static const String screenroute = 'workspaceHome';

  const WorkspaceHomeScreen({super.key, required this.workspaceId});

  @override
  State<WorkspaceHomeScreen> createState() => _WorkspaceHomeScreenState();
}

class _WorkspaceHomeScreenState extends State<WorkspaceHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
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

  Map<String, bool> permissions = {
    'المخازن': false,
    'إضافة صنف مخزني': false,
    'الفواتير والمشتريات': false,
    'العملاء والموردين': false,
    'المتجر الإليكتروني': false,
    'الأصول والمعدات': false,
    'إضافة أصل أو معدة': false,
    'إضافة مهمة': false,
    'طلبات الانضمام': false,
  };
  Future<void> _loadExistingPermissions() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('employees_permissions')
          .doc(widget.workspaceId)
          .collection('items')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

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
    } catch (e) {
      debugPrint('Error loading permissions: \$e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadExistingPermissions(); // Load existing permissions
    _initializeAnimations();
    _loadWorkspace();
    getDeviceToken(); // Call the method to get the device token
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
          _loading = false;
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
                'لم يتم العثور على بيانات المساحة',
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

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16, left: 8, right: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 40, 110, 189),
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
          colors: [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['name'] ?? 'مساحة العمل',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
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
                  color: Colors.greenAccent.withOpacity(0.2),
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

  Widget _buildDashboard(bool isAdmin) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('إدارة المخازن والمبيعات'),
              GridView(
                shrinkWrap:
                    true, // Important for GridView inside SingleChildScrollView
                physics:
                    const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.15,
                ),
                children: [
                  // Admin Cards for Inventory and Sales
                  if (isAdmin && permissions['المخازن'] == true)
                    _buildDashboardCard(
                      icon: Icons.warehouse,
                      title: 'المخازن',
                      color: const Color.fromARGB(255, 14, 9, 141),
                      onTap: () => _navigateTo(
                        StoreScreen(
                          groupId: widget.workspaceId,
                          isFromInvoice: false,
                          deletedItems: false,
                          invoiceType: '',
                          customerId: '',
                          isEditMode: false,
                          itemsPurchase: [],
                        ),
                      ),
                    ),
                  if (isAdmin && permissions['إضافة صنف مخزني'] == true)
                    _buildDashboardCard(
                      icon: Icons.warehouse_outlined,
                      title: 'إضافة صنف مخزني',
                      color: const Color.fromARGB(255, 9, 72, 233),
                      onTap: () => _navigateTo(
                        AddInventoryItemScreen(
                          groupId: widget.workspaceId,
                          invoiceType: '',
                          isFromInvoice: false,
                          customerId: '',
                          isEditMode: false,
                          itemsPurchase: [],
                        ),
                      ),
                    ),
                  if (isAdmin && permissions['الفواتير والمشتريات'] == true)
                    _buildDashboardCard(
                      icon: Icons.receipt_long,
                      title: 'الفواتير والمشتريات',
                      color: const Color.fromARGB(255, 66, 121, 3),
                      onTap: () => _navigateTo(
                        InvoicePage(
                          groupId: widget.workspaceId,
                          itemsSale: [],
                          itemsPurchase: [],
                          name: '',
                          phone: '',
                          address: '',
                          customerId: '',
                          isFromConstCustomers: false,
                          isFromWorkSpace: true,
                          type: 'بيع',
                          isFormStore: false,
                          isEditMode: false,
                        ),
                      ),
                    ),
                  if (isAdmin && permissions['العملاء والموردين'] == true)
                    _buildDashboardCard(
                      icon: Icons.account_balance_wallet,
                      title: 'العملاء والموردين',
                      color: const Color.fromARGB(255, 7, 108, 162),
                      onTap: () => _navigateTo(
                        CustomersSuppliers(
                          groupId: widget.workspaceId,
                          isFromInvoice: false,
                          itemsSale: [],
                          itemsPruchase: [],
                          invoiceType: '',
                          isEditMode: false,
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 10),

              if (isAdmin && permissions['المتجر الإليكتروني'] == true)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.25),
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
                        _navigateTo(
                          StoreDashboardScreen(groupId: widget.workspaceId),
                        );
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
              GridView(
                shrinkWrap:
                    true, // Important for GridView inside SingleChildScrollView
                physics:
                    const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.15,
                ),
                children: [
                  // Admin Cards for Maintenance and HR
                  if (isAdmin && permissions['الأصول والمعدات'] == true)
                    _buildDashboardCard(
                      icon: Iconsax.building_4,
                      title: 'الأصول والمعدات',
                      color: const Color.fromARGB(255, 126, 6, 98),
                      onTap: () => _navigateTo(
                        AssetsScreen(groupId: widget.workspaceId),
                      ),
                    ),
                  if (isAdmin && permissions['إضافة أصل أو معدة'] == true)
                    _buildDashboardCard(
                      icon: Icons.precision_manufacturing,
                      title: 'إضافة أصل أو معدة',
                      color: const Color.fromARGB(255, 139, 10, 194),
                      onTap: () => _navigateTo(
                        AddAssetScreen(groupId: widget.workspaceId),
                      ),
                    ),
                  // Common Cards
                  _buildDashboardCard(
                    icon: Icons.assignment,
                    title: 'المهام والأعطال',
                    color: Colors.blue,
                    onTap: () => _navigateTo(
                      TasksScreen(
                        groupId: widget.workspaceId,
                        isAdmin: isAdmin,
                      ),
                    ),
                  ),
                  // Admin Add Task Card
                  if (isAdmin && permissions['إضافة مهمة'] == true)
                    _buildDashboardCard(
                      icon: Icons.add_circle,
                      title: 'إضافة مهمة',
                      color: const Color.fromARGB(255, 97, 12, 108),
                      onTap: () {
                        _navigateTo(
                          AddTaskScreen(
                            groupId: widget.workspaceId,
                            fromConstTasks: false,
                            description: TextEditingController(),
                            title: TextEditingController(),
                          ),
                        );
                        print(
                          '111111111111111111111 ${'aa'}',
                        ); // Debug: Print FCM token
                      },
                    ),
                  _buildDashboardCard(
                    icon: Icons.handyman,
                    title: 'الابلاغ عن الاعطال',
                    color: const Color.fromARGB(255, 126, 34, 34),
                    onTap: () =>
                        _navigateTo(AddReportPage(groupId: widget.workspaceId)),
                  ),
                  _buildDashboardCard(
                    icon: Icons.group,
                    title: 'الفريق',
                    color: Colors.green,
                    onTap: () => _navigateTo(
                      TeamScreen(
                        groupId: widget.workspaceId,
                        adminId: workspaceData!['adminId'] ?? '',
                        isXadmin: workspaceData!['adminId'] == uid,
                        isAdmin: isAdmin,
                      ),
                    ),
                  ),
                  _buildDashboardCard(
                    icon: Icons.badge,
                    title: 'الحضور والانصراف',
                    color: const Color.fromARGB(255, 6, 104, 160),
                    onTap: () => _navigateTo(
                      DailyAttendanceScreen(
                        groupId: widget.workspaceId,
                        isAdmin: isAdmin,
                      ),
                    ),
                  ),
                  // Admin Join Requests Card with Badge
                  if (isAdmin && permissions['طلبات الانضمام'] == true)
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
                          onTap: () => _navigateTo(
                            AdminApprovalPage(groupId: widget.workspaceId),
                          ),
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

  Future<void> _navigateTo(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,

    int badgeCount = 0,
  }) {
    return Card(
      elevation: 6,
      shadowColor: color.withOpacity(0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 32, color: color),
                  ),

                  /// Badge Notification
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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
