# ADR-0010: Uçtan uca şifreleme için Signal kütüphanesi

- **Durum:** Önerildi (platform sahibinin kararını bekliyor; üç açık soru aşağıda)
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md); Tayfam-Api ADR-0005 (E2E tasarımı), ADR-0011; CLAUDE.md kesin kural 4; Notion: Proje Planı §6, Açık Kararlar ("Signal için Dart/Flutter kütüphanesi seçimi")

## Bağlam

Birebir mesajlar Signal protokolüyle uçtan uca şifrelenecek (Notion §6,
Tayfam-Api ADR-0005): cihaz başına anahtar çifti, alıcının ve gönderenin
tüm cihazlarına ayrı zarflar, kullanıcının geçmiş anahtarıyla şifreli
arşiv, QR ile geçmiş anahtarı aktarımı, "güvenlik kodu değişti" uyarısı.
Kendi kriptografimizi yazmayız (kesin kural 4). Web'de özel anahtarların
WebCrypto ile dışa aktarılamaz saklanması isteniyor. Uygulama sırası:
önce düz birebir mesaj, E2E modülün son adımı; bu karar E2E iş paketinden
önce kesinleşmelidir, düz sürümü engellemez.

## Araştırma (2026-11-09)

| Seçenek | Ne | Platformlar | Lisans | Olgunluk |
| --- | --- | --- | --- | --- |
| **`libsignal`** (pub.dev) | Signal'in resmi Rust çekirdeğine Flutter Rust Bridge bağlaması; Signal'den değil, üçüncü kişi | Android, iOS, masaüstü, web (WASM; `--wasm` derlemesi yok) | AGPL-3.0 (bağlamada uygulama mağazası istisnası var, gömülü libsignal'de yok) | Birkaç aylık, tek geliştirici, sık büyük sürüm; çekirdek Signal'in kendi kodu |
| **`libsignal_protocol_dart`** (Mixin) | Java sürümünün saf Dart'a çevirisi | Dart'ın çalıştığı her yer (web dahil) | GPL-3.0 | ~4 yıllık; son güncelleme Haziran 2025; bağımsız denetim yok; kripto Dart'ta yeniden yazılmış |
| **Kendi bağlamamız** | Signal'in resmi Rust `libsignal`'ine kendi Flutter Rust Bridge bağlamamız | Rust'ın derlendiği her yer, web WASM | AGPL-3.0 | Çekirdek resmi; bağlamanın bakımı bizde |
| **vodozemac** (Matrix Olm) | Signal değil, Double Ratchet'in Matrix sürümü | `flutter_vodozemac`: web yok | Bağlama AGPL-3.0 | Denetlenmiş çekirdek; ama protokol kararından sapma |

Bulgular:

1. **Lisans:** Uygun her seçenek GPL ya da AGPL. Repo MIT kalabilir, ama
   dağıtılan uygulama (APK/IPA/web) bu lisansa tabi olur; kaynak zaten
   açık olduğu için uyum mümkün. App Store ile GPL/AGPL'nin uyumu tartışmalı;
   Google Play'de bilinen engel yok.
2. **Web'de dışa aktarılamaz anahtar:** Hiçbir seçenek anahtarları
   WebCrypto'ya bırakmıyor; Signal protokolü X25519 ve Ed25519 işlemlerini
   kütüphanenin kendi belleğinde yapıyor (WASM ya da Dart). Tarayıcılarda
   Ed25519 artık her büyük motorda var, X25519 Chrome 133 ve Firefox'ta var,
   Safari'de belirsiz; yine de kütüphaneler bunu kullanmıyor. Bu şart olduğu
   gibi karşılanamaz.
3. **Kalıcı durum:** Signal, kimlik anahtarı, ön anahtarlar ve oturum
   (ratchet) durumunu kalıcı ve sıralı yazmak ister; bellekte tutulursa
   uygulama her açılışta yeni cihaz gibi davranır. Bu, ADR-0006'nın "token
   dışında diske bir şey yazılmaz" kuralına bir istisna gerektirir.

## Öneri

1. **Signal'in resmi Rust çekirdeği kullanılır.** Başlangıçta `libsignal`
   bağlaması sürümü sabitlenerek kullanılır; bağlama kodu (Rust ve Dart
   tarafı) eklenmeden önce satır satır incelenir, sürüm yükseltmeleri de
   aynı incelemeden geçer (hassas alan). Bağlamanın bakımı bırakılırsa ya
   da inceleme güven vermezse aynı arayüzle kendi bağlamamıza geçilir.
   Saf Dart çeviri (Mixin), kriptoyu yeniden yazdığı ve denetlenmediği için
   önerilmez.
2. **Anahtarlar ve Signal durumu şifreli olarak kalıcı tutulur (ADR-0006'ya
   istisna):**
   - Mobil: Signal durumu tek bir dosyada, AES-256-GCM ile şifreli; dosya
     anahtarı Android Keystore / iOS Keychain'de, cihazdan çıkmaz.
   - Web: Signal durumu IndexedDB'de, WebCrypto ile üretilmiş **dışa
     aktarılamaz** bir AES-GCM sarma anahtarıyla şifreli. Böylece "web'de
     anahtarlar dışa aktarılamaz" şartı, saklanan anahtarlar için sarma
     anahtarı düzeyinde karşılanır; kullanım anında anahtarlar kütüphanenin
     belleğindedir (her seçenekte böyle).
   - Bu istisna yalnızca anahtar ve protokol durumu içindir; mesaj içeriği
     diske yazılmaz (ADR-0006 aynen geçerli). Geçmiş arşivi sunucudan
     indirilip bellekte çözülür.
   - Oturum kapanınca ve hesap silinince bu durum ve sarma anahtarı silinir.
3. **Lisans:** Uygulama dağıtımında AGPL-3.0 yükümlülükleri kabul edilir;
   repo MIT kalır, ama E2E modülü ve libsignal'in AGPL olduğu README'de ve
   uygulamanın lisans ekranında belirtilir. App Store dağıtımı hukukçu
   listesine eklenir.

## Açık sorular (platform sahibi)

1. Uygulamada AGPL-3.0 bağımlılık kabul ediliyor mu? (Kabul edilmezse
   Signal ile E2E yapılamaz; protokol kararı yeniden açılır.)
2. Web'deki şart "saklanan anahtarlar dışa aktarılamaz bir sarma anahtarıyla
   korunur" olarak değiştirilebilir mi?
3. Anahtar ve protokol durumu için ADR-0006'ya istisna kabul ediliyor mu?

## Sonuçlar (kabul edilirse)

- Bağımlılık: `libsignal` (sabit sürüm, hassas alan). Web derlemesinde WASM
  paketi gelir; `--wasm` (dart2wasm) derlemesi kullanılmaz.
- Notion'da "Signal için Dart/Flutter kütüphanesi seçimi" açık kararı
  kapanır; hukukçu listesine App Store ve AGPL maddesi eklenir;
  Proje Planı §6'daki web anahtar cümlesi güncellenir.
- E2E iş paketinden önce: bağlamanın incelenmesi, cihaz ekleme/çıkarma ve
  QR akışının istemci tasarımı.

## Değerlendirilen alternatifler

Yukarıdaki tablo. Ayrıca: E2E'yi web'de kapatmak (web'de yalnızca düz
mesaj) ya da web'de DM'i hiç sunmamak; ikisi de Notion'daki "tam web sürümü"
kararıyla çelişir.
