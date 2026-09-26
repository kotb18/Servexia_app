import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:maintenance/JoinGroup.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'package:maintenance/Store/inventory_store_service.dart';
import 'package:maintenance/Store/store_product_detail_screen.dart';
import 'package:maintenance/addAsset.dart';
import 'package:maintenance/addAwarehouseItem.dart';
import 'package:maintenance/addTask.dart';
import 'package:maintenance/admin/feedBack.dart';
import 'package:maintenance/admin/groups.dart';
import 'package:maintenance/admin/mainAdmin.dart';
import 'package:maintenance/assets.dart';
import 'package:maintenance/attendance.dart';
import 'package:maintenance/createGroup.dart' hide billingService;
import 'package:maintenance/firebase_options.dart';
import 'package:maintenance/homePage.dart';
import 'package:maintenance/invoiceSettings.dart';
import 'package:maintenance/joinReq.dart';
import 'package:maintenance/customersSuppliers.dart';
import 'package:maintenance/reportPage.dart';
import 'package:maintenance/invoicePage.dart';
import 'package:maintenance/signIn.dart';
import 'package:maintenance/splashScreen.dart';
import 'package:maintenance/tasks.dart';
import 'package:maintenance/teamWork.dart';
import 'package:maintenance/termsAndConditions.dart';
import 'package:maintenance/updateVersion.dart';
import 'package:maintenance/wareHouseItemeMovement.dart';
import 'package:maintenance/warehouseScreen.dart';
import 'package:maintenance/workSpace.dart';
import 'package:maintenance/services/billing_service.dart';
import 'package:maintenance/Store/store_home_screen.dart';
import 'package:maintenance/Store/store_dashboard_screen.dart';
import 'package:maintenance/Store/store_cart_screen.dart';
import 'package:maintenance/Store/store_setup_screen.dart';
import 'package:maintenance/Store/select_products_screen.dart';
import 'package:maintenance/Store/store_orders_screen.dart';
import 'package:maintenance/Store/store_preview_screen.dart';
import 'package:maintenance/Store/customer_orders_screen.dart';
import 'package:maintenance/Store/store_checkout_screen.dart';
import 'package:maintenance/Store/store_cart_service.dart';
import 'package:provider/provider.dart';

// ✅ Conditional import للـ Platform Setup
import 'mobile_setup.dart' if (dart.library.html) 'web_setup.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

bool _notificationsInitialized = false;

Future<void> _initializeNotifications() async {
  if (_notificationsInitialized) return;

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings = InitializationSettings(
    android: androidSettings,
  );

  await _notifications.initialize(settings: initializationSettings);

  const channel = AndroidNotificationChannel(
    'task_reminders',
    'تنبيهات المهام',
    description: 'تنبيهات مواعيد بدء المهام',
    importance: Importance.high,
  );

  final androidNotifications = _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidNotifications?.createNotificationChannel(channel);
  await androidNotifications?.requestNotificationsPermission();

  _notificationsInitialized = true;
}

Future<void> scheduleTaskReminder({
  required String taskId,
  required String taskTitle,
  required DateTime startTime,
  int reminderMinutes = 15,
}) async {
  if (taskId.trim().isEmpty || taskTitle.trim().isEmpty) {
    debugPrint('⚠️ لا يمكن جدولة تنبيه بدون taskId أو عنوان المهمة');
    return;
  }

  if (reminderMinutes < 0) {
    debugPrint('⚠️ عدد دقائق التذكير لا يمكن أن يكون سالبًا');
    return;
  }

  await _initializeNotifications();

  final now = DateTime.now();
  final reminderTime = startTime.subtract(Duration(minutes: reminderMinutes));

  // لا نستخدم isBefore فقط؛ الوقت الحالي نفسه لا يصلح للجدولة أيضًا.
  if (!reminderTime.isAfter(now)) {
    debugPrint('⚠️ وقت التنبيه عدى بالفعل: $reminderTime');
    return;
  }

  // تحويل الوقت إلى المنطقة الزمنية المهيأة قبل إرساله إلى الإضافة.
  final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
  final notificationId = taskId.hashCode & 0x7fffffff;

  const notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders',
      'تنبيهات المهام',
      channelDescription: 'تنبيهات مواعيد بدء المهام',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    ),
  );

  await _notifications.zonedSchedule(
    id: notificationId,
    title: 'تنبيه مهمة',
    body: '$taskTitle ستبدأ بعد $reminderMinutes دقيقة',
    scheduledDate: scheduledDate,
    notificationDetails: notificationDetails,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    payload: 'task:$taskId',
  );

  debugPrint('✅ تم جدولة تنبيه المهمة: $taskTitle');
  debugPrint('⏰ وقت التنبيه: $scheduledDate');
  debugPrint('🆔 Notification ID: $notificationId');
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ============================================================
  // هذه الدالة تعمل عندما تصل رسالة FCM والتطبيق في الخلفية
  // أو مغلق.
  //
  // يجب تهيئة Firebase داخل الـ Background Isolate.
  // ============================================================

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ============================================================
  // نتأكد أن الرسالة خاصة بجدولة مهمة
  // ============================================================

  if (message.data['type'] != 'schedule_task') {
    return;
  }

  // ============================================================
  // قراءة بيانات المهمة القادمة من FCM
  // ============================================================

  final taskId = message.data['taskId'];
  final taskTitle = message.data['title'];

  final taskDateTimeString = message.data['taskDateTime'];

  final reminderMinutes =
      int.tryParse(message.data['reminderMinutes'] ?? '15') ?? 15;

  // ============================================================
  // التأكد من وجود البيانات المطلوبة
  // ============================================================

  if (taskId == null || taskTitle == null || taskDateTimeString == null) {
    return;
  }

  // ============================================================
  // تحويل وقت المهمة من String إلى DateTime
  // ============================================================

  final taskDateTime = DateTime.tryParse(taskDateTimeString);
  if (taskDateTime == null) {
    debugPrint('⚠️ تاريخ المهمة غير صالح: $taskDateTimeString');
    return;
  }

  // ============================================================
  // جدولة التنبيه محليًا على هاتف الموظف
  // ============================================================

  await scheduleTaskReminder(
    taskId: taskId,
    taskTitle: taskTitle,
    startTime: taskDateTime,
    reminderMinutes: reminderMinutes,
  );
}

Future<void> main() async {
  // ============================================================
  // 1️⃣ تجهيز Flutter قبل تشغيل أي Plugin
  // ============================================================

  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // 2️⃣ إعداد GoRouter
  // ============================================================

  GoRouter.optionURLReflectsImperativeAPIs = true;

  // ============================================================
  // 3️⃣ إعدادات الـ Platform الخاصة بتطبيقك
  // ============================================================

  await PlatformSetup.init();

  // ============================================================
  // 4️⃣ تهيئة Firebase
  // ============================================================

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ============================================================
  // 5️⃣ تهيئة Firebase Cloud Messaging
  // ============================================================

  final FirebaseMessaging fcm = FirebaseMessaging.instance;

  // ============================================================
  // 6️⃣ طلب صلاحية الإشعارات من المستخدم
  //
  // خصوصًا Android 13+
  // ============================================================

  await fcm.requestPermission(alert: true, badge: true, sound: true);

  // ============================================================
  // 7️⃣ استقبال الإشعارات عندما يكون التطبيق مفتوحًا
  //
  // هنا يمكنك التعامل مع الإشعار إذا كان التطبيق Foreground.
  //
  // لاحظ أن الـ Data Message الخاصة بجدولة المهمة
  // سيتم التعامل معها أيضًا من خلال البيانات.
  // ============================================================

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground message: ${message.messageId}');

    debugPrint('Title: ${message.notification?.title}');

    debugPrint('Body: ${message.notification?.body}');

    debugPrint('Data: ${message.data}');

    if (message.data['type'] == 'schedule_task') {
      final taskId = message.data['taskId'];
      final taskTitle = message.data['title'];
      final taskDateTimeString = message.data['taskDateTime'];
      final taskDateTime = taskDateTimeString == null
          ? null
          : DateTime.tryParse(taskDateTimeString);
      final reminderMinutes =
          int.tryParse(message.data['reminderMinutes'] ?? '15') ?? 15;

      if (taskId != null && taskTitle != null && taskDateTime != null) {
        scheduleTaskReminder(
          taskId: taskId,
          taskTitle: taskTitle,
          startTime: taskDateTime,
          reminderMinutes: reminderMinutes,
        );
      }
    }
  });

  // ============================================================
  // 8️⃣ تسجيل Background Handler
  //
  // مهم جدًا:
  // الدالة يجب أن تكون خارج main()
  // وأن تكون Top-Level Function.
  //
  // لذلك وضعنا:
  //
  // @pragma('vm:entry-point')
  //
  // فوقها.
  // ============================================================

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ============================================================
  // 9️⃣ تشغيل التطبيق
  // ============================================================

  runApp(
    Provider<BillingService>(
      create: (_) => billingService,
      dispose: (_, service) => service.dispose(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Servexia',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'AE')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: "ElMessiri",
      ),
      routerConfig: _router,
    );
  }
}

// GoRouter Configuration
bool _showSplashOnStartup = true;

final GoRouter _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // Keep the original startup flow: the app always starts at SplashScreen.
    // The only preserved deep link is the public store URL, which SplashScreen
    // supported before the router migration.
    if (_showSplashOnStartup) {
      _showSplashOnStartup = false;
      if (state.uri.path != '/') {
        final queryParameters = state.uri.path.startsWith('/shop/')
            ? {'shopLink': state.uri.toString()}
            : <String, String>{};
        return Uri(path: '/', queryParameters: queryParameters).toString();
      }
    }
    return null;
  },
  routes: [
    // SplashScreen - دايماً يفتح أولاً
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/legacy',
      name: 'legacy',
      builder: (context, state) {
        final page = state.extra;
        return page is Widget ? page : const SplashScreen();
      },
    ),

    // صفحة المتجر من لينك خارجي
    GoRoute(
      path: '/shop/:groupId',
      name: 'shop',
      builder: (context, state) {
        final groupId = Uri.decodeComponent(
          (state.pathParameters['groupId'] ?? '').trim(),
        );

        debugPrint('🌐 SHOP ROUTE');
        debugPrint('📍 Location: ${state.uri}');
        debugPrint('🆔 groupId: "$groupId"');

        return StoreHomeScreen(groupId: groupId, isPreview: false);
      },
    ),
    GoRoute(
      path: '/store-dashboard/:groupId',
      name: 'storeDashboard',
      builder: (context, state) =>
          StoreDashboardScreen(groupId: state.pathParameters['groupId'] ?? ''),
    ),
    GoRoute(
      path: '/store-dashboard/:groupId/setup',
      name: 'storeSetup',
      builder: (context, state) => StoreSetupScreen(
        groupId: state.pathParameters['groupId'] ?? '',
        isFromSettings: state.uri.queryParameters['isFromSettings'] == 'true',
      ),
    ),
    GoRoute(
      path: '/store-dashboard/:groupId/products',
      name: 'storeProducts',
      builder: (context, state) =>
          SelectProductsScreen(groupId: state.pathParameters['groupId'] ?? ''),
    ),
    GoRoute(
      path: '/store-dashboard/:groupId/orders',
      name: 'storeOrders',
      builder: (context, state) =>
          StoreOrdersScreen(storeId: state.pathParameters['groupId'] ?? ''),
    ),
    GoRoute(
      path: '/store-dashboard/:groupId/preview',
      name: 'storePreview',
      builder: (context, state) => StorePreviewScreen(
        groupId: state.pathParameters['groupId'] ?? '',
        storeName: state.uri.queryParameters['storeName'] ?? '',
      ),
    ),
    GoRoute(
      path: '/shop/:groupId/cart',
      name: 'storeCart',
      builder: (context, state) => StoreCartScreen(
        groupId: state.pathParameters['groupId'] ?? '',
        shippingFee:
            double.tryParse(state.uri.queryParameters['shippingFee'] ?? '') ??
            0,
        makeSetStateOnCartChange: false,
        deviceTokrn: state.uri.queryParameters['deviceToken'] ?? '',
      ),
    ),
    GoRoute(
      path: '/shop/:groupId/orders',
      name: 'customerOrders',
      builder: (context, state) => MyOrdersScreen(
        customerId: state.uri.queryParameters['customerId'] ?? '',
        groupId: state.pathParameters['groupId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/shop/:groupId/checkout',
      name: 'storeCheckout',
      builder: (context, state) => StoreCheckoutScreen(
        cartService: StoreCartService(),
        groupId: state.pathParameters['groupId'] ?? '',
        shippingFee:
            double.tryParse(state.uri.queryParameters['shippingFee'] ?? '') ??
            0,
        deviceTokrn: state.uri.queryParameters['deviceToken'] ?? '',
      ),
    ),
    GoRoute(
      path: '/shop/:groupId/product/:sku',
      name: 'productDetail',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        final sku = state.pathParameters['sku'] ?? '';
        final service = InventoryStoreService();

        return FutureBuilder<InventoryItemModel?>(
          future: service.getItemById(groupId, sku), // أو getItemBySku
          builder: (context, snapshot) {
            // Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // خطأ
            if (snapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('خطأ: ${snapshot.error}')),
              );
            }

            // مش موجود
            if (!snapshot.hasData || snapshot.data == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'المنتج غير موجود',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.go('/shop/$groupId'),
                        child: const Text('الرجوع للمتجر'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ✅ المنتج موجود
            return StoreProductDetailScreen(
              groupId: groupId,
              item: snapshot.data!,
              shippingFee:
                  0.0, // <-- يمكنك تعديل قيمة رسوم الشحن هنا إذا لزم الأمر
              deviceToken: state.uri.queryParameters['deviceToken'] ?? '',
              isPreview: state.uri.queryParameters['isPreview'] == 'true',
            );
          },
        );
      },
    ),
    // Routes القديمة
    GoRoute(
      path: '/signIn',
      name: 'logIn',
      builder: (context, state) => const Login(fromCheckout: false),
    ),
    GoRoute(
      path: '/termsAndConditions',
      name: 'terms',
      builder: (context, state) => const TermsAndConditionsScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) {
        final isAdmin = state.uri.queryParameters['isAdmin'] == 'true';
        return Homepage(isAdmin: isAdmin);
      },
    ),
    GoRoute(
      path: '/create-group',
      name: 'createGroup',
      builder: (context, state) => const Creategroup(),
    ),
    GoRoute(
      path: '/join-group',
      name: 'joinGroup',
      builder: (context, state) => JoinGroupScreen(),
    ),
    GoRoute(
      path: '/workspace/:workspaceId',
      name: WorkspaceHomeScreen.screenroute,
      builder: (context, state) {
        final workspaceId = state.pathParameters['workspaceId'] ?? '';
        return WorkspaceHomeScreen(workspaceId: workspaceId);
      },
    ),
    GoRoute(
      path: '/team/:groupId',
      name: 'team',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        final adminId = state.uri.queryParameters['adminId'] ?? '';
        final isAdmin = state.uri.queryParameters['isAdmin'] == 'true';
        final isXadmin = state.uri.queryParameters['isXadmin'] == 'true';
        return TeamScreen(
          groupId: groupId,
          adminId: adminId,
          isAdmin: isAdmin,
          isXadmin: isXadmin,
        );
      },
    ),
    GoRoute(
      path: '/admin-approval/:groupId',
      name: 'adminApproval',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        return AdminApprovalPage(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/add-task',
      name: 'addTask',
      builder: (context, state) => AddTaskScreen(
        groupId: state.uri.queryParameters['groupId'] ?? '',
        fromConstTasks: state.uri.queryParameters['fromConstTasks'] == 'true',
        description: TextEditingController(),
        title: TextEditingController(),
      ),
    ),
    GoRoute(
      path: '/add-asset/:groupId',
      name: 'addAsset',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        return AddAssetScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/assets/:groupId',
      name: 'assets',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        return AssetsScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/tasks/:groupId',
      name: 'tasks',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        final isAdmin = state.uri.queryParameters['isAdmin'] == 'true';
        final isFinishTasks =
            state.uri.queryParameters['isFinishTasks'] == 'true';
        return TasksScreen(
          groupId: groupId,
          isAdmin: isAdmin,
          isFinishTasks: isFinishTasks,
        );
      },
    ),
    GoRoute(
      path: '/attendance/:groupId',
      name: 'attendance',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        final isAdmin = state.uri.queryParameters['isAdmin'] == 'true';
        return DailyAttendanceScreen(groupId: groupId, isAdmin: isAdmin);
      },
    ),
    GoRoute(
      path: '/update-version',
      name: 'updateVersion',
      builder: (context, state) => Updateversion(
        storeLink: state.uri.queryParameters['storeLink'] ?? '',
      ),
    ),

    GoRoute(
      path: '/add-inventory/:groupId',
      name: 'addInventory',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        return AddInventoryItemScreen(
          groupId: groupId,
          isFromInvoice: state.uri.queryParameters['isFromInvoice'] == 'true',
          invoiceType: state.uri.queryParameters['invoiceType'] ?? '',
          customerId: state.uri.queryParameters['customerId'] ?? '',
          isEditMode: state.uri.queryParameters['isEditMode'] == 'true',
          itemsPurchase: state.uri.queryParameters['itemsPurchase'] == 'true'
              ? []
              : [],
          isFromWarehouseScreen:
              state.uri.queryParameters['isFromWarehouseScreen'] == 'true',
        );
      },
    ),
    GoRoute(
      path: '/store/:groupId',
      name: 'store',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        return StoreScreen(
          groupId: groupId,
          isFromInvoice: state.uri.queryParameters['isFromInvoice'] == 'true',
          deletedItems: state.uri.queryParameters['deletedItems'] == 'true',
          invoiceType: state.uri.queryParameters['invoiceType'] ?? '',
          customerId: state.uri.queryParameters['customerId'] ?? '',
          isEditMode: state.uri.queryParameters['isEditeMode'] == 'true',
          itemsPurchase: state.uri.queryParameters['itemsPurchase'] == 'true'
              ? []
              : [],
          itemsSale: state.uri.queryParameters['itemsSale'] == 'true' ? [] : [],
        );
      },
    ),
    GoRoute(
      path: '/inventory-details/:groupId/:itemId',
      name: 'inventoryDetails',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        final itemId = state.pathParameters['itemId'] ?? '';
        return InventoryItemDetailsScreenRefactored(
          groupId: groupId,
          itemId: itemId,
          deletedItems: state.uri.queryParameters['deletedItems'] == 'true',
        );
      },
    ),
    GoRoute(
      path: '/admin/mainAdmin',
      name: 'mainAdmin',
      builder: (context, state) => const MainAdmin(),
    ),
    GoRoute(
      path: '/feedbacks',
      name: 'feedbacks',
      builder: (context, state) => const FeedbacksPage(),
    ),
    GoRoute(
      path: '/add-report/:groupId',
      name: 'addReport',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        return AddReportPage(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/groups-monitor',
      name: 'groupsMonitor',
      builder: (context, state) => const GroupsMintor(),
    ),
    GoRoute(
      path: '/invoice',
      name: 'invoice',
      builder: (context, state) => InvoicePage(
        groupId: state.uri.queryParameters['groupId'] ?? '',
        itemsSale: [],
        itemsPurchase: [],
        name: state.uri.queryParameters['name'] ?? '',
        phone: state.uri.queryParameters['phone'] ?? '',
        address: state.uri.queryParameters['address'] ?? '',
        customerId: state.uri.queryParameters['customerId'] ?? '',
        isFromConstCustomers:
            state.uri.queryParameters['isFromConstCustomers'] == 'true',
        isFromWorkSpace: state.uri.queryParameters['isFromWorkSpace'] == 'true',
        type: state.uri.queryParameters['type'] ?? '',
        isFormStore: state.uri.queryParameters['isFormStore'] == 'true',
        isEditMode: state.uri.queryParameters['isEditMode'] == 'true',
      ),
    ),
    GoRoute(
      path: '/customers-suppliers/:groupId',
      name: 'customersSuppliers',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'] ?? '';
        return CustomersSuppliers(
          groupId: groupId,
          isFromInvoice: state.uri.queryParameters['isFromInvoice'] == 'true',
          itemsSale: [],
          itemsPruchase: [],
          invoiceType: state.uri.queryParameters['invoiceType'] ?? '',
          isEditMode: state.uri.queryParameters['isEditMode'] == 'true',
        );
      },
    ),
    GoRoute(
      path: '/invoice-settings',
      name: 'invoiceSettings',
      builder: (context, state) => InvoiceSettingsPage(
        groupId: state.uri.queryParameters['groupId'] ?? '',
        items: [],
        isFromConstCustomers:
            state.uri.queryParameters['isFromConstCustomers'] == 'true',
        customerId: state.uri.queryParameters['customerId'] ?? '',
        name: state.uri.queryParameters['name'] ?? '',
        phone: state.uri.queryParameters['phone'] ?? '',
        address: state.uri.queryParameters['address'] ?? '',
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'الصفحة غير موجودة',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('الرجوع للرئيسية'),
          ),
        ],
      ),
    ),
  ),
);
