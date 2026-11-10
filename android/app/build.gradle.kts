plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Geliştirme imzası (ADR-0012 §6): Google girişi uygulamanın imza parmak
// izine bağlıdır. CI, GitHub secret'ları varken sabit geliştirme anahtarını
// geçici bir dosyaya açar ve TAYFAM_DEV_KEYSTORE ile yolunu verir; parola ve
// takma ad da ortam değişkenleridir. Anahtar ve parolalar repoya girmez
// (CLAUDE.md kesin kural 6). Değişken yoksa (yerel derleme, fork PR'ı)
// Flutter'ın varsayılan debug anahtarı kullanılır. Sürüm (mağaza) imzası
// ayrı iştir (#13).
val gelistirmeAnahtari: File? =
    System.getenv("TAYFAM_DEV_KEYSTORE")
        ?.takeIf { it.isNotBlank() }
        ?.let { File(it) }
        ?.takeIf { it.isFile }

android {
    namespace = "com.murattarslan.tayfam"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.murattarslan.tayfam"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (gelistirmeAnahtari != null) {
            create("gelistirme") {
                storeFile = gelistirmeAnahtari
                storePassword = System.getenv("TAYFAM_DEV_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("TAYFAM_DEV_KEY_ALIAS")
                keyPassword = System.getenv("TAYFAM_DEV_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            if (gelistirmeAnahtari != null) {
                signingConfig = signingConfigs.getByName("gelistirme")
            }
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
