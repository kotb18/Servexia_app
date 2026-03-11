import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
//import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:maintenance/homePage.dart';
import 'package:maintenance/termsAndConditions.dart';
import 'package:maintenance/updateVersion.dart';

List<dynamic> admins = [];
bool isAdmin = false;
int? versionNumber;
String? linkStore;
bool appRun = false;
User? user;

class Login extends StatefulWidget {
  static const String screenroute = 'logIn';
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool agreedToTerms = false;
  bool isLoading = false;

  Future<void> signInWithGoogle() async {
    if (!agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب الموافقة على الشروط والأحكام أولاً')),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      await getAdmins();
      if (versionNumber != 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Updateversion(storeLink: linkStore!),
          ),
        );
        return;
      }
      await subscribeToNotifications();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Homepage(isAdmin: isAdmin)),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> subscribeToNotifications() async {
    if (kIsWeb) {
      // Web: تجاهل الاشتراك في topic
      print('FCM topics not supported on Web');
      return;
    }

    // Mobile فقط
    await FirebaseMessaging.instance.subscribeToTopic('mainAdmin');
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xffF4F6F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// LOGO
                  Container(
                    height: height * 0.18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.asset('images/22.jpeg'),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Servexia',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'سجل الدخول للمتابعة',
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 24),

                  /// TERMS
                  Row(
                    children: [
                      Checkbox(
                        value: agreedToTerms,
                        onChanged: (v) => setState(() => agreedToTerms = v!),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              TermsAndConditionsScreen.screenroute,
                            );
                          },
                          child: const Text(
                            'أوافق على الشروط والأحكام',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// GOOGLE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (agreedToTerms && !isLoading)
                          ? signInWithGoogle
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 12),
                                const Text(
                                  'تسجيل الدخول باستخدام     ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Image.asset('images/google.png', height: 24),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    '© Created by Al_Ostaz',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> getAdmins() async {
    user = await FirebaseAuth.instance.currentUser;
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
}
