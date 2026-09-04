import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maintenance/homePage.dart';
import 'dart:async';
import 'package:maintenance/signIn.dart';
import 'package:maintenance/updateVersion.dart';

bool? isCompleted;
int? versionNumber;
String? linkStore;
bool admin2 = false;
bool appRun = false;
bool walletRun = false;
bool isAdmin = false;
List<dynamic> admins = [];
User? user;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  static const String screenroute = 'splsh';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  Future<void> checkAndNavigate() async {
    final shopLink = GoRouterState.of(context).uri.queryParameters['shopLink'];
    if (shopLink != null && shopLink.startsWith('/shop/')) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      context.go(shopLink);
      return;
    }

    // 1. استخراج الـ groupId من URL أولاً
    final groupId = _extractGroupIdFromUrl();

    // 2. لو فيه groupId في اللينك → روح للمتجر مباشرة
    if (groupId != null && groupId != 'default') {
      await Future.delayed(const Duration(seconds: 3)); // انتظر Animation
      if (!mounted) return;

      // استخدم GoRouter للتنقل للمتجر
      context.go('/shop/$groupId');
      return;
    }

    // 3. لو مفيش لينك → كمل الطبيعي
    user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('kotb');
      if (!mounted) return;
      context.go('/signIn');
      return;
    }

    await getAdmins();

    if (!mounted) return;

    if (versionNumber != 1) {
      context.go(
        Uri(
          path: '/update-version',
          queryParameters: {'storeLink': linkStore!},
        ).toString(),
      );
      return;
    }

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    context.go('/home?isAdmin=$isAdmin');
  }

  // استخراج groupId من URL
  String? _extractGroupIdFromUrl() {
    final uri = Uri.base;
    final host = uri.host;

    // للـ Firebase Hosting: groupId.web.app
    final parts = host.split('.');
    if (parts.length >= 3 && parts.first != 'maintenance-b7282') {
      return parts.first; // ahmed-store.web.app => ahmed-store
    }

    // من الـ path: /shop/ahmed-store
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shop') {
      return uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
    }

    return null;
  }

  Future<void> getAdmins() async {
    final doc = await FirebaseFirestore.instance
        .collection('admins')
        .doc('masry')
        .get();

    if (!doc.exists) {
      return;
    }

    final data = doc.data();
    if (data == null || data['admins'] == null) {
      admins = [];
      return;
    }
    versionNumber = data['versionNo'];
    linkStore = data['shareLink'];
    appRun = data['appRun'];
    admins = data['admins'];

    if (user != null) {
      setState(() {
        isAdmin = admins.contains(FirebaseAuth.instance.currentUser!.email);
      });
    }

    print(admins);
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndNavigate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) =>
              Transform.scale(scale: _animation.value, child: child),
          child: SizedBox(
            height: size.height,
            child: Image.asset('images/222.png', fit: BoxFit.fill),
          ),
        ),
      ),
    );
  }
}
