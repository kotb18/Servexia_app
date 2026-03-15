import UIKit
import Flutter
import FirebaseCore // تأكد من وجود هذا السطر

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1. تهيئة Firebase قبل تسجيل أي شيء آخر
    FirebaseApp.configure()
    
    // 2. تسجيل إضافات Flutter (هذا السطر جوهري لربط FirebaseCore بـ Xcode)
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
