# ADR-0023: Uygulama bütünlüğü (istemci)

- **Durum:** Kabul edildi (platform sahibi, 2026-11-12, sohbette)
- **Tarih:** 2026-11-12
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0005](0005-api-istemcisi.md) (ApiClient, SessionStore, tek uçuşta yenileme), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0010](0010-signal-kutuphanesi.md) (Kotlin köprüsü düzeni), [ADR-0011](0011-yalnizca-mobil.md), [ADR-0012](0012-giris-ve-kayit-akisi.md) (Google girişi, nonce); Tayfam-Api ADR-0022 ve sözleşmedeki `integrity_token`, `integrity_check_after`, `integrity-required` (62feb2e); issue #80

## Bağlam

Tayfam-Api ADR-0022 (kabul, 2026-11-12) uygulama bütünlüğünü oturuma
bağladı: kanıt girişte ve 24 saatte bir token yenilemede gelir, sonuç
oturuma yazılır. Platform sahibinin kararları: önce **yalnızca kayıt**
(`report`; sunucu hiçbir isteği reddetmez), Android'de
`MEETS_STRONG_INTEGRITY`, giriş + 24 saatte bir yeniden doğrulama. Play
Console'da uygulama Play Integrity API için Google Cloud projesine
(`tayfam-514116`, proje numarası 73439258394) bağlandı (2026-11-12).

Sözleşme (62feb2e):

- `SignInRequest.integrity_token` ve `RefreshRequest.integrity_token`
  isteğe bağlı (en çok 16384 karakter). Yenilemede yalnızca
  `integrity_check_after` geçtiyse gönderilir; öncesinde yok sayılır.
- `Session.integrity_check_after` (zaman): bundan sonraki ilk yenileme
  kanıt taşır. Denetim kapalıyken alan yoktur.
- `integrity-required` (403): yalnızca ortam `enforce` modundayken, kanıtı
  geçmemiş oturumun erişim token'ı alır (WebSocket el sıkışması dahil).
  Giriş, yenileme, çıkış, kayıt, onaylar, oturumlar, hesap silme, KVKK
  dışa aktarma ve `status`/`client-config` muaftır.

iOS App Attest için Apple Developer üyeliği yok; sözleşmede `app_attest`
alanı da henüz yok.

## Karar

### 1. Kapsam: önce yalnızca Android

- Bu ADR Android Play Integrity'yi (standard request) uygular. **iOS App
  Attest iOS sürümüne kalır**: Apple Developer üyeliği ve sözleşmeye
  `app_attest` alanı geldiğinde ayrı bir issue ve bu ADR'ye not ile.
  O zamana kadar iOS'ta ve web geliştirme derlemesinde sağlayıcı yoktur
  (`OlmayanButunlukSaglayici`, her zaman `null`): istekler kanıtsız gider,
  `report` modunda sunucu bunu yalnızca `missing` olarak sayar.
- Bağlama değeri Dart'ta hesaplanır; App Attest'in `clientDataHash`'i aynı
  değerden türeyeceği için iOS'ta yeniden yazılmaz.

### 2. Bağlama değeri (Tayfam-Api ADR-0022 §2 ile birebir)

```
sign-in:  base64url(SHA-256("tayfam-integrity/v1/sign-in\n" + nonce))
refresh:  base64url(SHA-256("tayfam-integrity/v1/refresh\n" + SHA-256(refresh_token)))
```

- base64url **dolgusuz** (43 karakter); yenilemedeki iç özet **ham
  bayttır** (hex ya da base64 değil). Metinler UTF-8.
- Android'de `requestHash` olarak gider. Nonce, Google girişinde
  `google_sign_in`'e verilen ve `SignInRequest.nonce`'ta giden değerdir
  (ADR-0012 §2). Nonce **her giriş denemesinde** (yeniden giriş dahil)
  `Random.secure()` ile yeniden üretilir; böylece her girişin bağlama
  değeri farklıdır (2026-11-12 düzeltmesi: önceden süreç başına tek nonce
  vardı, bkz. Notlar).
- **Yenileme token'ı Google'a gitmez**, Kotlin köprüsüne de gitmez: köprüye
  yalnızca özetin özeti verilir. Token, yenileme token'ı, nonce ve istek
  özeti hiçbir yere loglanmaz (kesin kural 3).
- SHA-256 için `crypto` paketi (dart.dev, Dart ekibi) doğrudan bağımlılık
  olur. Dart standart kütüphanesinde SHA-256 yok; Signal köprüsünde de
  özet işlemi yok. Paket zaten geçişli bağımlılıktı (pubspec.lock'ta aynı
  3.0.8), saf Dart, izin getirmez; kendi kriptomuzu yazmamış oluruz (kesin
  kural 4).
- Doğruluk, sunucunun kendi testindeki vektörlerle sınanır
  (`SignInBinding("n")`, `RefreshBinding("abc")`).

### 3. Android köprüsü

- Kütüphane: Google'ın resmi **`com.google.android.play:integrity`**
  (Google Maven), sürüm tam sabit (**1.6.0**).
- `MainActivity`'deki mevcut kanallara dokunmadan ayrı sınıf:
  `android/.../butunluk/ButunlukKoprusu.kt`, `MethodChannel("tayfam/butunluk")`;
  akış mantığı JVM'de sınanabilsin diye Play'e bağımlı olmayan
  `ButunlukIslemleri.kt`'de.
- Yöntemler: `hazirla {proje}` ve `token {proje, istekOzeti}`.
- **Standard request:** `StandardIntegrityManager.prepareIntegrityToken`
  (bulut proje numarasıyla) bir kez çağrılır, token sağlayıcısı bellekte
  tutulur; hazırlık sürerken gelen istekler aynı hazırlığı bekler. Token
  `request(requestHash)` ile alınır.
- Hazırlık **uygulama açılışında** yapılır: Dart'taki sağlayıcı ilk
  okunduğunda (`SessionStore` kurulurken) `hazirla` çağrılır. Başarısızsa
  ilk token isteği yeniden hazırlar.
- `INTEGRITY_TOKEN_PROVIDER_INVALID`: sağlayıcı yeniden hazırlanır ve istek
  **bir kez** tekrarlanır; yine geçersizse `saglayiciGecersiz`.
- `StandardIntegrityErrorCode` → tür (`ButunlukHatasiTuru`): Play yok
  (`playYok`), Play/API eski ya da yok (`playEski`), ağ (`ag`), kota
  (`kota`), Google/istemci geçici (`gecici`), yapılandırma (proje numarası,
  uygulama kimliği, istek özeti; `yapilandirma`), bilinmeyen. Kanalda hata
  kodu yalnızca tür adıdır; mesajda token ya da özet yoktur. Köprüde log
  yoktur.
- Bulut proje numarası Gradle'a ya da Kotlin'e gömülmez; Dart'tan gelir:
  `--dart-define=TAYFAM_BULUT_PROJE_NUMARASI`, varsayılanı 73439258394.
  Public bir değerdir (APK'dan okunabilir; kesin kural 6).

### 4. Akış

- **Giriş** (`HesapDeposu.girisYap`; ana giriş ve hesap silme / veri
  dışa aktarmadaki yeniden giriş aynı yoldan): nonce'a bağlı kanıt istenir;
  alınırsa `integrity_token` olarak eklenir, alınamazsa **alan gönderilmez**.
- **Yenileme** (yalnızca `SessionStore`, tek uçuşta; ADR-0005 §3):
  - `integrity_check_after` giriş ve yenileme yanıtlarından okunup oturum
    kaydında tutulur.
  - O zaman geldiyse (`şimdi ≥ integrity_check_after`) yenileme isteğine
    yenileme token'ının özetine bağlı kanıt eklenir. Alan yoksa (denetim
    kapalı) ya da zamanı gelmediyse Play'e gidilmez (kota ve gecikme).
  - Kanıt, `GET /v1/status` yoklamasından **sonra** (bağlantı yoksa Play
    kotası harcanmaz) ve yenileme token'ı **harcanmadan önce** alınır.
    Böylece "gönderilmiş token bir daha gönderilmez" kuralı ve sunucunun
    10 saniyelik toleransı etkilenmez: kanıt beklenirken token henüz
    gönderilmemiştir, eşzamanlı istekler aynı uçuşu bekler.
- **Hata durumunda kanıtsız devam:** kanıt alma en çok **5 saniye**
  sürebilir; aşılırsa, Play hatası verirse ya da platform yoksa istek
  kanıtsız gider. Kanıt hiçbir koşulda giriş ya da yenilemeyi
  engellemez. Günlüğe yalnızca hata türü yazılır (`bütünlük: ag`).

### 5. `integrity-required`

Sunucu şimdilik `report` modunda olduğu için dönmez. Gelirse (`enforce`):

- `ApiClient`, isteği reddedilen erişim token'ı için `SessionStore`'dan
  **kanıtla zorunlu bir yenileme** ister (`butunlukGerekti`; zamanı
  gelmemiş olsa da kanıt eklenir, tek uçuşta) ve isteği **bir kez**
  tekrarlar.
- Kanıtla alınmış token da reddedilirse yenileme bir daha yapılmaz; hata
  çağırana döner ve kullanıcıya `ProblemType.integrityRequired` çeviri
  metni gösterilir (ADR-0005 §4). Böylece kanıt veremeyen bir cihazda her
  istek yeni bir yenileme ve Play çağrısı üretmez. Oturum kapanmaz:
  muaf uçlar (hesap silme, KVKK dışa aktarma, çıkış) çalışmaya devam eder.
- WebSocket el sıkışmasındaki `integrity-required` için ayrı davranış
  yoktur; REST isteğinin tetiklediği kanıtlı yenilemeden sonra mevcut
  yeniden bağlanma yeni token'la bağlanır. `enforce`'a geçişten önce
  (Tayfam-Api ADR-0022 §6) yeniden değerlendirilir.

### 6. `integrity_check_after` nerede tutulur (ADR-0006)

Oturum kaydıyla birlikte **güvenli depoda** (`KayitliOturum`,
`butunluk_sonra` alanı), oturumla birlikte silinir. ADR-0006'nın "token ve
iki oturum bayrağı" listesine eklenen üçüncü değerdir; gerekçe:

- İçerik ya da kişisel veri değildir: sunucunun bildirdiği bir sonraki
  denetim zamanıdır, oturuma bağlıdır ve token kaydından ayrı bir anlam
  taşımaz.
- Yalnızca bellekte tutulsaydı uygulama her soğuk açılışta zamanı
  bilemezdi: ya ilk yenilemede kanıt gönderilmez (denetim zamanı geçmişse
  sunucu `passed` oturumu `failed/stale` sayar) ya da her açılışta Play'e
  gidilirdi (kota, 5 saniyeye kadar gecikme).
- Kayıt sürümü değişmez (`v: 1`); alan isteğe bağlıdır, eski kayıtta yoksa
  kanıt gönderilmez ve ilk yenileme yanıtı zamanı getirir.

## Gerekçe

- Sunucu tasarımı (oturum düzeyi, var olan tek kullanımlık değerlere
  bağlama) istemciye yeni uç ya da yeni bir yenileme yolu getirmez; kanıt
  mevcut tek yenileme noktasına eklenir.
- Kanıtı hiçbir koşulda engelleyici yapmamak "yalnızca kayıt" kararına ve
  Google'ın "önce gözlemle" önerisine uyar; Play kesintisi kullanıcıyı
  dışarıda bırakmaz.
- Bağlama değerini Dart'ta hesaplamak yenileme token'ını platform koduna
  hiç taşımaz ve iOS'ta yeniden yazmayı önler.

## Sonuçlar

- Yeni bağımlılıklar: `crypto` (Dart, zaten geçişli) ve
  `com.google.android.play:integrity:1.6.0` (Android). İkisi de izin
  getirmez; APK izin denetimi CI'da sürer.
- Play Integrity yalnızca Play'den kurulan (iç test kanalı dahil) ve Play
  App Signing ile imzalı derlemede `passed` olur; CI'ın debug APK'sı
  `failed/app_unrecognized` sayılır. `report` modunda etkisi yoktur.
- Google'a cihaz bütünlüğü isteği gönderilir; KVKK aydınlatma metnine
  eklenmesi Tayfam-Api ADR-0022'de platform sahibine bırakıldı.
- Testler: bağlama vektörleri, girişte alanın eklenmesi/eklenmemesi,
  yenilemede `integrity_check_after` öncesi/sonrası, kanıt beklerken tek
  uçuş, zaman aşımı, kanal hata türleri (sahte `MethodChannel`),
  `integrity-required` ile tek tekrar; Kotlin akışı (hazırlık, yeniden
  hazırlama, hata eşlemesi) sahte Play ile JVM'de.

## Değerlendirilen alternatifler

- **Özeti Kotlin'de hesaplamak (`MessageDigest`):** Dart paketi gerekmez;
  ama yenileme token'ı platform koduna taşınır, iOS'ta Swift'te yeniden
  yazılır ve vektör testi yalnızca JVM'de kalır.
- **Classic request (`IntegrityManager.requestIntegrityToken`):** her
  istekte Google'a tam tur, daha yavaş ve kota açısından pahalı; sunucu
  standard request bekliyor.
- **`integrity_check_after`'ı yalnızca bellekte tutmak:** §6'daki kaçan
  denetim ya da her açılışta Play çağrısı.
- **`integrity-required`'da oturumu kapatmak:** kullanıcı muaf uçlara
  (hesap silme, veri talebi) ulaşamaz; Tayfam-Api ADR-0022 §6'ya aykırı.

## Notlar

- **2026-11-12 (platform sahibi, sohbette):** ADR §5 ve §6 dahil kabul
  edildi. Aynı PR'da (#121) Google girişindeki nonce düzeltildi: önceden
  `google_sign_in` yalnızca `initialize` sırasında nonce aldığı için süreç
  başına tek nonce üretiliyordu; aynı süreçteki ikinci giriş (hesap silme
  ya da veri dışa aktarmadaki yeniden giriş) aynı nonce'u ve aynı bütünlük
  bağlamasını kullanıyordu. Artık her denemede yeni nonce üretilir ve
  `initialize` o nonce'la yeniden çağrılır. `google_sign_in` belgesi
  `initialize`'ın bir kez çağrılmasını ister; Android uygulaması
  (`google_sign_in_android` 7.2.x) `init`'te yalnızca parametreleri saklar
  ve olay akışı yoktur, bu yüzden tekrar çağrı güvenlidir. Paket
  yükseltmelerinde bu varsayım yeniden doğrulanır; iOS girişinde (#122 ile
  birlikte) ayrıca bakılır.
