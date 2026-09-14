import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class BrowserDetector {
  static bool get isInAppBrowser {
    if (!kIsWeb) return false;
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains('fbav') || // Facebook / Messenger
        ua.contains('instagram') ||
        ua.contains('whatsapp') ||
        ua.contains('telegram') ||
        ua.contains('tiktok');
  }

  static bool get isAndroid {
    if (!kIsWeb) return false;
    return html.window.navigator.userAgent.toLowerCase().contains('android');
  }

  static void openInExternalBrowser() {
    if (!kIsWeb) return;

    final url = html.window.location.href;
    final host = html.window.location.host;
    final path = html.window.location.pathname;
    final query = html.window.location.search;

    if (isAndroid) {
      // Intent URL للأندرويد
      final intentUrl =
          'intent://$host$path$query#Intent;scheme=https;package=com.android.chrome;end';
      html.window.location.href = intentUrl;
    } else {
      // iOS وغيره
      html.window.open(url, '_blank');
    }
  }
}
