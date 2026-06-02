// ✅ ملف للـ Web فقط - مش هيتاستورد على Mobile
import 'package:flutter/material.dart';
import 'package:universal_html/universal_html.dart' as html;
import 'dart:ui_web' as ui_web;

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
    final viewId =
        'web-image-${src.hashCode}-${DateTime.now().millisecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      final img = html.ImageElement()
        ..src = src
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = _getObjectFit(fit);
      return img;
    });

    return SizedBox(
      width: width,
      height: height,
      child: HtmlElementView(viewType: viewId),
    );
  }

  String _getObjectFit(BoxFit? fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'cover';
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      default:
        return 'cover';
    }
  }
}
