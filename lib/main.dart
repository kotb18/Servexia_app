import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:maintenance/JoinGroup.dart';
import 'package:maintenance/addAsset.dart';
import 'package:maintenance/addAwarehouseItem.dart';
import 'package:maintenance/addTask.dart';
import 'package:maintenance/admin/feedBack.dart';
import 'package:maintenance/admin/mainAdmin.dart';
import 'package:maintenance/assets.dart';
import 'package:maintenance/attendance.dart';
import 'package:maintenance/createGroup.dart' hide billingService;
import 'package:maintenance/homePage.dart';
import 'package:maintenance/joinReq.dart';
import 'package:maintenance/reportPage.dart';
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

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyA-l6i06vfoBsz9C6BuLDMoqGY6h7AXmIQ",
      appId: "1:840926699694:android:d94b4af2bcaf2145314d3f",
      messagingSenderId: "840926699694",
      projectId: "maintenance-b7282",
      storageBucket: "maintenance-b7282.firebasestorage.app",
    ),
  );
  // Initialize the Gemini Developer API backend service
  // Create a `GenerativeModel` instance with a model that supports your use case

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  await _fcm.requestPermission(alert: true, badge: true, sound: true);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print(message.notification?.title);
    print(message.notification?.body);
  });
  Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp();
    print("Background message: ${message.messageId}");
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
        AddTaskScreen.screenroute: (context) => AddTaskScreen(groupId: ''),
        AddAssetScreen.screenroute: (context) => AddAssetScreen(groupId: ''),
        AssetsScreen.screenroute: (context) => AssetsScreen(groupId: ''),
        TasksScreen.screenroute: (context) =>
            TasksScreen(groupId: '', isAdmin: false),
        DailyAttendanceScreen.screenroute: (context) =>
            DailyAttendanceScreen(groupId: ''),
        SplashScreen.screenroute: (context) => SplashScreen(),
        Updateversion.screenroute: (context) => Updateversion(storeLink: ''),
        TermsAndConditionsScreen.screenroute: (context) =>
            TermsAndConditionsScreen(),
        AddInventoryItemScreen.screenroute: (context) =>
            AddInventoryItemScreen(groupId: ''),
        StoreScreen.screenroute: (context) => StoreScreen(groupId: ''),
        InventoryItemDetailsScreenRefactored.screenroute: (context) =>
            InventoryItemDetailsScreenRefactored(
              groupId: '',
              itemId: '',
              deletedItems: false,
            ),
        MainAdmin.screenroute: (context) => const MainAdmin(),
        FeedbacksPage.screenroute: (context) => const FeedbacksPage(),
        AddReportPage.screenroute: (context) => AddReportPage(groupId: ''),
      },
    );
  }
}
