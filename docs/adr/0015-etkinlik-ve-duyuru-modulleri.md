# ADR-0015: Etkinlik ve duyuru modülleri, tayfa ana sayfası

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0002](0002-modul-yapisi.md), [ADR-0003](0003-gezinme-iskeleti.md), [ADR-0004](0004-tema-ve-bilesen-dili.md), [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0014](0014-tayfa-listesi-katilim-ve-olusturma.md); Tayfam-Api ADR-0008 (konum); Notion: Proje Planı §3, §4; Özellik Haritası "Etkinlik", "Duyuru ve soru-cevap"; Tasarım Standartları "Etkinlik türü renkleri"

## Bağlam

Tayfa ana sayfası şu an yalnızca mor üst bölümü gösteriyor. Sunucuda
duyurular (liste, oluşturma, düzenleme, silme, sabitleme) ve etkinlikler
hazır:

- tür, mod, katılım ve bekleme listesi,
- varış bildirimi (check-in, 300 m),
- iptal, tekrar (RRULE) ve `.ics`,
- türe özel araçlar: konvoy araçları, kamp malzemeleri, yürüyüş
  yoklaması, av günlüğü.

Modülleri sunucunun `modules` alanı açar (ADR-0002).

## Karar

### 1. Tayfa ana sayfası: iki bölüm

Platform sahibinin kararı (2026-11-11). Mor üst bölümün altında sırasıyla:

1. **Yaklaşan etkinlikler:** `GET /events`'ten en yakın üç kart ve
   "Tümü" bağlantısı.
2. **Duyurular:** önce sabitlenenler, sonra son üç duyuru ve "Tümü"
   bağlantısı.

Kurallar:

- Modül kapalıysa ilgili bölüm hiç görünmez.
- Boş bölümde kısa bir boş durum gösterilir. Yetkili kullanıcıya
  "Etkinlik aç" ya da "Duyuru yaz" kısayolu eklenir; yetkiyi sunucu
  verir (`caller_can_manage`, rol), istemci yalnızca kolaylık sağlar.
- Aşağı çekince yenilenir. Veri yalnızca bellekte tutulur (ADR-0006).

### 2. Duyurular

- **Liste:** önce sabitlenenler, sonra en yeniden eskiye, sayfalı.
- **Detay:** başlık ve gövde. Gövde düz metin olarak gösterilir; markdown
  ya da HTML yorumlanmaz. Bağlantılar dokunulabilir değildir.
- **Yazma ve düzenleme:** başlık (1–120 karakter) ve gövde (en çok 5000
  karakter). `client_request_id` form açılınca bir kez üretilir.
- **Sabitleme, kaldırma ve silme:** silmede onay istenir.
- Moderatör silmesini geri alma (`restoration`) yönetim ekranlarıyla
  gelir.

### 3. Etkinlikler

**Liste ve kart.** Kartta şunlar bulunur: tür çipi (renk ve ikon tür
kaydından, ADR-0004 Notlar), başlık, tarih ve saat (`tr_TR`, Europe/Istanbul),
yer adı ya da "Çevrimiçi", gelen/kontenjan bilgisi ve senin cevabın.
İptal edilen etkinlik soluk görünür ve "İptal edildi" etiketi taşır.

**Detay** şunları gösterir:
- açıklama,
- yer (harita önizlemesi; dokununca sistemin harita uygulaması açılır),
- çevrimiçi bağlantı (yalnızca üyelere gelir),
- organizatör,
- katılım sayıları ve katılımcılar listesi,
- türe özel bölüm.

**Katılım.** "Geliyorum", "Belki" ve "Gelmiyorum" seçenekleri var.
Kontenjan doluysa "Geliyorum" seçimi bekleme listesine düşer ve bu
gösterilir.

**Takvime ekleme.** `.ics` dosyası indirilip sistemin paylaşım menüsüyle
takvim uygulamasına verilir (`share_plus`).

**Oluşturma: adım adım sihirbaz** (platform sahibi, 2026-11-11). Adımlar:
1. Tür.
2. Başlık, açıklama, başlangıç ve bitiş.
3. Yüz yüze ise buluşma noktası (harita seçici), il ve ilçe. Çevrimiçi ise
   bağlantı.
4. Türe özel alanlar, kontenjan ve tekrar. Tekrar, "Her hafta / Her ay",
   aralık ve bitiş seçimleriyle verilir; RRULE istemcide üretilir.

Sihirbazın kuralları ADR-0014 §4'teki gibidir: girilenler korunur,
`client_request_id` bir kez üretilir. Kapak görseli dosya altyapısı (R2)
gelene kadar yoktur.

**Düzenleme ve iptal.** `caller_can_manage` ise gösterilir. İptalde gerekçe
istenir. Seri etkinlikte düzenlemenin yalnızca bu etkinliği değiştirdiği
söylenir.

### 4. Buluşma noktası: OpenStreetMap harita seçici

Platform sahibinin kararı (2026-11-11):

- **Paket:** `flutter_map`, OpenStreetMap karolarıyla. Anahtar ve
  faturalandırma gerekmez.
- **Kullanım:** haritada iğne bırakılır ya da ad aranır. Ad araması
  Nominatim ile, yalnızca "Ara"ya basınca yapılır; anlık otomatik tamamlama
  yoktur. Bunun nedeni Nominatim'in kullanım kuralı: saniyede en çok bir
  istek ve otomatik tamamlama yasağı. İsteklerde uygulamayı tanıtan bir
  `User-Agent` gönderilir; OSM atfı haritada gösterilir.
- **Gizlilik:** karo ve arama istekleri OSM'ye kullanıcının IP adresini ve
  bakılan bölgeyi gösterir. Cihazın konumu gönderilmez. Seçici açılınca
  harita il düzeyinde bir varsayılanla başlar; cihaz konumu bu ekranda
  **istenmez**. Bu yurt dışına aktarım aydınlatma metnine eklenir
  (hukukçu listesi).
- **Yük:** OSM karo sunucularının kullanım kuralı yoğun trafiği kabul
  etmez. Pilottan sonra kullanım büyürse karo sağlayıcısı yeniden
  değerlendirilir; `flutter_map` sağlayıcı değişimine izin verir.

### 5. Varış bildirimi ("Geldim")

- Düğme yalnızca pencere açıkken ve cevabın "Geliyorum" ise görünür.
  Pencere başlangıçtan 30 dakika önce açılır, bitişte kapanır.
- **Konum izni** yalnızca bu düğmeye basılınca, "uygulamayı kullanırken"
  kapsamıyla istenir. Paket: `geolocator`.
- Konum tek seferlik okunur, yalnızca istek gövdesinde gider; saklanmaz,
  önbelleğe alınmaz, loglanmaz (kesin kural 3).
- Hata metinleri uzaklık söylemez.
- Çevrimiçi etkinlikte konum istenmez; düğmenin adı "Katıldım" olur.

### 6. Türe özel araçlar

| Tür | Araç | Kim kullanır |
| --- | --- | --- |
| Konvoy | Araç listesi; kendi aracını ekleme | Herkes kendi aracı için |
| Kamp | Ortak malzeme listesi | Ekleme ve çıkarma: yönetim ve organizatör |
| Yürüyüş | "Çıktım" ve "Döndüm" düğmeleri | Katılımcılar |
| Balık | Av günlüğü | Katılımcılar |
| Oyun, spor | Yalnızca bilgi alanları | — |

- Plaka isteğe bağlıdır (sunucu 30 günde siler).
- Yürüyüşte dönmeme alarmı sunucudadır.
- Av günlüğünde mera gizliliği sunucunun alanlarına göre gösterilir.
- Organizatörün katılım düzeltmesi katılımcılar listesindedir.

### 7. Paketleme

Üç iş paketi:
1. **Duyurular ve ana sayfa bölümleri.** Etkinlik kartı salt okunur.
2. **Etkinlik çekirdeği:** liste, detay, katılım, katılımcılar, takvim,
   sihirbaz, harita seçici, düzenleme, iptal, tekrar.
3. **Varış bildirimi ve türe özel araçlar.** 2'den sonra yapılır.

## Gerekçe

- İki bölümlü ana sayfa, tayfanın iki ana sorusunu ("ne zaman, nerede?"
  ve "ne duyuruldu?") ilk ekranda cevaplar.
- Tür seçimi sonraki adımları belirlediği için sihirbaz doğal bir yapı;
  tayfa oluşturmayla da tutarlı.
- Koordinat, varış bildiriminin 300 m kontrolü için şart; harita seçici
  bunu güvenilir biçimde alır. OSM anahtar ve faturalandırma istemez.

## Sonuçlar

- Yeni paketler: `flutter_map` (yanında `latlong2`) ve `geolocator`
  (kesin kural 8; PR'larda gerekçe).
- Android'de konum izni (`ACCESS_FINE_LOCATION` ve
  `ACCESS_COARSE_LOCATION`) manifeste eklenir. CI'daki "yalnızca INTERNET"
  denetimi bu iki iznin gerekçesiyle güncellenir. iOS'ta kullanım
  açıklaması metni iOS işiyle gelir.
- Aydınlatma metnine OSM ve Nominatim'e IP adresi ve bakılan bölge
  aktarımı eklenir.

## Değerlendirilen alternatifler

- **Tek akış ya da sekmeler:** platform sahibi iki bölümü seçti.
- **Tek uzun form:** tür değişince alanlar yer değiştirir; sihirbaz
  seçildi.
- **Google Maps:** anahtar ve faturalandırma ister.
- **Metin ve harita linki:** paket gerektirmez, ama koordinatı güvenilir
  biçimde almak zahmetli.

## Notlar

- **2026-11-11 (platform sahibi, issue #38 / PR #39):**
  1. **Saat.** Etkinlik zamanları cihazın saat diliminde gösterilir ve
     girilir. Cihaz UTC+3 değilse saat diliminin adı belirtilir. Bu
     ADR-0008 ile uyumludur ve §3'teki "Europe/Istanbul" ifadesinin yerini
     alır. Tekrar kuralının `time_zone`'u `Europe/Istanbul`'dur. Sonu bir
     günle verilen tekrarın `UNTIL`'i o günün sonudur (Türkiye saati).
  2. **Katılımcı ve organizatör adları.** Sözleşmede katılımcı listesi
     yalnızca `user_id` döndürür. Ad, profil ucundan
     (`GET /v1/users/{id}/profile`) bir bellek önbelleğiyle alınır
     (`core/kullanici/`):
     - Ad yalnızca ekrana gelen satır için istenir.
     - Aynı kimlik için istekler tek uçuşta birleşir; aynı anda en çok
       dört profil isteği yapılır.
     - Önbellek oturum boyunca yalnızca bellekte tutulur (ADR-0006) ve
       oturum değişince sıfırlanır.
     - Bulunamayan kullanıcı "Silinmiş kullanıcı" olarak gösterilir;
       başka hatalar önbelleğe alınmaz.
     - Kullanım büyüyünce sözleşmeye `display_name` eklenmesi yeniden
       değerlendirilir.
  3. **Türe özel form alanları.** Bu alanlar şimdilik oluşturma
     sihirbazında, türe göre `switch` ile yazılır. Bu, ADR-0002'deki
     `EtkinlikTuru.formAlanlari` kaydından bir sapmadır. Gerekçe:
     arayüzün `formAlanlari(BuildContext)` imzası sihirbaz durumunu
     taşıyamaz. Detaydaki `aracBolumu` kancası kayıttan bağlıdır.
  4. **Konvoy rotası** (`ConvoyDetailsInput.route`) sihirbazda girilmez;
     §7'deki 3. paketle (türe özel araçlar) gelir.
- **2026-11-11 (PR #42):**
  - `EtkinlikTuru.aracBolumu` artık etkinlik kimliği yerine `Event` alır,
    çünkü türe özel araçlar tayfa kimliğine ve tek etkinlik yanıtındaki
    ayrıntılara ihtiyaç duyar. Ortak taban `KayitliEtkinlikTuru`.
  - Yürüyüşte "Geldim" gösterilmez; katılım "Çıktım" ile doğrulanır.
  - Organizatör düzeltmesi yalnızca bitişten sonraki 7 gün içinde gösterilir.
  - Kamp malzemesine kişi atama arayüzü yoktur; atanmışsa gösterilir.
  - Oturumdaki kullanıcının kimliği profil ucunun `self` alanından ad
    önbelleğiyle öğrenilir ("kendi aracım" gibi ayrımlar için; yetki kararı
    değildir).
  - Android izinleri: INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION.
    Arka plan konumu ve ön plan servisi izinleri `tools:node="remove"` ile
    engellenir. `USE_BIOMETRIC` ve `USE_FINGERPRINT` de kaldırılmıştır;
    Google girişi bunlar olmadan telefonda doğrulanmalıdır. CI, izinleri
    derlenen APK'dan denetler.
- **2026-11-12 (issue #113, Tayfam-Api #150):**
  - Oturumdaki kullanıcının kimliği artık `GET /v1/me/account`'un
    `user_id` alanından okunur (`kendiKimligimProvider`, yalnızca bellekte,
    oturum değişince yeniden). `kendisiMiProvider` bununla karşılaştırır;
    profil ucunun `self` alanına ve ad önbelleğine dolaylı başvuru
    kalktı. Ad önbelleği yalnızca adı tutar.
  - Profil ucu ad ve avatarı ortak tayfa ya da arkadaşlık olmadan da
    döndürür; engel ya da silinmiş hesapta `user-not-found`. Bildirim
    kartında bu durumda ad yerine "Biri" yazılır.
