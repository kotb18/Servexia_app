import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:maintenance/JoinGroup.dart';
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
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final FirebaseMessaging fcm = FirebaseMessaging.instance;

  await fcm.requestPermission(alert: true, badge: true, sound: true);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print(message.notification?.title);
    print(message.notification?.body);
  });
  Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    print("Background message: ${message.messageId}");
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maintenance',
      localizationsDelegates: [
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
      home: SplashScreen(),
      routes: {
        Login.screenroute: (context) => const Login(),
        Homepage.screenroute: (context) => const Homepage(isAdmin: false),
        Creategroup.screenroute: (context) => const Creategroup(),
        JoinGroupScreen.screenroute: (context) => JoinGroupScreen(),
        WorkspaceHomeScreen.screenroute: (context) =>
            const WorkspaceHomeScreen(workspaceId: ''),
        TeamScreen.screenroute: (context) => TeamScreen(
          groupId: '',
          adminId: '',
          isAdmin: false,
          isXadmin: false,
        ),
        AdminApprovalPage.screenroute: (context) =>
            AdminApprovalPage(groupId: ''),
        AddTaskScreen.screenroute: (context) => AddTaskScreen(
          groupId: '',
          fromConstTasks: false,
          description: TextEditingController(),
          title: TextEditingController(),
        ),
        AddAssetScreen.screenroute: (context) => AddAssetScreen(groupId: ''),
        AssetsScreen.screenroute: (context) => AssetsScreen(groupId: ''),
        TasksScreen.screenroute: (context) =>
            TasksScreen(groupId: '', isAdmin: false),
        DailyAttendanceScreen.screenroute: (context) =>
            DailyAttendanceScreen(groupId: '', isAdmin: false),
        SplashScreen.screenroute: (context) => SplashScreen(),
        Updateversion.screenroute: (context) => Updateversion(storeLink: ''),
        TermsAndConditionsScreen.screenroute: (context) =>
            TermsAndConditionsScreen(),
        AddInventoryItemScreen.screenroute: (context) => AddInventoryItemScreen(
          groupId: '',
          isFromInvoice: false,
          invoiceType: '',
          customerId: '',
        ),
        StoreScreen.screenroute: (context) => StoreScreen(
          groupId: '',
          isFromInvoice: false,
          deletedItems: false,
          invoiceType: '',
          customerId: '',
        ),
        InventoryItemDetailsScreenRefactored.screenroute: (context) =>
            InventoryItemDetailsScreenRefactored(
              groupId: '',
              itemId: '',
              deletedItems: false,
            ),
        MainAdmin.screenroute: (context) => const MainAdmin(),
        FeedbacksPage.screenroute: (context) => const FeedbacksPage(),
        AddReportPage.screenroute: (context) => AddReportPage(groupId: ''),
        GroupsMintor.screenroute: (context) => const GroupsMintor(),
        InvoicePage.screenroute: (context) => InvoicePage(
          groupId: '',
          itemsSale: [],
          itemsPurchase: [],
          name: '',
          phone: '',
          address: '',
          customerId: '',
          isFromConstCustomers: false,
          isFromWorkSpace: false,
          type: '',
        ),
        CustomersSuppliers.screenroute: (context) => const CustomersSuppliers(
          groupId: '',
          isFromInvoice: false,
          itemsSale: [],
          itemsPruchase: [],
          invoiceType: '',
        ),
        InvoiceSettingsPage.routeName: (context) => const InvoiceSettingsPage(
          groupId: '',
          items: [],
          isFromConstCustomers: false,
          customerId: '',
          name: '',
          phone: '',
          address: '',
        ),
      },
    );
  }
}
