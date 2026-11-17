# ADR-0019: Push bildirimleri (FCM)

- **Durum:** Kabul edildi (platform sahibi, sohbette, 2026-11-11)
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Arslan (kapsam, izin zamanı, google-services.json,
  tek Firebase uygulaması); uygulama ayrıntıları mimari oturumu
- **İlgili:** ADR-0001, ADR-0002, ADR-0005, ADR-0006, ADR-0007, ADR-0008,
  ADR-0011, ADR-0018 §3; Tayfam-Api [ADR-0019](https://github.com/murattarslan-dev/Tayfam-Api/blob/main/docs/adr/0019-push-bildirimleri.md)
  (sunucu tarafı), sözleşme `/v1/me/push-token`; issue #73

## Bağlam

Sunucu push'u Tayfam-Api ADR-0019 ile kurdu: token oturuma bağlıdır,
gönderim FCM HTTP v1 ile, açık WebSocket bağlantısı yokken (ve
`hike_overdue` için her zaman) yapılır. Push metin taşımaz: Android
`title_loc_key` / `body_loc_key` = `push_<tür>_title|body`, çeviri argümanı
yoktur; `data` yalnızca kimlik taşır; kanallar `tayfam_messages`,
`tayfam_alerts`, `tayfam_general`'dır ve istemci açar.

ADR-0018 push'u v0.1.0'ın dışında bırakmıştı. Platform sahibi
2026-11-11'de push'un bu sürüme girmesine karar verdi (sohbette).

## Karar

### 1. Paketler ve yapılandırma

- `firebase_core` ve `firebase_messaging` (yayıncı firebase.google.com).
  `firebase_messaging` 17.x hattı (2026-11-17'ye kadar 16.7; bkz. Notlar):
  push kimliği **Firebase Installation ID (FID)**'dir ve `register()` /
  `onRegistered` / `unregister()` ile yönetilir. Kullanımdan kalkan kayıt
  token'ı API'si (`getToken`, `onTokenRefresh`, `deleteToken`) Firebase'in
  uyarısına uygun olarak hiç çağrılmaz; sunucu FID'e `message.fid` ile
  gönderir (Tayfam-Api ADR-0036).
- Android `minSdk` açıkça **26**'dır (Android 8.0; platform sahibi kararı,
  2026-11-17). firebase_messaging 17 / Firebase BoM 35 en az 24 ister.
- **Firebase Analytics, Crashlytics ve başka Firebase ürünü eklenmez.**
  Manifestte `firebase_analytics_collection_deactivated=true`,
  `google_analytics_adid_collection_enabled=false`,
  `delivery_metrics_exported_to_big_query_enabled=false`.
- **Otomatik FCM kaydı kapalıdır** (`firebase_messaging_auto_init_enabled
  =false`): kayıt yalnızca oturum açık ve izin verilmişken yapılır;
  kayıt istenince otomatik kayıt açılır, çıkışta yeniden kapanır.
- `android/app/google-services.json` **repodadır** (platform sahibi,
  sohbette). İçindeki değerler (proje kimliği, uygulama kimliği, `AIza…`
  API anahtarı) her APK'da açıkça bulunan istemci tanımlayıcılarıdır
  (kesin kural 6); gizli değildir. Dosya yoksa Gradle anlaşılır bir
  hatayla durur. gitleaks yalnızca bu dosya yolu ve `gcp-api-key` kuralı
  için daraltılmış istisna taşır (`.gitleaks.toml`).
- **Tek Firebase projesi ve tek Android uygulaması** (`com.murattarslan.tayfam`;
  platform sahibi, 2026-11-11 18:24, sohbette): geliştirme ve prod
  derlemesi aynı uygulama kimliğini ve aynı Firebase uygulamasını
  kullanır; yalnızca API adresi (`--dart-define=TAYFAM_API`) değişir.
  Flavor, `applicationIdSuffix` ya da ayrı Firebase uygulaması yoktur.
- `com.google.gms.google-services` Gradle eklentisi sabit sürümle.
- Firebase'e yalnızca `core/push/firebase_push_platformu.dart` dokunur;
  `main.dart` onu mobilde verir. Web geliştirme derlemesinde ve testlerde
  push kapalıdır (`KapaliPushPlatformu`; ADR-0011).

### 2. Push kimliği = oturum

- Açılışta altyapı başlatılınca `onRegistered` dinlenmeye başlar
  (Firebase: `register()`'dan önce abone ol).
- Oturum açık olunca (giriş, kayıt/onay sonrası ve her açılış) ve izin
  verilmişse `register()` çağrılır. FID dönüşte değil `onRegistered`
  akışından gelir; gelen FID, oturum açık ve izin verilmişse
  `PUT /v1/me/push-token` (`platform: android`, `token_type: fid`) ile
  kaydedilir. FID değişince ya da her `register()`'da yeniden
  yayınlanınca aynı yol işler; aynı oturumda zaten kaydedilmiş FID
  tekrar gönderilmez (yalnızca bellekte tutulur). 16.x'ten yükselen
  cihazda sunucudaki eski kayıt token'ı satırı aynı oturumun `PUT`'uyla
  FID'e döner (Tayfam-Api ADR-0036 §1).
- **Çıkışta** önce `DELETE /v1/me/push-token`, sonra cihazda
  `unregister()` (otomatik kayıt da kapanır); ardından
  `POST /v1/auth/sign-out`. Sunucuya ulaşılamasa da devam edilir (oturum
  kapanınca sunucu siler).
- **Oturum başka yoldan kapanırsa** (sunucu kapattı, yenileme reddedildi,
  hesap silindi) cihazda `unregister()` yapılır; sunucudaki kaydı oturum
  bitişi siler (Tayfam-Api ADR-0019 §1). Hesap silmede ayrıca `DELETE`
  çağrılmaz: yeniden girişle açılan oturumun kaydı yoktur ve
  `user.deleted` bütün kayıtları siler.
- İşler sırayla yürür, hata fırlatmaz. **FID loglanmaz** ve uygulamanın
  hiçbir deposuna yazılmaz; yalnızca FCM SDK'sının kendi deposunda durur.

### 3. İzin: ilk gerçek ihtiyaçta

(platform sahibi, sohbette, 2026-11-11)

- Android 13+ `POST_NOTIFICATIONS` açılışta istenmez. **İlk gerçek
  ihtiyaçta** istenir: ilk tayfaya katılınca ya da tayfa kurunca, ilk
  birebir mesaj gönderilince.
- Önce uygulamanın kendi kısa **açıklama kartı** (kabuğun içeriğinin
  altında, modal değil): "İzin ver" sistem penceresini açar, "Şimdi değil"
  kartı kapatır.
- Kart bir kez gösterilir (kabul ya da ret); bayrak
  `CihazAyarlariDeposu`'nda (`bildirimIzniSoruldu`). İzin bir daha
  kendiliğinden sorulmaz.
- **Profil → Bildirimler**: cihazdaki izin durumu; izin yoksa "Bildirimleri
  aç" (sistem penceresi gösterilebiliyorsa o, gösterilemiyorsa uygulamanın
  sistem bildirim ayarı); kanalları yönetmek için sistem ayarı. Uygulama ön
  plana dönünce izin yeniden okunur; yeni verildiyse token kaydedilir.
- Sunucudaki bildirim tercihleri (tayfa/konuşma sessize alma) bu ekranda
  değildir; ilgili menülerde kalır.

### 4. Kanallar, metinler, simge

- Üç kanal uygulama açılışında kurulur; adları ve açıklamaları ARB'dedir
  (`push_kanal_*`). Kurulum için ek paket yoktur: `MainActivity.kt`'de küçük
  bir `MethodChannel` (`tayfam/bildirim`: `kanallariKur`, `ayarlariAc`).
  `tayfam_messages` ve `tayfam_alerts` yüksek, `tayfam_general` varsayılan
  önemdedir; kilit ekranında görünürlük "özel".
- **Push metinleri** (`push_<tür>_title|body`, sözleşmedeki
  `NotificationType`'ın her değeri için) içeriksiz ve geneldir ("Yeni
  mesaj", "Yeni etkinlik"); isim, başlık, konum, sayı yoktur; birebir
  mesajda gönderen yoktur (kesin kural 7).
- **Tek kaynak ARB'dir.** Metinler Android `res/values/strings.xml`'e
  `tool/kurallar/bin/android_metinleri.dart` ile üretilir; kural betiği
  (`android-metinleri`) dosyanın ARB'yle aynı olduğunu CI'da denetler ve bu
  anahtarları "kullanılmayan" saymaz. Kaynak küçültme bu metinleri ve
  simgeyi silmesin diye `res/raw/tayfam_keep.xml` vardır.
- Varsayılan kanal `tayfam_general`; varsayılan simge `ic_bildirim`
  (logonun tek renkli hali — 2026-11-12'ye kadar monogramdı, bkz. Notlar;
  `tool/ikon/ikon_uret.py` üretir); renk marka
  yüzeyi (`ic_launcher_background`).

### 5. Dokunma ve ön plan

- Bildirime dokunma (`getInitialMessage`, `onMessageOpenedApp`): `data`
  girdi kabul edilir; kimlikler UUID biçiminde, `type` ve `target_type`
  bilinen değerlerden olmalıdır. Geçerliyse bildirim
  `PUT /v1/notifications/{id}/read` ile okundu işaretlenir ve hedefi
  `bildirimAdresi` ile açılır (Bildirimler sekmesindeki eşlemeyle aynı).
  Geçersizse ya da hedefin ekranı yoksa Bildirimler sekmesi açılır.
- Ön planda gelen mesajda (`onMessage`) sistem bildirimi gösterilmez;
  rozet ve (açıksa) bildirim listesi yenilenir.
- `data` ve bildirim içeriği loglanmaz.

### 6. İzinler (APK)

CI'daki APK izin denetimine eklenenler: `POST_NOTIFICATIONS`,
`WAKE_LOCK` ve `ACCESS_NETWORK_STATE` (FCM'in mesaj alırken cihazı kısa
süre uyanık tutması ve bağlantı durumu; kullanıcıya sorulmayan normal
izinler). `com.google.android.c2dm.permission.RECEIVE` FCM'in teslim
iznidir.

## Gerekçe

- İzni ilk ihtiyaçta, açıklamayla istemek kabul oranını artırır ve "en
  az izin, gerektiği anda" ilkesine uyar; reddedeni tekrar tekrar
  rahatsız etmez.
- Metinlerin ARB'de tek kaynağı olması çeviri ve gözden geçirmeyi tek yerde
  tutar; Android kaynağı elle düzenlenmez.
- Firebase'i tek sınıfa hapsetmek testleri Firebase'siz, web derlemesini
  push'suz tutar.
- `google-services.json`'ı repoda tutmak CI'ı secret'sız ve fork PR'larında
  da çalışır kılar; değerler zaten APK'da public'tir.

## Sonuçlar

- ADR-0018 §3'teki "Push (FCM) bu sürümde yoktur" ve Sonuçlar'daki "Push
  bu sürümün dışında" kaydı bu ADR'yle değişti.
- FCM SDK'sı (firebase_messaging eklentisi), uygulama arka plandayken gelen
  bildirim mesajını `getInitialMessage` için kendi `SharedPreferences`
  dosyasında kısa süre tutar. Mesajda içerik yoktur (yalnızca kimlikler ve
  çeviri anahtarları); ADR-0006'nın "diske içerik yok" ilkesi korunur.
- iOS'ta push bu sürümde yoktur: `GoogleService-Info.plist` ve APNs
  anahtarı eklenince açılır (platform `ios`); o zamana kadar başlatma
  başarısız sayılır ve push kapalı kalır.
- Platform sahibinin işi: Firebase projesinde Android uygulaması
  (`com.murattarslan.tayfam`) ve SHA parmak izleri; API tarafında FCM
  servis hesabının prod'a verilmesi (Tayfam-Api ADR-0019 §7–§8).

## Değerlendirilen alternatifler

- **`flutter_local_notifications`:** kanal kurma ve ön planda bildirim
  göstermek için yaygın; ama ön planda bildirim göstermiyoruz ve kanal
  kurulumu birkaç satır Kotlin. Ek paket ve izin yüzeyi gereksiz.
- **İzni açılışta istemek:** bağlamsız istek reddedilme olasılığını artırır.
- **`google-services.json`'ı CI secret'ı yapmak:** değerler public; secret
  yönetimi ve fork PR'larında kırılan derleme kazancı aşar.
- **16.7 hattında kalmak:** kayıt token'ı API'si kullanımdan kalktı ve
  kaldırılacak; Dependabot güncellemeleri birikir. Sunucu FID'i
  desteklediği için (Tayfam-Api ADR-0036) gerekçesi kalmadı.
- **17.x'te deprecated `getToken`'ı kullanmaya devam etmek:** Firebase iki
  API'yi birlikte kullanmamayı söylüyor ve eski API kaldırılacak; analiz
  uyarısını susturmak sorunu erteler.

## Notlar

- **2026-11-12 (platform sahibi; PR #99):** §4'teki varsayılan simge
  `ic_bildirim` artık eski monogramın değil, yeni "Dörtlü" logonun tek
  renkli (beyaz) halidir (`tayfam-tek-renk.svg`; `tool/ikon/ikon_uret.py`
  üretir). Kaynak adı ve manifestteki `default_notification_icon` /
  `default_notification_color` değişmedi. Uyarlanabilir uygulama ikonuna
  Android 13+ temalı ikon için tek renk (monochrome) katman eklendi.
- **2026-11-17 (platform sahibi; issue #212, Tayfam-Api #230 / ADR-0036):**
  `firebase_core` 4 → 5.2, `firebase_messaging` 16.7 → 17.1. Push kimliği
  kayıt token'ından FID'e geçti (§1, §2); seçenek "önce sunucu": sunucu
  sözleşmesi (`token_type`) ve `message.fid` gönderimi önce birleşti.
  **Platform sahibi kararı, 2026-11-17:** Android `minSdk` açıkça 26
  (Android 8.0); 17.x en az 24 ister. Firebase iOS SDK 13'ün istediği iOS
  15 zaten hedefti. Yeni izin eklenmedi.
