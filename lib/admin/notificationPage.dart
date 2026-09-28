import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Notificationpage extends StatefulWidget {
  const Notificationpage({super.key});
  static const String screenRoute = 'NotificationPage';

  @override
  State<Notificationpage> createState() => _NotificationpageState();
}

class _NotificationpageState extends State<Notificationpage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController notTitle = TextEditingController();
  TextEditingController notBody = TextEditingController();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getAccessToken();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    notBody.dispose();
    notTitle.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('إرسال إشعارات الى المستخدمين')),
      backgroundColor: const Color.fromARGB(255, 232, 229, 220),
      body: Form(
        key: _formKey,
        child: Container(
          padding: EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  'الإشعارات',
                  style: TextStyle(
                    fontSize: 20,
                    color: const Color.fromARGB(255, 6, 80, 208),
                  ),
                ),
              ),
              SizedBox(height: 20),
              _textField(notTitle, 'العنوان', 'اكتب عنوان الرساله'),
              SizedBox(height: 20),
              _textField(notBody, 'الرسالة', 'اكتب الرساله هنا'),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  sendTopicNotification(
                    topic: 'mainAdmin',
                    title: notTitle.text,
                    body: notBody.text,
                  );
                },
                icon: Icon(Icons.send),
                style: ButtonStyle(
                  iconColor: WidgetStatePropertyAll<Color>(
                    const Color.fromARGB(255, 6, 80, 208),
                  ),
                  backgroundColor: WidgetStatePropertyAll<Color>(
                    const Color.fromARGB(255, 214, 223, 161),
                  ),
                ),
                label: Text(
                  'إرسال',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color.fromARGB(255, 6, 80, 208),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint,
    //  String validator,
  ) {
    return TextFormField(
      controller: controller,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.message_outlined),

        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 2,
          ),
        ),
      ),

      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'من فضلك أدخل الرسالة';
        }
        return null;
      },
    );
  }

  // --- FCM Functions (Keep original logic) ---

  Future<String> getAccessToken() async {
    const serviceAccount = {
      "client_email":
          "firebase-adminsdk-fbsvc@maintenance-b7282.iam.gserviceaccount.com",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC9cKtKpsZcrdxM\nq1nXAX9lK64kvOk2r8SELU2IghVhInV7aPDruKyUbM0Fr2hyrEBKw+QgFHg7W4GR\nSstTirBrAelDWTVI2ARhnkNuHfPyAQMQni918S4tbqTB4On0ZqiSiQ7lit134tQF\n7bQ5FzbG9RkTA58nn0NpcZtA0dUc8HisY9yLma5IjixAlSJv87iDBXb+CYt0V/+T\nAL+Fm1soZ267Y6dXORL4bJYqmFcwEctJiAsYqSTgkiBdOulYV29ZFCq9C3JXtA4/\nHGW8xq976gaykoVQ2vzyReYNR8fIizRk/mWY/auF763MhSdKFpFSnTWvDm9lFRSQ\nAwiPLGcpAgMBAAECggEAHRaCxriq9qofjIo3BkONmyxE1hFHwgTlKOKH6DEJNVwE\nLAnmDFvT7Ap0xK21XP5D9Pb1PVPHTl3znCqe49oE0rl9ZsD45JF+wrp5YhwpS/yJ\nyvBvGy4ISCOYGsj9Q3DL64wuBGL5NKJYqfxg0u9UkuIpknjY5E2ZHUS7cQ2HKqUi\nQgVbKd+Vx2qy2AjVyp3L+3CoJ3PslTE7NvsS9uT2+1T/LDbizN2ufGK4OyDmg4Wc\n/y1qP/MYHQa+pM+lsO7i+0OLuV5EDVBUB4OT/nVwY6HYm2lzgr21/UUztmCNYQ8Z\nyfOGXH4uQYcXJX0U/VLXRzbrBbUpnWAMlochXyYLsQKBgQDlrNOebzmGkMsIOVj8\ngDmFYa/cn/4Wlemk/Fv7dkKVVIa6CShdowLXAC6n2FvnMKpsC83tYRe8FmwKCLbh\nrEtPKCvuf36cvpmkef/8jjmLc7yoVW7qCFNGHdxrW6nKbeqyB72tDoTXFvgXOaNl\nIxYzTr2B3jNp6QOYNTeSLLuTJQKBgQDTJ0Jd7httA/40hR5wYxTgi/ymjNoTvK1i\nFniNkaAb4fjPU4Sa1mqBAuvfQ8hxASfpgumgasg6+DlG9O5n+NxToFhfuyV2STz6\nHncds4OHRUCExXDEahrdS4qaLGhx+siHoQQqljYbmIbffqbG5jX0FSr4+HXj6nw7\nV2sf7uiGtQKBgEvRC2JnkPPM5FjopWlk4pgXMTiBUB0gi6o87BhMZ5pn9rl+wGZ4\noz1aAAzELUJaHEfida4AuRcLx8pgKg7BE3Mj7ayjRaZ0fL+AznIOeQyBvitLWHvF\nF8gzn0mJTrlWI311dLWl71AZcvgnvLpsJK33NjOiqBI0K02Zc6i7P4hJAoGAeNwX\n2LvZZuTKNDWd3qZX5M87pfkpOfLdKy/BgQbBpjQJvmIHnLjt7TpG2Fxr9oK63aXZ\nI8D7KwW5gyve6hQ/yH4XF3R/VN1G0cNuWsnNlzfEXjrE+SfiiJgclXKltdfdwAQh\n5l5kShdb28EapO5QI42aMzfEAtjMkwrOflC5N6ECgYAJBqWDPTuQJR6lG8LC2fNQ\nODtFJGGhxk/YA7JI4JWjE7RimVT7rphnoSMqUusQiis4UkvP4zGYWda5Bq170J25\nzannFLP/fTkPL8gDWOHOFTqU93VSmqVHAKVQbllXcuVHgehfv5zct9KoVAXoQONG\nKYjV1i62aKLsRCFtlC35Rg==\n-----END PRIVATE KEY-----\n",
      "token_uri": "https://oauth2.googleapis.com/token",
    };

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final jwt = JWT({
      "iss": serviceAccount['client_email'],
      "scope": "https://www.googleapis.com/auth/firebase.messaging",
      "aud": serviceAccount['token_uri'],
      "iat": now,
      "exp": now + 3600,
    });

    final signedJwt = jwt.sign(
      RSAPrivateKey(serviceAccount['private_key']!),
      algorithm: JWTAlgorithm.RS256,
    );

    final response = await http.post(
      Uri.parse(serviceAccount['token_uri']!),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": signedJwt,
      },
    );

    final data = jsonDecode(response.body);
    if (data['access_token'] == null) {
      throw Exception("Failed to get access token: ${response.body}");
    }
    return data['access_token'];
  }

  Future<void> sendTopicNotification({
    required String topic,
    required String title,
    required String body,
  }) async {
    print(
      "Sending notification to topic: $topic with title: $title and body: $body",
    );
    final accessToken = await getAccessToken();
    print("Obtained access token: $accessToken");
    final url = Uri.parse(
      "https://fcm.googleapis.com/v1/projects/maintenance-b7282/messages:send",
    );

    await http.post(
      url,
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "message": {
          "topic": topic,
          "notification": {"title": title, "body": body},
          "data": {"route": "home"},
          "android": {
            "priority": "HIGH", // ملاحظة: يجب أن تكون HIGH وليس high
            "notification": {"channel_id": "high_importance_channel"},
          },
        },
      }),
    );
    print('45123');
  }

  Future<void> sendNotificationToDevice({
    required String deviceToken, // FCM Device Token
    required String title,
    required String body,
    // الـ Access Token اللي حصلت عليه
  }) async {
    print('111111111111111111111111111111111');
    final url = Uri.parse(
      "https://fcm.googleapis.com/v1/projects/maintenance-b7282/messages:send",
    );

    final payload = {
      "message": {
        "token": deviceToken, // هنا نستخدم token بدل topic
        "notification": {"title": title, "body": body},
        "android": {
          "priority": "HIGH", // ملاحظة: يجب أن تكون HIGH وليس high
          "notification": {"channel_id": "high_importance_channel"},
        },
        "data": {"route": "home"},
      },
    };
    final accessToken = await getAccessToken();
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );

    print("FCM Response Status: ${response.statusCode}");
    print("FCM Response Body: ${response.body}");
  }
}
