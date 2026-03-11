import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  const SplashScreen({Key? key}) : super(key: key);
  static const String screenroute = 'splsh';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  Future<void> checkAndNavigate() async {
    user = await FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('kotb');
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Login()),
      );
      return;
    }

    await getAdmins();

    if (!mounted) return;

    if (versionNumber != 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Updateversion(storeLink: linkStore!)),
      );
      return;
    }

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => Homepage(isAdmin: isAdmin)),
    );
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
    // print(FirebaseAuth.instance.currentUser!.email);
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

    checkAndNavigate();

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
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
            child: Image.asset('images/2.png', fit: BoxFit.fill),
          ),
        ),
      ),
    );
  }
}
