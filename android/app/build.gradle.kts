import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials are read from android/key.properties (which is
// git-ignored and generated per-developer — see SECURITY.md / README).
//
// SECURITY: a release build MUST ship signed with the real release key. The
// debug keystore is publicly known, so an APK/AAB signed with it can be
// trivially forged/replaced on a device. When key.properties is absent the
// build now fails fast instead of silently falling back to debug signing.
//
// Local dev escape hatch: pass -Pandroid.allowDebugSigning=true (or set it in
// ~/.gradle/gradle.properties) to opt back into the debug fallback, e.g. for
// `flutter run --release`. Production/CI builds must NEVER use this flag.
val allowDebugSigning =
    (project.findProperty("android.allowDebugSigning") as? String) == "true"
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val missingReleaseKeystoreMessage =
    "Release build requires android/key.properties. " +
        "For local `flutter run --release` pass -Pandroid.allowDebugSigning=true."

gradle.taskGraph.whenReady {
    val requestedReleaseBuild = allTasks.any { it.name.contains("Release") }
    if (requestedReleaseBuild && !hasReleaseKeystore && !allowDebugSigning) {
        throw GradleException(missingReleaseKeystoreMessage)
    }
}

android {
    namespace = "com.example.flutter_application_1"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_application_1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Real release key when key.properties is present. Without it the
            // build fails — see the comment above the keystore loading.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else if (allowDebugSigning) {
                logger.warn("⚠️ Release build using DEBUG signing key (android.allowDebugSigning=true). DO NOT ship this artifact.")
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
