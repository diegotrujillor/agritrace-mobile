import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing config loaded from android/key.properties (git-ignored).
// Falls back to debug signing when the file is absent (CI / fresh clone).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Play Store requires a unique, monotonically increasing versionCode per upload.
// CI overrides via -PversionCode=<n> / -PversionName=<s> (or VERSION_CODE / VERSION_NAME
// env vars); local builds fall back to pubspec `version:` (flutter.versionCode/Name).
val resolvedVersionCode: Int =
    (project.findProperty("versionCode") as String?)?.toInt()
        ?: System.getenv("VERSION_CODE")?.toInt()
        ?: flutter.versionCode
val resolvedVersionName: String =
    (project.findProperty("versionName") as String?)
        ?: System.getenv("VERSION_NAME")
        ?: flutter.versionName

// When true, a missing key.properties FAILS the build instead of silently
// falling back to debug signing (Play rejects debug-signed / wrong-key uploads).
// CI release job sets -PreleaseSigningRequired=true; local/dev defaults to false.
val releaseSigningRequired: Boolean =
    (project.findProperty("releaseSigningRequired") as String?)?.toBoolean() ?: false

android {
    namespace = "co.agritrace.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "co.agritrace.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = resolvedVersionCode
        versionName = resolvedVersionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else if (releaseSigningRequired) {
                throw GradleException(
                    "Release signing required but android/key.properties is missing. " +
                        "Provide the upload keystore (CI: write key.properties from secrets), " +
                        "or omit -PreleaseSigningRequired=true for a local debug-signed build."
                )
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
