plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.io.FileInputStream
import java.util.Properties

// ==============================
// تحميل بيانات keystore
// ==============================
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {

    namespace = "com.example.maintenance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.0.13004108" // دعم 16KB page size
     packaging {
             jniLibs {
               useLegacyPackaging = true
           }
        }

    // ==============================
    // Java & Kotlin
    // ==============================
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    // ==============================
    // Default Config
    // ==============================
    defaultConfig {

        applicationId = "com.masry.maintenance"

        minSdk = flutter.minSdkVersion
        targetSdk = 35

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true

        // ✅ IMPORTANT — إعادة دعم كل الأجهزة
        ndk {
            abiFilters.clear()
            abiFilters += listOf(
                "armeabi-v7a", // أجهزة 32bit
                "arm64-v8a"    // أجهزة حديثة
            )
        }
       
    }

    // ==============================
    // Signing
    // ==============================
    signingConfigs {

        getByName("debug") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }

        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    // ==============================
    // Build Types
    // ==============================
    buildTypes {

        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            
        }

        getByName("release") {
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // ✅ حل توافق 16KB Page Size (Android 15)
   

    // ==============================
    // Rename APK Output
    // ==============================
    applicationVariants.all {
        outputs.all {
            val outputImpl =
                this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            outputImpl.outputFileName =
                "${applicationId}-${name}.apk"
        }
    }
}

// ==============================
// Dependencies
// ==============================
dependencies {

    implementation(platform("com.google.firebase:firebase-bom:33.14.0"))

    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-storage")
    implementation("com.google.firebase:firebase-database")
    implementation("com.google.firebase:firebase-messaging")

    implementation("com.google.android.gms:play-services-auth:21.0.0")

    implementation("androidx.multidex:multidex:2.0.1")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase App Check
    debugImplementation("com.google.firebase:firebase-appcheck-debug:16.0.0-beta01")
    releaseImplementation("com.google.firebase:firebase-appcheck-playintegrity")
    implementation("com.google.firebase:firebase-appcheck")
}