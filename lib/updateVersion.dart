import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Updateversion extends StatefulWidget {
  const Updateversion({super.key, required this.storeLink});
  final String storeLink;
  static const String screenroute = 'updateversion';

  @override
  State<Updateversion> createState() => _UpdateversionState();
}

class _UpdateversionState extends State<Updateversion> {
  final bool forceUpdate = true;
  final String message =
      'هناك تحديث متاح للتطبيق. يرجى التحديث للحصول على المزايا الأخيرة.';

  Future<void> _showUpdateDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            // ✅ في حال ضغط رجوع أثناء وجود الـ Dialog → يخرج من التطبيق
            exit(0);
          },
          child: AlertDialog(
            title: const Text(
              'تحديث متوفر',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () async {
                  final uri = Uri.parse(widget.storeLink);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('تحديث الآن'),
              ),
              if (!forceUpdate)
                TextButton(
                  onPressed: () => exit(0),
                  child: const Text('لاحقاً'),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showUpdateDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WillPopScope(
        onWillPop: () async {
          // ✅ لو المستخدم ضغط رجوع من الصفحة نفسها (بدون الـDialog)
          exit(0);
        },
        child: const SizedBox.shrink(),
      ),
    );
  }
}
