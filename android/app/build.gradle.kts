import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Push (FCM; istemci ADR-0019 §5): Firebase yapılandırması
    // google-services.json'dan.
    id("com.google.gms.google-services")
}

// Firebase yapılandırması repodadır (istemci ADR-0019 §5; değerler public,
// kesin kural 6). Yoksa derleme anlaşılır bir hatayla durur.
check(file("google-services.json").isFile) {
    "android/app/google-services.json yok. Firebase konsolundaki " +
        "com.murattarslan.tayfam Android uygulamasının dosyası repoya " +
        "konmalı (istemci ADR-0019 §5)."
}

// Geliştirme imzası (ADR-0012 §6): Google girişi uygulamanın imza parmak
// izine bağlıdır. CI, GitHub secret'ları varken sabit geliştirme anahtarını
// geçici bir dosyaya açar ve TAYFAM_DEV_KEYSTORE ile yolunu verir; parola ve
// takma ad da ortam değişkenleridir. Anahtar ve parolalar repoya girmez
// (CLAUDE.md kesin kural 6). Değişken yoksa (yerel derleme, fork PR'ı)
// Flutter'ın varsayılan debug anahtarı kullanılır. Bu yalnızca debug
// derlemesi içindir; sürüm imzası aşağıda.
val gelistirmeAnahtari: File? =
    System.getenv("TAYFAM_DEV_KEYSTORE")
        ?.takeIf { it.isNotBlank() }
        ?.let { File(it) }
        ?.takeIf { it.isFile }

// Sürüm (mağaza) imzası (#13, ADR-0018 §10): Play App Signing kullanılır;
// sürüm derlemesi yalnızca yükleme anahtarıyla (upload key) imzalanır.
// Kaynak sırası:
//   1. Ortam değişkenleri (CI, surum.yml): TAYFAM_UPLOAD_KEYSTORE (anahtar
//      dosyasının yolu), TAYFAM_UPLOAD_KEYSTORE_PASSWORD,
//      TAYFAM_UPLOAD_KEY_ALIAS, TAYFAM_UPLOAD_KEY_PASSWORD.
//   2. android/key.properties (yerel; .gitignore'da): storeFile,
//      storePassword, keyAlias, keyPassword. Göreli storeFile android/app'e
//      göredir; mutlak yol önerilir.
// İkisi de yoksa ya da eksikse sürüm görevleri (assembleRelease,
// bundleRelease) anlaşılır bir hatayla durur; debug anahtarına asla
// düşülmez. Debug derlemesi bundan etkilenmez. Parolalar hiçbir mesaja
// yazılmaz.
val yuklemeAlanlari = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")

fun ortamDegeri(ad: String): String? = System.getenv(ad)?.takeIf { it.isNotBlank() }

val keyPropertiesDosyasi: File = rootProject.file("key.properties")

val yuklemeKaynagi: String? =
    when {
        ortamDegeri("TAYFAM_UPLOAD_KEYSTORE") != null -> "TAYFAM_UPLOAD_* ortam değişkenleri"
        keyPropertiesDosyasi.isFile -> "android/key.properties"
        else -> null
    }

val yuklemeImzasi: Map<String, String?> =
    when {
        ortamDegeri("TAYFAM_UPLOAD_KEYSTORE") != null ->
            mapOf(
                "storeFile" to ortamDegeri("TAYFAM_UPLOAD_KEYSTORE"),
                "storePassword" to ortamDegeri("TAYFAM_UPLOAD_KEYSTORE_PASSWORD"),
                "keyAlias" to ortamDegeri("TAYFAM_UPLOAD_KEY_ALIAS"),
                "keyPassword" to ortamDegeri("TAYFAM_UPLOAD_KEY_PASSWORD"),
            )
        keyPropertiesDosyasi.isFile -> {
            val ozellikler = Properties()
            keyPropertiesDosyasi.inputStream().use { ozellikler.load(it) }
            yuklemeAlanlari.associateWith { ad ->
                ozellikler.getProperty(ad)?.takeIf { it.isNotBlank() }
            }
        }
        else -> emptyMap()
    }

val yuklemeImzasiHatasi: String? =
    run {
        val kaynak =
            yuklemeKaynagi
                ?: return@run "Sürüm imzası yok: yükleme anahtarı ne " +
                    "TAYFAM_UPLOAD_* ortam değişkenlerinde ne android/key.properties " +
                    "dosyasında. Sürüm derlemesi debug anahtarıyla imzalanmaz (#13). " +
                    "Geliştirme için debug derlemesini kullan (flutter build apk --debug)."
        val eksikler = yuklemeAlanlari.filter { yuklemeImzasi[it] == null }
        if (eksikler.isNotEmpty()) {
            return@run "Sürüm imzası eksik ($kaynak): ${eksikler.joinToString()} boş."
        }
        if (!file(yuklemeImzasi.getValue("storeFile")!!).isFile) {
            return@run "Sürüm imza anahtarı dosyası bulunamadı ($kaynak, storeFile)."
        }
        null
    }

// Sürüm imzası yoksa sürüm görevleri, derleme başlamadan durur.
val surumGorevleri = setOf("assembleRelease", "bundleRelease", "packageRelease", "signReleaseBundle")
gradle.taskGraph.whenReady {
    val hata = yuklemeImzasiHatasi ?: return@whenReady
    if (allTasks.any { it.project.path == ":app" && it.name in surumGorevleri }) {
        throw GradleException(hata)
    }
}

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
        if (yuklemeImzasiHatasi == null) {
            create("yukleme") {
                storeFile = file(yuklemeImzasi.getValue("storeFile")!!)
                storePassword = yuklemeImzasi.getValue("storePassword")
                keyAlias = yuklemeImzasi.getValue("keyAlias")
                keyPassword = yuklemeImzasi.getValue("keyPassword")
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
            // Yalnızca yükleme anahtarı; yoksa imza yapılandırması verilmez
            // ve sürüm görevleri yukarıdaki denetimle durur (#13).
            if (yuklemeImzasiHatasi == null) {
                signingConfig = signingConfigs.getByName("yukleme")
            }
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
