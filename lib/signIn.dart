import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
//import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:maintenance/homePage.dart';
import 'package:maintenance/updateVersion.dart';

List<dynamic> admins = [];
bool isAdmin = false;
int? versionNumber;
String? linkStore;
bool appRun = false;
User? user;

class Login extends StatefulWidget {
  static const String screenroute = 'logIn';
  final bool fromCheckout;
  const Login({super.key, required this.fromCheckout});

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

      if (kIsWeb) {
        // --- منطق الويب (Web) ---
        // الطريقة الأكثر استقراراً للويب هي استخدام Firebase مباشرة
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // --- منطق الموبايل (Android / iOS) - متوافق مع v7.x ---
        final GoogleSignIn googleSignIn = GoogleSignIn.instance;

        // تهيئة المعرف
        await googleSignIn.initialize(
          serverClientId:
              '840926699694-qslfjros665j55vtofid6rghqe4qsiii.apps.googleusercontent.com',
        );

        // في v7.x نستخدم authenticate() بدلاً من signIn()
        final GoogleSignInAccount googleUser = await googleSignIn
            .authenticate();

        // الحصول على الـ idToken (في الإصدار الجديد accessToken لم يعد موجوداً/مطلوباً هنا)
        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // --- التكملة بعد النجاح ---
      await getAdmins();

      if (versionNumber != 1) {
        context.go(
          Uri(
            path: '/update-version',
            queryParameters: {'storeLink': linkStore!},
          ).toString(),
        );
        return;
      }

      await subscribeToNotifications();

      if (!mounted) return;
      if (widget.fromCheckout) {
        Navigator.pop(
          context,
          true,
        ); // ارجع للصفحة السابقة (checkout) بعد تسجيل الدخول
      } else {
        context.go('/home?isAdmin=$isAdmin');
      }
    } catch (e) {
      print("Google Auth Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
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
                    height: height * 0.3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.asset('images/1.png'),
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
                            context.pushNamed('terms');
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
    user = FirebaseAuth.instance.currentUser;
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
