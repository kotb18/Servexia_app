import 'package:flutter/material.dart';

// ✅ Stub للـ Mobile - مش بيعمل حاجة
class WebImage extends StatelessWidget {
  final String src;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const WebImage({
    super.key,
    required this.src,
    this.width,
    this.height,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(src, width: width, height: height, fit: fit);
  }
}
