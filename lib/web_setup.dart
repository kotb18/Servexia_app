import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class PlatformSetup {
  static Future<void> init() async {
    usePathUrlStrategy();
  }
}
