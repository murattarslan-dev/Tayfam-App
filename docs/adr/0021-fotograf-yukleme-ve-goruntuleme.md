# ADR-0021: Fotoğraf yükleme ve görüntüleme

- **Durum:** Kabul edildi (platform sahibi, 2026-11-12, sohbette)
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md),
  [ADR-0005](0005-api-istemcisi.md),
  [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md),
  [ADR-0014](0014-tayfa-listesi-katilim-ve-olusturma.md),
  [ADR-0015](0015-etkinlik-ve-duyuru-modulleri.md); Tayfam-Api ADR-0007,
  ADR-0020 (görüntü işleme istemcide); issue #77; Notion: İstemci Geçiş
  Özeti (2026-11-11 18:52), Kötüye Kullanım ve Genç Kullanıcı Güvenliği

## Bağlam

Tayfam-Api ADR-0020'ye göre sunucu görüntü pikselini hiç çözmez: istemci
fotoğrafı okur (HEIC dahil), EXIF yönünü piksellere uygular, **bütün
metadata'yı siler** (EXIF ve GPS, XMP, IPTC, MPF) ve aynı görüntüden iki
varyant kodlar: `full` (en uzun kenar ≤ 1600 px) ve `preview` (≤ 400 px),
JPEG ya da animasyonsuz WebP, varyant başına ≤ 10 MiB. Sunucu yalnızca
başlıkları denetler; metadata'lı, yanlış ölçülü ya da oranı tutmayan dosya
`rejected` olur (`metadata_present`, `dimension_mismatch` …).

Bu yüzden konum sızıntısına karşı asıl koruma istemcidedir: fotoğrafın
GPS'i sunucuya hiç gitmemelidir (CLAUDE.md kesin kural 3, Tayfam-Api
ADR-0008). Flutter'ın standart kütüphanesi HEIC okuyamaz, JPEG yazamaz ve
galeri/kamera açamaz; paket gerekir (kesin kural 8).

## Karar

### 1. Galeri ve kamera: `image_picker`

- **Paket:** `image_picker` (yayıncı flutter.dev, BSD-3, Flutter ekibinin
  bakımında; Android ve iOS). Photo Picker'ı açmak için Android uygulaması
  `image_picker_android` ve `image_picker_platform_interface` da doğrudan
  bağımlılıktır (aynı yayıncı, aynı paketin parçaları).
- **Galeri:** Android'de sistemin fotoğraf seçicisi (Photo Picker;
  `useAndroidPhotoPicker = true`): Android 13+ yerleşik, eskilerde Google
  Play hizmetleriyle gelen sürüm (paketin manifestindeki
  `ModuleDependencies` servisi). iOS'ta PHPicker,
  `requestFullMetadata: false`. **İkisi de izin istemez**; uygulama
  yalnızca kullanıcının seçtiği fotoğrafı görür. `READ_MEDIA_IMAGES` /
  `READ_EXTERNAL_STORAGE` eklenmez.
- **Kamera:** sistem kamera uygulaması (`ACTION_IMAGE_CAPTURE`, iOS
  `UIImagePickerController`). Android'de uygulama manifestinde `CAMERA`
  izni **yoksa** bu yol izin gerektirmez; bu iş `CAMERA` eklemez. E2E'nin
  QR eşleştirme işi `CAMERA`'yı ekleyince `image_picker` çekimden önce o
  izni çalışma anında ister (eklentinin davranışı: manifestte izin varsa
  sistem kamerası da izin ister). İki iş aynı izni paylaşır; CI'ın APK
  izin denetimine `CAMERA`'yı QR işi ekler.
- **iOS metinleri:** `NSPhotoLibraryUsageDescription` (PHPicker sormasa da
  eklenti ve mağaza incelemesi ister) ve `NSCameraUsageDescription`
  (yalnızca "Fotoğraf çek"e basınca sorulur), Türkçe.
- **Geçici dosya:** seçici fotoğrafı uygulamanın geçici klasörüne kopyalar
  (Android önbellek klasörü, iOS `tmp`). Baytlar belleğe okunur okunmaz o
  kopya silinir (ADR-0006: diske içerik yok). Uygulama seçim sırasında
  sistemce sonlandırılırsa kalan kopyayı işletim sistemi önbellek
  temizliğinde siler; uygulama ona bir daha dokunmaz.

### 2. Çözme, yön, küçültme, kodlama: `flutter_image_compress` (platform kodlayıcıları)

- **Paket:** `flutter_image_compress` (yayıncı fluttercandies.com, MIT;
  2026'da düzenli sürüm, Android ve iOS). Android'de `BitmapFactory`
  (+ `androidx.exifinterface`), iOS'ta `UIImage`/ImageIO. **İzin eklemez**
  (Android manifesti yalnızca `uses-sdk` geçersiz kılması içerir).
- **HEIC:** iOS her sürümde; Android'de HEIF çözücüsü 9+ (API 28) sistemde
  vardır. Daha eski Android'de HEIC seçilirse "Bu fotoğraf okunamadı"
  gösterilir (bu cihazlarda kamera zaten JPEG üretir).
- **Yön:** Android'de EXIF `Orientation`'dan döndürme açısı okunup
  piksellere uygulanır (`autoCorrectionAngle`); iOS `UIImage` yönü
  kendisi uygular. **Bilinen sınır:** Android yolu yansıtmalı yönleri
  (EXIF 2, 4, 5, 7) yalnızca döndürme olarak uygular; bu yönler pratikte
  bazı ön kameralarda görülür, sonuç aynalanmış görüntüdür (metadata
  sızmaz). Kabul edildi (platform sahibi, 2026-11-12: "aynalı fotoğraflara takılmayalım").
- **Ölçek:** paketin kuralı `max(1, min(g/minG, y/minY))`'dir; görüntü
  **hiçbir zaman büyütülmez**. Uzun kenarı sınırlamak için yönelim gerekir;
  bu yüzden üç adım:
  1. *Yoklama:* kaynak 1/8 alt örneklemeyle, ölçeklenmeden, yönü
     uygulanarak kodlanır; ölçülerinden yönelim ve (Android'de) yaklaşık
     boyut okunur.
  2. *Tam:* yataysa `minG = 1600, minY = 1`, dikeyse tersi; Android'de
     bellek için ikinin kuvveti alt örnekleme (uzun kenar ≥ 1600 kalacak
     kadar). Kalite 85.
  3. *Önizleme:* tam varyanttan, aynı kuralla 400 px. Kalite 80.
- **Biçim:** yalnızca JPEG. WebP iOS'ta ek kodlayıcı (SDWebImageWebPCoder)
  ister ve kazancı bu boyutlarda küçüktür; sözleşme ikisini de kabul eder.
- **Bellek:** bütün ara veriler bellektedir; kaynak en çok 40 MiB okunur.
  Diske görüntü yazılmaz.

### 3. Metadata silme: kendi kayıpsız JPEG temizleyicimiz ve denetçimiz

Platform kodlayıcısı `keepExif: false` ile EXIF kopyalamaz, ama bir
kodlayıcının ne yazacağı garanti değildir (ör. iOS ImageIO çıktısına
kendi EXIF'ini ekleyebilir). Garanti paketlere değil koda dayanır:

- `lib/core/medya/jpeg.dart` → `jpegTemizle`: JPEG'i segment segment
  yeniden kurar, piksellere dokunmaz. Kalan: DQT, DHT, DAC, DRI, SOFn, SOS
  ve tarama verisi, ICC profili (`APP2 ICC_PROFILE`), Adobe dönüşüm
  segmenti (`APP14 Adobe`), JFIF (`APP0`, **küçük resmi silinerek**
  yeniden yazılır). Atılan: diğer **bütün** APPn (EXIF/GPS, XMP,
  genişletilmiş XMP, MPF, IPTC/Photoshop, JFXX, üretici), COM, JPGn ve
  EOI'den sonraki her bayt (MPF ikinci resmi, "motion photo" videosu).
  İzin listesidir: bilinmeyen segment kalmaz.
- `jpegDenetle`: sunucunun denetiminin (Tayfam-Api
  `internal/core/app/media/inspect`) daha sıkısı: `FF D8 FF` ile başlar,
  `FF D9` ile biter ve sonrası boştur; tek SOFn; dosyanın **her yerinde**
  (ilerlemeli JPEG'in taramaları arası dahil) yalnızca JFIF, ICC ve Adobe
  uygulama segmentleri. Geçmeyen dosya gönderilmez.
- **Oran kuralı:** sunucunun kuralının aynısı, `|pg·ty − py·tg| ≤
  max(tg, ty)` ve önizleme her kenarda tamdan büyük değil; ölçüler
  çıktının başlığından okunur, tahmin edilmez. `complete`'e tam
  varyantın başlıktaki ölçüleri gider.
- **Kanıt (test):** `test/core/medya/ornekler/` altında sahte GPS'li EXIF,
  XMP, IPTC, MPF, JFXX küçük resmi, JFIF küçük resmi, yorum ve EOI'den
  sonra ikinci resim taşıyan temel ve ilerlemeli iki JPEG vardır (üretim
  betiği `tool/medya/ornek_jpeg_uret.py`). Testler, en kötü durumu
  canlandıran sahte kodlayıcıyla (metadata'yı aynen geri veren) hazırlama
  çıktısını **bayt düzeyinde** tarar: `Exif\0\0`, XMP ad alanı,
  `Photoshop 3.0`, `8BIM`, `MPF\0`, `JFXX`, sahte üretici/GPS işaretleri
  ve ikinci resmin SOI'si çıktıda yoktur; çıktı `jpegDenetle`'den geçer.

`image` (saf Dart) paketi değerlendirildi ve **seçilmedi**: HEIC okuyamaz
(iPhone'un varsayılanı), 12 MP fotoğrafı Dart yığınında çözmek ~50 MB ve
saniyeler sürer; metadata silmeyi ise kodlayıcıdan bağımsız temizleyicimiz
zaten garanti eder.

### 4. Yükleme

`lib/core/medya/yukleyici.dart`:

1. `POST /v1/uploads` (`purpose`, iki varyantın tür ve boyutu, kapak ve av
   fotoğrafında `tayfa_id`, `client_request_id`). `client_request_id` her
   seçilen fotoğraf için **bir kez** üretilir; "Tekrar dene" aynı hazır
   görüntüyü aynı id ile gönderir (ADR-0005).
2. Her varyant dönen imzalı linke `PUT` edilir. Bu istekler **`ApiClient`
   dışında**, `lib/core/api/medya_tasima.dart`'taki ayrı `http.Client` ile
   gider: link kendisi yetkidir, **erişim token'ı ve Tayfam başlıkları
   gönderilmez**. Sunucunun `headers`'ı aynen gönderilir (`Content-Length`
   gövdeyle tutmazsa istek gönderilmez; `Host`, `Authorization`, `Cookie`
   gelirse link güvenilmez sayılır). Link yalnızca `https` ve
   `*.r2.cloudflarestorage.com` ise kabul edilir (sunucudan gelen veri
   girdidir); yönlendirme izlenmez.
3. `POST /v1/uploads/{id}/complete` (tam varyantın ölçüleri) → `ready` ya
   da `rejected`.

Sınırlı tekrar (her adım en çok 3 deneme, 2–4–8 sn): `upload-not-received`
→ varyantlar yeniden `PUT` edilir; tamamlamada `unavailable` (503, depoya
ulaşılamadı, yükleme `pending` kalır) ve bağlantı hatası → beklenip
tekrarlanır; `PUT` bağlantı hatasında tekrarlanır; süresi dolmuş linkte
(403) aynı `client_request_id` ile yeni linkler istenir. Açılıştaki
`unavailable` (R2 yapılandırılmamış) tekrarlanmaz: "Fotoğraf yükleme şu an
kullanılamıyor" gösterilir. `rejected` tekrarlanmaz: "Fotoğraf kabul
edilmedi, başka bir fotoğraf seç".

İmzalı linkler, nesne anahtarı, dosya içeriği ve metadata log'a yazılmaz;
`medya_tasima` günlüğe yalnızca yöntem ve durum kodu yazar. Hata türleri
adres taşımaz.

### 5. Görüntüleme ve önbellek (yalnızca bellek)

- `lib/core/medya/medya_onbellegi.dart`: aynı olay döngüsü turunda istenen
  kimlikler tek `POST /v1/media/urls` isteğinde birleşir (en çok 100).
  Link `expires_at`'tan 1 dakika önce, en geç 1 saatte düşer. Yanıtta
  olmayan (görülemeyen) kimlik 5 dakika "yok" sayılır. Linkler doğrulanır
  (§4 kuralı); geçersizse dosya görülemiyor sayılır.
- Baytlar kendi `http.Client`'ımızla indirilir ve `Image.memory` ile
  çizilir; bellek önbelleği en çok 32 MiB, en eski kullanılan önce atılır.
  `Image.network` kullanılmaz: hata mesajına adresi yazar (kesin kural 3).
  Süresi dolmuş linkte (403) link bir kez yenilenir.
- Yeni yüklenen fotoğrafın baytları önbelleğe hemen konur (yeniden
  indirilmez).
- **Hiçbir şey diske yazılmaz** (ADR-0006): link, görüntü, ara dosya.
  Oturum değişince önbellek boşalır (ADR-0001 kural 8).
- **Widget'lar:** `MedyaGorseli` (yükleniyor, hata ve görülemeyen durumda
  nötr yüzey; ekran okuyucuya tek görsel ve etiket), `KullaniciAvatari`
  (fotoğraf yoksa ya da görülemiyorsa adın baş harfi, ad yoksa kişi
  ikonu), `FotografAlani` (formda ekle/değiştir/kaldır, hazırlanıyor ve
  yükleniyor durumları, hata ve "Tekrar dene").

### 6. Bağlama

- **Avatar:** Profil sekmesinde değiştir/kaldır; hazır yükleme hemen
  `PUT /v1/me/avatar` ile bağlanır, kaldırma `DELETE /v1/me/avatar`.
- **Tayfa kapağı:** Tayfa bilgileri formunda; "Kaydet"le
  `PATCH .../tayfas/{id}` `cover_upload_id` (kaldırma `""`).
- **Etkinlik kapağı:** oluşturma/düzenleme sihirbazının bilgi adımında;
  oluşturmada `cover_upload_id`, düzenlemede yalnızca değiştiyse (kaldırma
  `""`). Detayda tam varyant gösterilir.
- **Av fotoğrafı:** av ekleme formunda `photo_upload_id`; av satırında
  önizleme.
- Avatar profilde, kişi profilinde ve arkadaş listesinde gösterilir. Üye
  listesi, kanal ve birebir mesaj şemalarında `avatar_upload_id` yoktur
  (sözleşme önce gelir, kesin kural 1); oralarda gösterim Tayfam-Api'de
  sözleşme değişikliği bekler.
- Fotoğraf alanları yalnızca o formu açabilen role görünür (formun kendi
  kuralı); bağlamaya sunucu karar verir (kesin kural 5).

### 7. Hatalar

`upload-rate-limited`, `upload-quota-exceeded`, `upload-not-found`,
`upload-not-ready`, `upload-in-use`, `upload-not-received` ortak eşlemeden
(`hata_<kod>`) gelir; hazırlama hataları (`okunamadi`, `cokBuyuk`,
`islenemedi`), ret ve `unavailable` (medya kapalı) `medya_hata_*`
anahtarlarıyla gösterilir.

## Gerekçe

- Konumun sızmaması bir paketin davranışına bırakılmaz: izin listeli
  temizleyici ve sunucununkinden sıkı denetçi, testte en kötü durum
  kodlayıcısıyla kanıtlanır.
- Platform kodlayıcıları HEIC'i ve büyük fotoğrafı hızlı, düşük bellekle
  işler; Dart'ta saf çözme bunu yapamaz.
- Photo Picker/PHPicker izinsizdir: galeri izni istemeden "en az izin"
  ilkesine uyulur.
- İmzalı linkler `ApiClient`'tan ayrı gittiği için token depolama
  sağlayıcısına hiç ulaşmaz.

## Sonuçlar

- Yeni paketler: `image_picker`, `image_picker_android`,
  `image_picker_platform_interface`, `flutter_image_compress`. iOS'ta
  `flutter_image_compress` SDWebImage ve SDWebImageWebPCoder pod'larını
  getirir (kullanılmayan WebP yolu için); kabul edildi.
- Android'de yeni izin yok; CI'ın APK izin denetimi değişmez.
- `lib/core/medya/` (temizleyici, hazırlayıcı, seçici, yükleyici, önbellek,
  widget'lar) ve `lib/core/api/medya_tasima.dart` (imzalı linkler).
- Web geliştirme derlemesinde fotoğraf işleme desteklenmez (paketin web
  yolu ayrı bir betik ister); seçim yapılırsa "okunamadı" gösterilir
  (ADR-0011).
- Uygulama bütünlüğü (Play Integrity / App Attest) Tayfam-App #80'de.

## Değerlendirilen alternatifler

- **`image` (saf Dart) ile çözme ve kodlama:** platform bağımsız, test
  edilebilir; ama HEIC yok, büyük fotoğrafta yavaş ve bellek ağır.
- **İkisi birlikte (HEIC → platform, gerisi `image`):** iki yol, iki
  davranış; metadata garantisi zaten temizleyicide.
- **`image_picker`'ın kendi küçültmesi (`maxWidth`):** Android'de EXIF'i
  (GPS dahil) çıktıya kopyalar; kullanılmaz.
- **Flutter motorunun çözücüsü (`instantiateImageCodec`) + PNG:** JPEG
  yazamaz; HEIC desteği platforma göre değişir.
- **`Image.network` ve disk önbellekli görsel paketleri:** adres log'a
  girebilir ya da görüntü diske yazılır (ADR-0006).
