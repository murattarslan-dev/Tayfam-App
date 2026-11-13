# ADR-0010: Uçtan uca şifreleme için Signal kütüphanesi

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-09, güncelleme 2026-11-10, 2026-11-11, 2026-11-12
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0011](0011-yalnizca-mobil.md); Tayfam-Api ADR-0005 (E2E tasarımı), ADR-0011; CLAUDE.md kesin kural 4; Notion: Proje Planı §6, Açık Kararlar ("Signal için Dart/Flutter kütüphanesi seçimi")

## Bağlam

Birebir mesajlar Signal protokolüyle uçtan uca şifrelenecek (Notion §6,
Tayfam-Api ADR-0005): cihaz başına anahtar çifti, alıcının ve gönderenin
tüm cihazlarına ayrı zarflar, kullanıcının geçmiş anahtarıyla şifreli
arşiv, QR ile geçmiş anahtarı aktarımı, "güvenlik kodu değişti" uyarısı.
Kendi kriptografimizi yazmayız (kesin kural 4). Uygulama yalnızca mobildir
(ADR-0011). Uygulama sırası: önce düz birebir mesaj, E2E modülün son adımı.
**Not (2026-11-12):** düz sürüm kalktı; Tayfam-Api #151 ile birebir mesaj
yalnızca uçtan uca şifrelidir, düz mesajlar sunucuda silindi ve istemcide
düz gönderim yolu yoktur (ADR-0020, ADR-0007 birebir istisnası).

## Araştırma (2026-11-09)

| Seçenek | Ne | Platformlar | Lisans | Olgunluk |
| --- | --- | --- | --- | --- |
| **`libsignal`** (pub.dev) | Signal'in resmi Rust çekirdeğine Flutter Rust Bridge bağlaması; Signal'den değil, üçüncü kişi | Android, iOS (ayrıca masaüstü, web) | AGPL-3.0 (bağlamada uygulama mağazası istisnası var, gömülü libsignal'de yok) | Birkaç aylık, tek geliştirici, sık büyük sürüm; çekirdek Signal'in kendi kodu |
| **`libsignal_protocol_dart`** (Mixin) | Java sürümünün saf Dart'a çevirisi | Dart'ın çalıştığı her yer | GPL-3.0 | ~4 yıllık; son güncelleme Haziran 2025; bağımsız denetim yok; kripto Dart'ta yeniden yazılmış |
| **Kendi bağlamamız** | Signal'in resmi Rust `libsignal`'ine kendi Flutter Rust Bridge bağlamamız | Android, iOS | AGPL-3.0 | Çekirdek resmi; bağlamanın bakımı bizde |
| **vodozemac** (Matrix Olm) | Signal değil, Double Ratchet'in Matrix sürümü | Android, iOS | Bağlama AGPL-3.0 | Denetlenmiş çekirdek; ama protokol kararından sapma |

Uygun her seçenek GPL ya da AGPL'dir. Repo MIT kalabilir, ama dağıtılan
uygulama (APK/IPA) bu lisansa tabi olur; kaynak zaten açık olduğu için uyum
mümkün. Google Play'de bilinen engel yok; App Store ile GPL/AGPL'nin uyumu
tartışmalı.

## Karar

1. **Signal'in resmi Rust çekirdeği kullanılır.** AGPL-3.0 lisansı kabul
   edildi (platform sahibi, 2026-11-10). Başlangıçta `libsignal` bağlaması sürümü sabitlenerek kullanılır;
   bağlama kodu (Rust ve Dart tarafı) eklenmeden önce satır satır incelenir,
   sürüm yükseltmeleri de aynı incelemeden geçer (hassas alan). Bağlamanın
   bakımı bırakılırsa ya da inceleme güven vermezse aynı arayüzle kendi
   bağlamamıza geçilir. Saf Dart çeviri (Mixin), kriptoyu yeniden yazdığı ve
   denetlenmediği için önerilmez.
2. **Anahtarlar ve Signal durumu token gibi güvenli depoda tutulur**
   (platform sahibi, 2026-11-10):
   - `flutter_secure_storage` ile (Android'de Keystore anahtarıyla
     AES-GCM şifreli kayıtlar, iOS'ta Keychain,
     `first_unlock_this_device`, yedeğe gitmez). Yeni bağımlılık değildir
     (ADR-0005). Kendi dosya şifrelememiz yoktur.
   - Kayıt kayıt saklanır: kimlik anahtarı ve kayıt kimliği, imzalı ön
     anahtar, ön anahtarlar, her karşı cihazla oturum durumu, kullanıcının
     geçmiş anahtarı.
   - Oturum durumu her mesajda güncellenir; durum güvenli depoya yazılmadan
     mesaj gönderilmiş veya alınmış sayılmaz.
   - Mesaj içeriği diske yazılmaz (ADR-0006 aynen geçerli); geçmiş arşivi
     sunucudan indirilip bellekte çözülür.
   - Oturum kapanınca ve hesap silinince bu kayıtların hepsi silinir.
   - Web geliştirme derlemesinde E2E yüklenmez (ADR-0011).

## Güncelleme 2026-11-11: resmi Android paketi + ince Kotlin köprüsü

**Karar (platform sahibi, sohbette 19:00):** `libsignal_dart` (pub.dev
`libsignal`) yerine Signal'in resmi `org.signal:libsignal-android` paketi
ve onun üzerinde ince bir Kotlin köprüsü (platform kanalı) kullanılır.
Rust araç zinciri ve Flutter Rust Bridge yoktur. iOS sonra aynı Dart
arayüzüyle (`SignalMotoru`) Signal'in Swift paketi (`LibSignalClient`)
üzerinde yazılır. Karar 1'deki "resmi Rust çekirdeği" aynen geçerlidir:
Android paketi, Signal'in kendi derlediği aynı çekirdektir.

### Araştırma özeti

- **`libsignal_dart` 9.0.0 değerlendirmesi** (2026-11-11): kripto yeniden
  yazılmamış, çekirdek upstream `libsignal` v0.106.0; ama yayıncı pub.dev'de
  doğrulanmamış tek geliştirici (yapay zekâ destekli bakım), 11 ayda 9 büyük
  sürüm ve kırıcı değişiklikler, yerel ikili derleme sırasında yayıncının
  GitHub Releases'ından indiriliyor (özet dosyası ikiliyle aynı yerden),
  her çağrıda durumu Dart'tan Rust'a taşıyan ~6,5 bin satır el yazımı
  "durum tesisatı" (inceleme yükü ~1 gün, her sürümde yeniden). Hüküm
  "şartlı kullanılabilir"di; pilottan önce fork'tan kendi derlememiz
  önerilmişti.
- **Resmi Android paketi:** Signal Messenger LLC yayınlıyor, Signal Android
  uygulamasının kendisi kullanıyor, Java/Kotlin API'si kararlı ve
  belgelenmiş. Signal'in Maven deposundan (`build-artifacts.signal.org`)
  gelir; Gradle bağımlılık doğrulamasıyla SHA-256 sabitlenir. Köprü kodu
  bizde ve küçüktür (`SignalIslemleri.kt`), inceleme yükü buraya iner.
- **Sürüm:** `0.106.1`. Signal'in deposundaki en yeni sürüm `0.107.0`
  (2026-11-10, bir günlük); Signal Android uygulamasının `main`'i
  `0.106.1` kullanıyor. Signal'in sahada kullandığı sürüm seçildi.

### Tasarım

- **Durumsuz köprü:** kalıcı durum Dart'tadır (güvenli depo, karar 2).
  Her çağrı gereken kayıtları (kimlik, oturum, ön anahtarlar) bayt olarak
  alır, tek çağrılık bellek içi depoyla libsignal işlemini yapar, değişen
  kayıtları (yeni oturum, tüketilen ön anahtar kimliği, Kyber kullanımı)
  döner ve depoyu atar. Köprü hiçbir şey saklamaz ve log'lamaz;
  libsignal'in kendi log'u açılmaz (`SignalProtocolLoggerProvider`
  kurulmaz). Hata yalnızca türünü taşır (`gecersizMesaj`, `eskiMesaj`,
  `oturumYok`, `gecersizAnahtar`, `bilinmeyen`).
- Çağrılar Flutter'ın arka plan görev kuyruğunda çalışır; ana iş
  parçacığı bloklanmaz.
- **Kimlik güveni (TOFU) Dart'tadır;** köprünün deposu kimliği her zaman
  güvenilir sayar.
- **Kyber son çare anahtarı:** libsignal `markKyberPreKeyUsed(kyberId,
  signedPreKeyId, baseKey)` ile bildirir; köprü bu üçlüyü döner, tekrar
  denetimi (görülen üçlü kümesi) Dart'tadır. Java API mesajdaki Kyber
  anahtar kimliğini açmadığı için çözmede aday Kyber kayıtlarının hepsi
  verilir.
- **Adres bağı:** libsignal 0.10x gönderen ve alıcı adreslerini mesajın
  MAC'ine bağlar; adres adı sunucunun cihaz UUID'sidir, iki taraf aynı
  adresleri kullanır.
- Simetrik yapı taşları (HKDF-SHA256, AES-256-GCM-SIV, AES-256-GCM çözme)
  ve güvenlik kodu (`NumericFingerprintGenerator`, sürüm 2, 5200
  yineleme) de libsignal'in kendi uygulamalarıdır; kendi kriptomuz yoktur
  (kesin kural 4).
- **Paketleme:** yalnızca `arm64-v8a`, `armeabi-v7a`, `x86_64`;
  libsignal-android'in API bağımlılığı olan masaüstü JVM paketinin yerel
  kütüphaneleri ve libsignal'in test kütüphanesi APK'ya girmez. R8 kuralları
  paketin kendi `META-INF/proguard/libsignal.pro` dosyasından gelir.
  libsignal `java.time` kullandığı için çekirdek kütüphane desugaring'i
  açıktır.
- Web geliştirme derlemesinde ve iOS köprüsü yazılana kadar iOS'ta motor
  `DesteklenmeyenSignalMotoru`'dur (her çağrı `UnsupportedError`).
- **Test:** köprü, Signal'in masaüstü JVM paketiyle (`libsignal-client`,
  aynı sürüm) gerçek libsignal üzerinde JVM birim testleriyle sınanır
  (CI android işi, JDK 21); Dart tarafı sahte kanal ve `SahteSignalMotoru`
  ile.

## Sonuçlar

- Bağımlılık (güncelleme 2026-11-11): Android'de
  `org.signal:libsignal-android:0.106.1` (Signal'in Maven deposu, yalnızca
  `org.signal` grubu bu depodan; SHA-256 `android/gradle/verification-metadata.xml`'de),
  testte `org.signal:libsignal-client:0.106.1`, desugaring için
  `com.android.tools:desugar_jdk_libs`. pub.dev'deki `libsignal` paketi
  kullanılmaz. `flutter_secure_storage` zaten var.
- Lisans değişmez: libsignal-android da AGPL-3.0'dır; dağıtılan APK bu
  lisansa tabidir (karar 1).
- Sürüm yükseltmesi yalnızca inceleme + PR ile yapılır: yeni sürümün
  değişiklik notu ve Java API farkı okunur, özetler Signal Android
  uygulamasının `gradle/verification-metadata.xml`'inden alınıp CI'daki
  indirmeyle doğrulanır. Dependabot'ta Gradle ekosistemi yoktur; bu paket
  için yalnızca GitHub güvenlik bildirimi gelir.
- APK boyutu: libsignal'in yerel kütüphanesi ABI başına birkaç MB ekler
  (mağaza `.aab`'ı ABI'ye göre bölünür).
- ADR-0006'daki "token dışında diske bir şey yazılmaz" kuralı "token ve
  Signal anahtarları/durumu yalnızca güvenli depoda" olarak genişler.
- Notion'da "Signal için Dart/Flutter kütüphanesi seçimi" açık kararı
  kapanır; hukukçu listesine App Store ve AGPL maddesi eklenir; README ve
  uygulamanın lisans ekranında E2E modülünün AGPL olduğu belirtilir.
- E2E iş paketinden önce: bağlamanın incelenmesi, cihaz ekleme/çıkarma ve
  QR akışının istemci tasarımı.

## Değerlendirilen alternatifler

Yukarıdaki tablo. Ayrıca anahtar saklama için kendi şifreli dosyamız
(AES-GCM, anahtar Keystore'da) düşünüldü; aynı güvenlik düzeyini kendi
şifreleme kodumuzla verdiği için `flutter_secure_storage` tercih edildi.
