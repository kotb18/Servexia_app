import 'package:flutter/material.dart';
import 'package:maintenance/Store/store_home_screen.dart';

class StorePreviewScreen extends StatelessWidget {
  final String groupId;
  final String storeName;

  const StorePreviewScreen({
    super.key,
    required this.groupId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة المتجر'),
        centerTitle: true,
        backgroundColor: Colors.green,
        actions: [
          // زر المشاركة
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: مشاركة الرابط
              final url = 'https://$groupId.web.app';
              // Share.share(url);
            },
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StoreHomeScreen(
        groupId: groupId,
        storeName: storeName,
        isPreview: true, // <-- علم المعاينة
      ),
    );
  }
}
