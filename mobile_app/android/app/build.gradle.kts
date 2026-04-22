plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun repairCorruptedFlutterDepfiles() {
    val flutterIntermediatesDir = layout.buildDirectory.dir("intermediates/flutter").get().asFile
    if (!flutterIntermediatesDir.exists()) return

    flutterIntermediatesDir
        .listFiles()
        ?.filter { it.isDirectory }
        ?.forEach { variantDir ->
            val depfile = variantDir.resolve("flutter_build.d")
            if (!depfile.exists()) return@forEach

            val bytes = depfile.readBytes()
            val hasNullBytes = bytes.any { it == 0.toByte() }
            val hasDepfileSeparator = String(bytes, Charsets.UTF_8).contains(": ")

            if (hasNullBytes || !hasDepfileSeparator) {
                depfile.delete()
                logger.warn("Deleted corrupted Flutter depfile: ${depfile.absolutePath}")
            }
        }
}

repairCorruptedFlutterDepfiles()

android {
    namespace = "com.grog.grog_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.grog.grog_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
