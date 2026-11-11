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
        // libsignal-android java.time kullanır ve tüketicide çekirdek
        // kütüphane desugaring'i ister (ADR-0010).
        isCoreLibraryDesugaringEnabled = true
    }

    packaging {
        // libsignal-android, masaüstü JVM paketini (libsignal-client) API
        // bağımlılığı olarak getirir; onun jar'ındaki masaüstü yerel
        // kütüphaneleri (Linux .so, macOS .dylib, Windows .dll) APK'ya
        // girmez. Android yerel kodu AAR'ın jni/ klasöründen gelir.
        resources {
            excludes += setOf(
                "libsignal_jni*.so",
                "**/*.dylib",
                "**/*.dll",
            )
        }
        // libsignal'in yalnızca kendi testleri için olan yerel kütüphanesi.
        jniLibs {
            excludes += setOf("**/libsignal_jni_testing.so")
        }
    }

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

        // Yalnızca gerçek cihazların ve emülatörün ABI'leri (ADR-0010):
        // libsignal-android 32 bit x86 kütüphanesini de getirir; Flutter
        // x86'yı zaten desteklemez. Mağaza .aab'ı ayrıca ABI'ye göre bölünür.
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
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

// JVM birim testleri (android/app/src/test): başarısız testin ayrıntısı CI
// log'unda görünsün. Testler gerçek anahtar ya da kullanıcı verisi içermez.
tasks.withType<Test>().configureEach {
    testLogging {
        events("passed", "skipped", "failed")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
}

dependencies {
    // Signal protokolü (ADR-0010, güncelleme 2026-11-11). Sürüm Signal
    // Android uygulamasının kullandığıyla aynıdır; yükseltme inceleme + PR
    // ile yapılır, SHA-256 gradle/verification-metadata.xml'de güncellenir.
    implementation("org.signal:libsignal-android:0.106.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // JVM birim testleri gerçek libsignal ile: masaüstü paketi linux-x86_64
    // yerel kodunu içerir (aynı sürüm).
    testImplementation("org.signal:libsignal-client:0.106.1")
    testImplementation("junit:junit:4.13.2")
}
