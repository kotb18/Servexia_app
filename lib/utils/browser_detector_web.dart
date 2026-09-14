import 'dart:html' as html;

class BrowserDetector {
  static bool get isInAppBrowser {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains('fbav') || // Facebook / Messenger
        ua.contains('instagram') ||
        ua.contains('whatsapp') ||
        ua.contains('telegram') ||
        ua.contains('tiktok');
  }

  static bool get isAndroid {
    return html.window.navigator.userAgent.toLowerCase().contains('android');
  }

  static void openInExternalBrowser() {
    final url = html.window.location.href;
    final host = html.window.location.host;
    final path = html.window.location.pathname;
    final query = html.window.location.search;

    if (isAndroid) {
      final intentUrl =
          'intent://$host$path$query#Intent;scheme=https;package=com.android.chrome;end';
      html.window.location.href = intentUrl;
    } else {
      html.window.open(url, '_blank');
    }
  }
}
