import 'package:flutter/material.dart';
import 'package:universal_html/universal_html.dart' as html;
import 'dart:ui_web' as ui_web;

class WebImage extends StatefulWidget {
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
  State<WebImage> createState() => _WebImageState();
}

class _WebImageState extends State<WebImage> {
  static int _counter = 0;
  late final String _viewId;

  @override
  void initState() {
    super.initState();

    _viewId = 'web-image-${_counter++}';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      final image = html.ImageElement()
        ..src = widget.src
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = _getObjectFit(widget.fit)
        ..style.pointerEvents = 'none';

      return image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: IgnorePointer(
        ignoring: true,
        child: HtmlElementView(viewType: _viewId),
      ),
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
      case BoxFit.fitWidth:
        return 'fill';
      case BoxFit.fitHeight:
        return 'contain';
      default:
        return 'cover';
    }
  }
}
