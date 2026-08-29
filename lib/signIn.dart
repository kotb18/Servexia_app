import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  bool _loginCompleted = false;

  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // بعد signInWithRedirect تعود الصفحة من Google ويتم تحديث authStateChanges.
    // لذلك نكمل التنقل بعد نجاح الرجوع من Google.
    if (kIsWeb) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        firebaseUser,
      ) {
        if (firebaseUser != null && mounted && !_loginCompleted) {
          _completeLogin();
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> signInWithGoogle() async {
    if (!agreedToTerms) {
      _showMessage('يجب الموافقة على الشروط والأحكام أولاً');
      return;
    }

    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      if (kIsWeb) {
        // مهم: في الويب استخدم Redirect بدل Popup.
        // Popup قد يتم حجبه في المتصفحات الخارجية أو متصفحات الهاتف.
        final googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        await FirebaseAuth.instance.signInWithRedirect(googleProvider);

        // سيتم الرجوع إلى التطبيق بعد انتهاء تسجيل الدخول،
        // وسيتم استدعاء _completeLogin من authStateChanges().
        return;
      }

      // Android / iOS: تسجيل الدخول الأصلي بدون Popup الخاص بالويب.
      final googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize(
        serverClientId:
            '840926699694-qslfjros665j55vtofid6rghqe4qsiii.apps.googleusercontent.com',
      );

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      await _completeLogin();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showMessage(_firebaseAuthMessage(e.code));
    } catch (e) {
      debugPrint('Google Auth Error: $e');

      if (!mounted) return;
      _showMessage('لم تكتمل عملية تسجيل الدخول. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _completeLogin() async {
    if (_loginCompleted || !mounted) return;

    _loginCompleted = true;

    if (!isLoading) {
      setState(() => isLoading = true);
    }

    try {
      await getAdmins();

      if (!mounted) return;

      // لا تستخدم linkStore! إلا إذا كانت القيمة موجودة فعلًا.
      if (versionNumber != null &&
          versionNumber != 1 &&
          linkStore != null &&
          linkStore!.isNotEmpty) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Updateversion(storeLink: linkStore!),
          ),
        );
        return;
      }

      await subscribeToNotifications();

      if (!mounted) return;

      if (widget.fromCheckout) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => Homepage(isAdmin: isAdmin)),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Complete Login Error: $e');
      _loginCompleted = false;

      if (mounted) {
        _showMessage('تم تسجيل الدخول، لكن تعذر تحميل بيانات الحساب.');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> subscribeToNotifications() async {
    if (kIsWeb) {
      debugPrint('FCM topics are not supported on Web.');
      return;
    }

    await FirebaseMessaging.instance.subscribeToTopic('mainAdmin');
  }

  Future<void> getAdmins() async {
    user = FirebaseAuth.instance.currentUser;

    final doc = await FirebaseFirestore.instance
        .collection('admins')
        .doc('masry')
        .get();

    if (!doc.exists) {
      admins = [];
      isAdmin = false;
      return;
    }

    final data = doc.data();

    if (data == null) {
      admins = [];
      isAdmin = false;
      return;
    }

    final adminsData = data['admins'];

    admins = adminsData is List ? adminsData : [];
    versionNumber = data['versionNo'] as int?;
    linkStore = data['shareLink'] as String?;
    appRun = data['appRun'] == true;

    isAdmin = user?.email != null && admins.contains(user!.email);

    debugPrint('Admins: $admins');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _firebaseAuthMessage(String code) {
    switch (code) {
      case 'popup-closed-by-user':
      case 'popup-blocked':
      case 'cancelled-popup-request':
        return 'تعذر فتح نافذة Google في هذا المتصفح. أعد المحاولة باستخدام تسجيل الدخول البديل.';
      case 'unauthorized-domain':
        return 'نطاق الموقع غير مضاف إلى Authorized domains في Firebase.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول باستخدام Google غير مفعّل في Firebase.';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.';
      case 'account-exists-with-different-credential':
        return 'يوجد حساب مسجل بهذا البريد بطريقة دخول مختلفة.';
      default:
        return 'حدث خطأ أثناء تسجيل الدخول. حاول مرة أخرى.';
    }
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
                  Container(
                    height: height * 0.18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.asset('images/1.PNG'),
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
                  Row(
                    children: [
                      Checkbox(
                        value: agreedToTerms,
                        onChanged: isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  agreedToTerms = value ?? false;
                                });
                              },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: isLoading
                              ? null
                              : () => context.pushNamed('terms'),
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
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: agreedToTerms && !isLoading
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
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'تسجيل الدخول باستخدام Google',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
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
}
