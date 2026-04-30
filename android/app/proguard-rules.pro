# ==============================================================================
# Flutter & Firebase ProGuard Rules for Production (Target SDK 35)
# ==============================================================================

# 1. قواعد أساسية لـ Flutter
# ------------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 2. قواعد Firebase (لحماية الجلسة والمصادقة من الحذف)
# ------------------------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# 3. قواعد محددة لـ Firebase Auth و Firestore
# ------------------------------------------------------------------------------
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.database.** { *; }
-keep class com.google.firebase.storage.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.analytics.** { *; }

# 4. قواعد لحفظ البيانات واستمرارية الجلسة (Persistence)
# ------------------------------------------------------------------------------
# إذا كنت تستخدم flutter_secure_storage
-keep class com.it_interact.secure_storage.** { *; }
# إذا كنت تستخدم shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# 5. تجنب التحذيرات التي قد توقف عملية البناء (Build)
# ------------------------------------------------------------------------------
-dontwarn okio.**
-dontwarn com.google.protobuf.**
-dontwarn org.checkerframework.checker.nullness.compatqual.**
-dontwarn javax.annotation.**
-dontwarn org.apache.http.**

# 6. تحسينات إضافية لـ Android 15 (Target SDK 35 )
# ------------------------------------------------------------------------------
-keep class androidx.lifecycle.DefaultLifecycleObserver { *; }
-keep class androidx.multidex.** { *; }

# ==============================================================================
# نهاية الملف
# ==============================================================================
# حل مشكلة الكلاسات المفقودة في Google Play Core
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# حل مشكلة الكلاسات المفقودة في Flutter Embedding
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# القواعد العامة التي أرسلتها لك سابقاً (مهمة جداً للجلسة)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
