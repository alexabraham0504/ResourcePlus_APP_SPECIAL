import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.resourceplus.app"
    compileSdk = 37 // Explicitly set to 37 for full Android 17 compatibility
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.resourceplus.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // minSdk defines the OLDEST Android version supported. 
        // 29 means it supports Android 10, 11, 12, 13, 14, 15, 16, 17 and newer.
        minSdk = 29 
        
        // targetSdk is a Google Play requirement (currently they require 34/35).
        // It DOES NOT limit the app to Android 14. It just means the app is optimized for it.
        targetSdk = 37 // Upgraded to Android 17 (SDK 37)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()

    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }

    val keystoreFilePath = keystoreProperties["storeFile"] as String? ?: "my-release-key.jks"
    val releaseKeystoreFile = rootProject.file(keystoreFilePath)
    val hasReleaseKeystore = keystorePropertiesFile.exists() && releaseKeystoreFile.exists()

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
