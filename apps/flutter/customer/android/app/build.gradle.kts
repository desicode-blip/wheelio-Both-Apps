import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Private internal-test bundles can skip the slow native shrink pass. Dart remains release/AOT.
val internalTestBuild = System.getenv("WASHKREW_ANDROID_INTERNAL_TEST") == "1"
val uploadPropertiesPath = System.getenv("WASHKREW_ANDROID_KEY_PROPERTIES")
val uploadProperties = Properties()
if (!uploadPropertiesPath.isNullOrBlank()) {
    file(uploadPropertiesPath).inputStream().use { uploadProperties.load(it) }
}
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name == "bundleRelease" } && uploadPropertiesPath.isNullOrBlank()) {
        throw GradleException("Play bundles require WASHKREW_ANDROID_KEY_PROPERTIES pointing to a private upload-key properties file outside Git.")
    }
}
android {
    namespace = "com.amanmaheshwari.wheelio.customer"
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
        applicationId = "com.amanmaheshwari.wheelio.customer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!uploadPropertiesPath.isNullOrBlank()) {
            create("upload") {
                keyAlias = uploadProperties.getProperty("keyAlias")
                keyPassword = uploadProperties.getProperty("keyPassword")
                storeFile = file(uploadProperties.getProperty("storeFile"))
                storePassword = uploadProperties.getProperty("storePassword")
            }
        }
    }
    buildTypes {
        release {
            // Flutter 3.38 prepopulates build-type ABI filters. Match the
            // arm64-only internal Dart/engine build, including plugin libraries.
            if (internalTestBuild) {
                ndk.abiFilters.clear()
                ndk.abiFilters.add("arm64-v8a")
            }
            isMinifyEnabled = !internalTestBuild
            isShrinkResources = !internalTestBuild
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // USB builds retain their existing certificate; Play bundles require the private upload key.
            signingConfig = signingConfigs.getByName(if (uploadPropertiesPath.isNullOrBlank()) "debug" else "upload")
        }
    }
}

flutter {
    source = "../.."
}
