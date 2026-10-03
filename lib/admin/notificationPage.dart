import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _PendingNotification {
  const _PendingNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
  };

  factory _PendingNotification.fromJson(Map<String, dynamic> json) {
    return _PendingNotification(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class Notificationpage extends StatefulWidget {
  const Notificationpage({super.key});
  static const String screenRoute = 'NotificationPage';

  @override
  State<Notificationpage> createState() => _NotificationpageState();
}

class _NotificationpageState extends State<Notificationpage> {
  static const _localStorageKey = 'pending_notifications';
  static const _firestoreCollection = 'pending_notifications';

  final _formKey = GlobalKey<FormState>();
  final _notTitle = TextEditingController();
  final _notBody = TextEditingController();
  final List<_PendingNotification> _pendingNotifications = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSending = false;
  String? _selectedNotificationId;
  String? _storageMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    List<_PendingNotification>? localNotifications;
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_localStorageKey);
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          localNotifications = decoded
              .whereType<Map>()
              .map(
                (item) => _PendingNotification.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
              .toList();
        }
      }
    } catch (error) {
      debugPrint('Local notifications read failed: $error');
    }

    // المحلية لها الأولوية. نستخدم Firestore فقط عند عدم وجود بيانات محلية
    // أو عند فشل/تعذر قراءة التخزين المحلي.
    if (localNotifications != null && localNotifications.isNotEmpty) {
      _replaceNotifications(localNotifications);
      return;
    }

    try {
      final remote = await _readFromFirestore();
      await _saveLocal(remote);
      _replaceNotifications(remote);
    } catch (error) {
      _setStorageMessage('تعذر تحميل الإشعارات من الهاتف أو Firestore');
      debugPrint('Firestore notifications read failed: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<_PendingNotification>> _readFromFirestore() async {
    final snapshot = await _firestore
        .collection(_firestoreCollection)
        .get(const GetOptions(source: Source.server));

    final notifications = snapshot.docs
        .map((doc) {
          final data = doc.data();
          return _PendingNotification(
            id: doc.id,
            title: (data['title'] ?? '').toString(),
            body: (data['body'] ?? '').toString(),
            createdAt: (data['createdAt'] is Timestamp)
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
                      DateTime.now(),
          );
        })
        .where((item) => item.title.isNotEmpty && item.body.isNotEmpty)
        .toList();
    notifications.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return notifications;
  }

  Future<void> _saveLocal(List<_PendingNotification> notifications) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      notifications.map((item) => item.toJson()).toList(),
    );
    final saved = await preferences.setString(_localStorageKey, encoded);
    if (!saved) throw Exception('تعذر حفظ الإشعارات محلياً');
  }

  void _replaceNotifications(List<_PendingNotification> notifications) {
    if (!mounted) return;
    setState(() {
      _pendingNotifications
        ..clear()
        ..addAll(notifications);
      _isLoading = false;
    });
  }

  void _setStorageMessage(String message) {
    if (!mounted) return;
    setState(() {
      _storageMessage = message;
      _isLoading = false;
    });
  }

  Future<void> _addNotification(String title, String body) async {
    final notification = _PendingNotification(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      createdAt: DateTime.now(),
    );
    final updated = [..._pendingNotifications, notification];

    // الحفظ المحلي أولاً حتى لا تضيع القائمة عند انقطاع الإنترنت.
    try {
      await _saveLocal(updated);
      if (mounted) {
        setState(() {
          _pendingNotifications.add(notification);
          _storageMessage = null;
        });
      }
    } catch (error) {
      _showMessage('تعذر حفظ الإشعار على الهاتف: $error');
      return;
    }

    // فشل Firestore لا يلغي الحفظ المحلي؛ تتم المحاولة مرة أخرى لاحقاً.
    try {
      await _firestore
          .collection(_firestoreCollection)
          .doc(notification.id)
          .set({
            'title': notification.title,
            'body': notification.body,
            'createdAt': Timestamp.fromDate(notification.createdAt),
          });
    } catch (error) {
      _showMessage('تم الحفظ محلياً، لكن تعذر الحفظ في Firestore');
      debugPrint('Firestore notification write failed: $error');
    }
  }

  Future<void> _deleteNotification(int index) async {
    final notification = _pendingNotifications[index];
    final updated = [..._pendingNotifications]..removeAt(index);
    try {
      await _saveLocal(updated);
      if (mounted) {
        setState(() {
          _pendingNotifications.removeAt(index);
          if (_selectedNotificationId == notification.id) {
            _selectedNotificationId = null;
            _notTitle.clear();
            _notBody.clear();
          }
        });
      }
    } catch (error) {
      _showMessage('تعذر حذف الإشعار محلياً: $error');
      return;
    }

    try {
      await _firestore
          .collection(_firestoreCollection)
          .doc(notification.id)
          .delete();
    } catch (error) {
      _showMessage('حُذف محلياً، لكن تعذر حذفه من Firestore');
      debugPrint('Firestore notification delete failed: $error');
    }
  }

  void _selectNotification(_PendingNotification notification) {
    setState(() {
      _selectedNotificationId = notification.id;
      _notTitle
        ..text = notification.title
        ..selection = TextSelection.collapsed(
          offset: notification.title.length,
        );
      _notBody
        ..text = notification.body
        ..selection = TextSelection.collapsed(offset: notification.body.length);
    });
  }

  _PendingNotification? get _selectedNotification {
    for (final notification in _pendingNotifications) {
      if (notification.id == _selectedNotificationId) return notification;
    }
    return null;
  }

  void _handleAddNotification() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('إضافة إشعار إلى القائمة'),
            const SizedBox(height: 16),
            _textField(titleController, 'العنوان', 'اكتب عنوان الرسالة'),
            const SizedBox(height: 16),
            _textField(bodyController, 'الرسالة', 'اكتب الرسالة هنا'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final body = bodyController.text.trim();
                    if (title.isEmpty || body.isEmpty) {
                      _showMessage('من فضلك أدخل العنوان والرسالة');
                      return;
                    }
                    // نعيد البيانات فقط. الحفظ و setState يتمان بعد إغلاق
                    // الـ BottomSheet حتى لا يحدث تعارض في build scope.
                    Navigator.pop(sheetContext, <String>[title, body]);
                  },
                  child: const Text('إضافة'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ).then((result) async {
      // ننتظر اكتمال إزالة الـ BottomSheet قبل تحديث الصفحة الأب.
      if (result != null && result.length == 2 && mounted) {
        await Future<void>.delayed(Duration.zero);
        if (mounted) await _addNotification(result[0], result[1]);
      }
      titleController.dispose();
      bodyController.dispose();
    });
  }

  Future<void> _sendNotifications() async {
    // await FirebaseMessaging.instance.subscribeToTopic('mainAdmin0');
    final selectedNotification = _selectedNotification;
    if (selectedNotification == null &&
        (_notTitle.text.trim().isEmpty || _notBody.text.trim().isEmpty)) {
      if (!_formKey.currentState!.validate()) return;
    }

    final notificationToSend =
        selectedNotification ??
        _PendingNotification(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: _notTitle.text.trim(),
          body: _notBody.text.trim(),
          createdAt: DateTime.now(),
        );

    setState(() => _isSending = true);
    try {
      await sendTopicNotification(
        topic: 'mainAdmin',
        title: notificationToSend.title,
        body: notificationToSend.body,
      );

      if (!mounted) return;
      _showMessage('تم إرسال الإشعار المحدد، وما زال محفوظاً لإعادة إرساله');
    } catch (error) {
      _showMessage('تعذر إرسال الإشعارات، وبقيت محفوظة محلياً: $error');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _notTitle.dispose();
    _notBody.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _handleAddNotification,
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(title: const Text('إرسال إشعارات إلى المستخدمين')),
      backgroundColor: const Color.fromARGB(255, 232, 229, 220),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  'الإشعارات',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color.fromARGB(255, 6, 80, 208),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _textField(_notTitle, 'العنوان', 'اكتب عنوان الرسالة'),
              const SizedBox(height: 20),
              _textField(_notBody, 'الرسالة', 'اكتب الرسالة هنا'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading || _isSending ? null : _sendNotifications,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSending ? 'جارٍ الإرسال...' : 'إرسال'),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'الإشعارات الجاهزة للإرسال (${_pendingNotifications.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_storageMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _storageMessage!,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _pendingNotifications.isEmpty
                    ? const Center(child: Text('لا توجد إشعارات مضافة حالياً'))
                    : ListView.separated(
                        itemCount: _pendingNotifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final notification = _pendingNotifications[index];
                          return Card(
                            child: ListTile(
                              selected:
                                  notification.id == _selectedNotificationId,
                              selectedTileColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              onTap: _isSending
                                  ? null
                                  : () => _selectNotification(notification),
                              leading: CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              title: Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                notification.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                tooltip: 'حذف الإشعار',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _isSending
                                    ? null
                                    : () => _deleteNotification(index),
                              ),
                            ),
                          );
                        },
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
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'من فضلك أدخل العنوان والرسالة'
          : null,
    );
  }

  // انقل هذا المنطق إلى Backend/Cloud Function قبل نشر التطبيق.
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

    String? accessToken;

    try {
      accessToken = await getAccessToken();
    } catch (e) {
      print("❌ Failed to get access token: $e");
      return;
    }

    // لو getAccessToken رجع null أو فاضي
    if (accessToken.trim().isEmpty) {
      print("❌ Access token is null or empty");
      return;
    }

    print("✅ Obtained access token");

    final url = Uri.parse(
      "https://fcm.googleapis.com/v1/projects/maintenance-b7282/messages:send",
    );

    try {
      final response = await http.post(
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
              "priority": "HIGH",
              "notification": {"channel_id": "high_importance_channel"},
            },
          },
        }),
      );

      print("FCM status: ${response.statusCode}");
      print("FCM response: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("✅ Notification sent successfully");
      } else {
        print("❌ Failed to send notification");
      }
    } catch (e) {
      print("❌ Error sending notification: $e");
    }
  }

  Future<void> sendNotificationToDevice({
    required String deviceToken,
    required String title,
    required String body,
  }) async {
    print('111111111111111111111111111111111');

    // التأكد من وجود Device Token
    if (deviceToken.trim().isEmpty) {
      print("❌ Device token is empty");
      return;
    }

    String? accessToken;

    // الحصول على Access Token
    try {
      accessToken = await getAccessToken();
    } catch (e) {
      print("❌ Failed to get access token: $e");
      return;
    }

    // التأكد من أن Access Token موجود
    if (accessToken.trim().isEmpty) {
      print("❌ Access token is null or empty");
      return;
    }

    print("✅ Access token obtained");

    final url = Uri.parse(
      "https://fcm.googleapis.com/v1/projects/maintenance-b7282/messages:send",
    );

    final payload = {
      "message": {
        "token": deviceToken,
        "notification": {"title": title, "body": body},
        "android": {
          "priority": "HIGH",
          "notification": {"channel_id": "high_importance_channel"},
        },
        "data": {"route": "home"},
      },
    };

    try {
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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("✅ Notification sent successfully");
      } else {
        print("❌ Failed to send notification");
      }
    } catch (e) {
      print("❌ Error sending notification: $e");
    }
  }
}
