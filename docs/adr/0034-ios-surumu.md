# ADR-0034: iOS sürümü: Mac'siz derleme, TestFlight ve platform köprüleri

- **Durum:** Önerildi (çerçeve kararları platform sahibinin 2026-11-24
  sohbetinden; ayrıntılar bu ADR'de seçildi ve PR'da onaya sunulur. Platform
  sahibine sorular: "Açık sorular")
- **Tarih:** 2026-11-24
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0009](0009-test-ci-ve-ios.md),
  [ADR-0010](0010-signal-kutuphanesi.md),
  [ADR-0012](0012-giris-ve-kayit-akisi.md),
  [ADR-0013](0013-tanitim-sitesi.md),
  [ADR-0019](0019-push-bildirimleri.md),
  [ADR-0020](0020-birebir-uctan-uca-sifreleme-istemci.md),
  [ADR-0023](0023-uygulama-butunlugu-istemci.md),
  [ADR-0029](0029-dal-modeli-dev-main-ve-surum.md); Tayfam-Api ADR-0022,
  Tayfam-Api #195; bu repoda #122

## Bağlam

Uygulama bugüne kadar yalnızca Android'de yayınlandı (Play kapalı test,
v0.3.0). iOS için Apple Developer üyeliği yoktu; önceki ADR'ler iOS'a
kalan işleri tek tek not etti: derleme (ADR-0009), Apple ile giriş
(ADR-0012), push (ADR-0019), Signal köprüsü (ADR-0010, ADR-0020), App
Attest (ADR-0023).

2026-11-24'te platform sahibi Apple Developer hesabını etkinleştirdi ve
App Store Connect'te uygulama kaydını (`com.murattarslan.tayfam`) açtı.
Aynı gün sohbette şunlara karar verdi:

1. Mac ve iOS cihaz yoktur. Uygulama doğrudan GitHub Actions'ta derlenir,
   imzalanır ve TestFlight'a yüklenir; test kullanıcıları oradan dener.
2. Dart kodu karartılmaz (`--obfuscate` yok).

Depodaki durum: `ios/` Flutter şablonudur (bundle kimliği ve iOS 15.0
hedefi ayarlı; `Info.plist`'te kamera ve fotoğraf açıklamaları var, konum
açıklaması yok; entitlement dosyası, `GoogleService-Info.plist`, Podfile
yok). Android'de dört platform kanalı var: `tayfam/e2e/signal`,
`tayfam/butunluk`, `tayfam/bildirim`, `tayfam/kronometre`; hiçbirinin iOS
karşılığı yazılmadı.

## Karar

### 1. Aşamalar

iOS tek seferde değil, her biri ayrı iş kaydı olan aşamalarla gelir. Sıra,
cihazsız çalışırken hatayı erken görmek için seçildi: önce derlenen ve
açılan bir uygulama, sonra tek tek yetenekler.

| # | Aşama | Bağlı olduğu |
|---|-------|--------------|
| 1 | CI'da imzasız simülatör derlemesi (`ci.yml`, zorunlu kontrol) | — |
| 2 | İmzalı derleme ve TestFlight yüklemesi; `Info.plist` izin metinleri, ikon, açılış ekranı; iOS'ta Google ile giriş | Platform sahibi: API anahtarı, Team ID, iOS OAuth istemcisi |
| 3 | Apple ile giriş | Tayfam-Api'de sözleşme ve identity (önce sunucu) |
| 4 | Push (APNs üzerinden FCM) | Platform sahibi: APNs anahtarı, Firebase iOS uygulaması |
| 5 | Universal Links (davet, referans, QR katılım) | Team ID |
| 6 | App Attest | Tayfam-Api #195, sözleşmede `app_attest` |
| 7 | Signal köprüsü (birebir uçtan uca şifreleme) | Hukukçu görüşü (aşağıda §8) |
| 8 | Harici test kullanıcıları (Apple beta incelemesi) | 3. aşama; inceleme için giriş yolu |

- 2. aşamanın çıktısı yalnızca dahili test kullanıcılarına gider (App Store
  Connect'e eklenen kişiler; inceleme beklemez).
- Bir aşama gelene kadar iOS, önceki ADR'lerde yazılı davranışı gösterir:
  push kapalı (ADR-0019), bütünlük sağlayıcısı yok ve istekler kanıtsız
  (ADR-0023 §1), birebir satırında "bu cihazda henüz açık değil" (ADR-0020).
  Bu aşamalar için yeni bir geçici davranış tanımlanmaz.
- Apple, üçüncü taraf girişi sunan uygulamadan eşdeğer bir giriş seçeneği
  ister; bu yüzden harici teste ve mağazaya Apple ile giriş olmadan
  çıkılmaz (8. aşama 3.'ye bağlı).

### 2. Derleme ve imza (GitHub Actions, Mac yok)

- **Runner:** GitHub'ın macOS runner'ı (ADR-0009). İmaj etiketi ve Xcode
  sürümü iş akışında tek yerde sabittir; `latest` kullanılmaz. Flutter
  sürümü `ci.yml` ile aynıdır.
- **CI (`ci.yml`):** yeni `ios` işi her PR'da imzasız simülatör derlemesi
  yapar ve `ios/RunnerTests` altındaki Swift testlerini simülatörde
  çalıştırır. Secret görmez. Kararlı hale gelince `dev` ve `main` kural
  setlerinde zorunlu kontrol olur (platform sahibinin GitHub ayarı).
- **Yayın (`testflight.yml`):** Play ile aynı model (ADR-0029): yalnızca
  `main`'e birleşmede (ve elle, yalnızca `main`'den) çalışır. İşler
  `play-dahili.yml`'deki ayrımı izler:
  1. `surum`: sürüm adı ve derleme numarası; secret yok.
  2. `arsiv`: imzasız `.xcarchive` üretir. Üçüncü taraf kodu (Flutter,
     eklentiler, bağımlılık yöneticisi) burada çalışır; API anahtarını
     görmez.
  3. `yukle`: yalnızca arşivi indirir, App Store Connect API anahtarıyla
     imzalar (Xcode'un otomatik, bulutta yönetilen dağıtım imzası) ve
     TestFlight'a yükler. Anahtar yalnızca bu iştedir.
- **Doğrulanacak varsayım:** imzasız arşivden dışa aktarımda entitlement'ların
  (push, Associated Domains, App Attest) imzaya doğru taşındığı 2. aşamanın
  ilk işinde, yüklenen derlemenin entitlement'ları okunarak doğrulanır.
  Taşınmıyorsa imza `arsiv` işine alınır, anahtar o işe verilir ve bu ADR'ye
  not düşülür; sessizce değiştirilmez.
- **Araçlar:** yalnızca Xcode'un kendi araçları (`xcodebuild`, `xcrun`).
  fastlane ve üçüncü taraf yükleme Action'ı kullanılmaz (ADR-0009'daki
  Codemagic gerekçesiyle aynı: ek tedarik zinciri halkası).
- **Kimlik:** Apple'da Play'deki anahtarsız kimliğin (Workload Identity
  Federation) karşılığı yoktur; App Store Connect API anahtarı uzun ömürlü
  bir secret'tır. Hasarı sınırlamak için: anahtar ekip anahtarıdır ve rolü
  yüklemeye yeten en düşük roldür (App Manager; daha düşüğü yetiyorsa 2.
  aşamada düşürülür); yalnızca `testflight` GitHub ortamındadır ve ortam
  yalnızca `main` dalına açıktır; anahtarı gören iş üçüncü taraf kodu
  çalıştırmaz; yenileme adımları `docs/runbooks/` altına yazılır.
  Secret adları: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`.
- **Public değerler repoda:** Team ID (proje dosyasında),
  `GoogleService-Info.plist` (`google-services.json` gibi commit edilir),
  iOS OAuth istemci kimliği.
- **Sürüm:** `CFBundleShortVersionString` = `pubspec.yaml`'daki `X.Y.Z`;
  `CFBundleVersion` = Android `versionCode` ile aynı sayı (ADR-0029 §4:
  `main`'in birinci ebeveyn commit sayısı + 1000). İki mağazada aynı commit
  aynı numarayı taşır.
- **Etiket:** `vX.Y.Z` etiketini atan iş Play iş akışında kalır. TestFlight
  yüklemesi düşerse etiket yine atılır; iOS yüklemesi `main`'den elle
  yeniden çalıştırılır.
- **Test notu:** TestFlight'taki "Neyi test etmeli" metni Play ile aynı
  dosyadan gelir (`play/surum-notu.tr-TR.txt`).
- **Bağımlılık kilidi:** iOS bağımlılık yöneticisinin kilit dosyası commit
  edilir (kesin kural 8).

### 3. Semboller

- Dart karartması yoktur (platform sahibi, 2026-11-24): repo public olduğu
  için gizlilik kazandırmaz, çökme kayıtlarını okumayı zorlaştırır.
- iOS: dSYM dosyaları yüklemeyle birlikte App Store Connect'e gider
  (TestFlight çökme kayıtları okunur olsun diye) ve ayrıca iş akışı
  artefaktı olarak saklanır.
- Android: sürüm `.aab`'ında yerel hata ayıklama sembollerinin bulunduğu
  doğrulanır; yoksa `release` yapılandırmasına `debugSymbolLevel` eklenir.
  R8 eşleme dosyası `.aab`'ın içindedir; ayrı yükleme adımı gerekmez. Bu,
  ayrı ve küçük bir Android işidir.

### 4. Cihazsız doğrulama

- Simülatörde doğrulanabilen her şey CI'dadır: derleme, Dart testleri (her
  PR'da zaten), Swift köprülerinin simülatörde çalışabilen testleri.
- Simülatörde tam çalışmayanlar (App Attest, push, kamera) yalnızca
  TestFlight'taki gerçek cihazda doğrulanır. Her aşamanın iş kaydı, dahili
  test kullanıcısının izleyeceği kısa bir kontrol listesiyle gelir; liste
  Notion'daki dahili test sayfasına eklenir.
- Hata ayıklama kaynağı: TestFlight çökme kayıtları ve test kullanıcısının
  ekran görüntüsü. Bu amaçla uygulamaya hata raporlama ya da analitik
  paketi eklenmez (ADR-0019: Analytics/Crashlytics yok).
- Dahili test için en az bir gerçek iPhone kullanıcısı gerekir; 2. aşama
  onsuz "tamam" sayılmaz.

### 5. Giriş

- **Google (2. aşama):** `google_sign_in` iOS'ta da kullanılır. Google
  Cloud'da iOS OAuth istemcisi açılır; ters istemci kimliği URL şeması
  `Info.plist`'e girer. Sunucu istemci kimliği Android ile aynıdır.
- **Sunucu, Google için değişmez:** identity ID token'da yalnızca `iss`,
  `aud`, `exp` ve `nonce`'u denetler (Tayfam-Api `internal/identity/app/oidc`,
  2026-11-24'te okundu); iOS'tan gelen token'ın `aud`'u aynı sunucu
  istemcisidir, `azp` denetlenmez.
- **Apple (3. aşama):** önce sunucu. Sözleşmede `provider` bugün yalnızca
  `google`'dır; veritabanı ve proto `apple`'a yer açmıştır, doğrulayıcı
  yoktur (Tayfam-Api ADR-0004). Tayfam-Api'de iş kaydı açılır:
  giriş ucunda Apple kimlik token'ı (nonce zorunlu, Google ile aynı kural),
  ad bilgisinin yalnızca ilk yetkilendirmede gelmesi, e-postanın gizlenmiş
  olabilmesi, hesap silmede Apple token'ının iptali ve hesap silme öncesi
  yeniden girişin Apple karşılığı. Sözleşme birleşmeden istemci kodu
  yazılmaz (kesin kural 1).
- İstemcide Apple girişi, Apple'ın kendi çerçevesi (AuthenticationServices)
  üzerinde ince bir Swift köprüsüyle yapılır; yeni Flutter paketi eklenmez.
  Düğme ADR-0012'deki yerindedir. `TAYFAM_APPLE_GIRIS` derleme bayrağı
  2026-11-26'da kaldırıldı (platform sahibi kararı): sunucu Apple ile girişi
  istemciden önce açtığı için düğme iOS'ta her zaman görünür.
- **Uygulama notu (2026-11-24, Tayfam-Api ADR-0045 ile):**
  - Düğme Apple'ın yerel düğmesidir (`ASAuthorizationAppleIDButton`,
    platform görünümü): açık temada siyah, koyu temada beyaz, Google
    düğmesinin üstünde ve aynı yükseklikte.
  - **Sağlayıcı cihazda hatırlanır (platform sahibi kararı, 2026-11-24).**
    Hesap silme ve veri indirme öncesindeki yeniden giriş, girişte
    kullanılan sağlayıcıyla yapılmak zorundadır. Kullanıcıya sormamak için
    son girişin sağlayıcısı güvenli depoda tek bir bayrak olarak tutulur
    (`appleIleGirildi`; kimlik, e-posta ya da token değil) ve her girişte
    yeniden yazılır. Kayıt yoksa ya da okunamıyorsa Google açılır; yanlış
    hesap seçilirse akış "farklı hesap" hatasıyla durur, hiçbir şey
    silinmez. Sunucudan sağlayıcıyı sormak sözleşmeye yeni alan gerektirirdi.
  - Hesap silmede Apple'ın yeniden girişte verdiği tek kullanımlık
    yetkilendirme kodu yalnızca `DELETE /v1/me` gövdesinde gider; saklanmaz,
    loglanmaz. Sunucu onunla Apple'daki yetkiyi iptal eder.
  - Apple ile kayıt olan kullanıcı şimdilik Android'de giremez (açık soru
    2'nin cevabı; hesap bağlama sonraya kaldı).

### 6. Push, linkler, izinler

- **Push (ADR-0019'a not):** APNs kimlik doğrulama anahtarı Firebase'e
  platform sahibi tarafından yüklenir; repoya ve GitHub'a girmez. Bildirim
  içeriksiz kalır (kesin kural 7); çeviri anahtarlarının iOS'ta nasıl metne
  döndüğü push işinde ADR-0019'a notla yazılır.
- **Universal Links (ADR-0013'e not):** `applinks:tayfam.app`;
  `site/.well-known/apple-app-site-association` yalnızca `/davet`, `/r/*`
  ve `/q` yollarını içerir. Kesin kural 9 aynen geçerlidir.
- **İzin metinleri:** `Info.plist`'e konum açıklaması eklenir (yalnızca
  varış bildiriminde, kullanım sırasında). Uygulama yalnızca Android'de
  istediği izinlerin iOS karşılıklarını ister; yenisi eklenmez.
- **Gizlilik bildirimi:** Apple'ın istediği gizlilik bildirimi dosyası ve
  App Store "Uygulama Gizliliği" formu, Play veri güvenliği formuyla aynı
  kaynaktan (Notion, Mağaza Sayfası) doldurulur.
- **Diğer kanallar:** `tayfam/bildirim` ve `tayfam/kronometre` için iOS
  karşılığı yazılır ya da Dart tarafı kanal yokken sessizce çalışır; hangisi
  olduğu ilgili işte belirtilir. Kanal yokluğu çökme sebebi olamaz.

### 7. App Attest

- ADR-0023'ün iOS karşılığı; aynı `tayfam/butunluk` kanalı, Swift köprüsü.
  Bağlama değeri Dart'ta hesaplanmaya devam eder (ADR-0023 §1).
- Sunucu tarafı ve sözleşme Tayfam-Api #195'te; Android'deki gibi `report`
  kipinde başlar.
- Simülatörde sağlayıcı yoktur (`OlmayanButunlukSaglayici`).

### 8. Signal köprüsü

- ADR-0010 güncellemesindeki karar geçerlidir: aynı `SignalMotoru` arayüzü,
  `tayfam/e2e/signal` kanalı, Signal'in resmi Swift paketi
  (`LibSignalClient`) üzerinde ince bir Swift köprüsü. Anahtarlar Keychain'de
  (ADR-0020, Depo).
- Paketin nasıl alınacağı (sabit sürüm, sağlama toplamı, önceden derlenmiş
  çekirdek) köprü işinde ADR-0010'a notla yazılır.
- **Ön koşul:** AGPL-3.0 lisanslı kütüphanenin App Store dağıtımıyla uyumu
  hukukçu listesinde açık bir maddedir (Notion, Açık Kararlar). TestFlight
  da aynı dağıtım kanalıdır. Bu aşama, platform sahibi o maddeyi kapatana
  ya da riski bilerek kabul edene kadar başlamaz.

## Gerekçe

- Aşamalı gidiş, cihaz olmadan çalışmanın maliyetini düşürür: her
  TestFlight derlemesinde tek bir yeni yetenek denenir, hata o yeteneğe
  bağlanabilir.
- İmzasız arşiv ile imzalama işinin ayrılması Play iş akışındaki ilkeyi
  korur: yayın kimliğini taşıyan iş üçüncü taraf kodu çalıştırmaz.
- Yalnızca Apple araçlarının ve kendi ince köprülerimizin kullanılması,
  bağımlılık ve tedarik zinciri kurallarıyla (kesin kural 8) tutarlıdır.
- Derleme numarasının iki mağazada aynı olması, bir hata bildiriminde
  hangi commit'in konuşulduğunu tek sayıyla belirler.

## Sonuçlar

- Yeni hassas alanlar: `.github/workflows/testflight.yml`, `ci.yml`'deki
  `ios` işi, `ios/Runner/*.entitlements`, `ios/Runner/Info.plist`,
  `site/.well-known/apple-app-site-association`. Hepsi CODEOWNERS
  kapsamındadır; iş akışı PR'larını yalnızca platform sahibi birleştirir.
- CLAUDE.md'deki "İlk hedef platform Android" cümlesi ve "Komutlar" bölümü
  2. aşamayla güncellenir (platform sahibinin birleştireceği ayrı PR).
- Platform sahibinin işleri (tek liste, 2. aşama başlamadan):
  1. Developer portalında uygulama kimliğinde Sign in with Apple, Push
     Notifications, App Attest ve Associated Domains yeteneklerini açmak.
  2. App Store Connect API ekip anahtarı üretip `testflight` ortamına üç
     secret olarak girmek; ortamı `main` dalıyla sınırlamak.
  3. Team ID'yi ve uygulamanın App Store Connect kimliğini iletmek
     (public değerler).
  4. Google Cloud'da iOS OAuth istemcisi açmak.
  5. En az bir dahili test kullanıcısını App Store Connect'e eklemek.
  Sonraki aşamalarda: APNs anahtarı ve Firebase iOS uygulaması (4. aşama),
  Sign in with Apple sunucu anahtarı (3. aşama, Tayfam-Api runbook'u).
- macOS runner dakikaları public repoda ücretsizdir; her PR'a bir iOS
  derlemesi eklendiği için CI süresi uzar.
- İlk gerçek cihaz denemesi test kullanıcısındadır; platform sahibi kendi
  cihazında göremez. Bu, kabul edilmiş bir sınırdır.

## Açık sorular (platform sahibine)

1. **iPad:** uygulama yalnızca iPhone için mi yayınlanır? Öneri: yalnızca
   iPhone. iPad desteği ayrı ekran görüntüleri ve geniş düzen denetimi
   ister.
2. **Apple ile giriş yapan kullanıcı Android'de:** Apple ile kayıt olan
   biri Android'e geçerse nasıl girer? Tayfam-Api ADR-0004 yönü çizmiş:
   farklı sağlayıcı hesapları otomatik birleştirilmez, hesaba ikinci
   sağlayıcı bağlama oturum açmış kullanıcının açık işlemi olacak; ama
   bağlama henüz yazılmadı. Soru: hesap bağlama Apple girişiyle birlikte mi
   gelsin, yoksa ilk sürümde Apple ile kayıt olan kullanıcı Android'de
   giremesin mi (ekranda açıkça söylenerek)? 3. aşamadan önce verilmelidir.
3. **Signal ve AGPL:** 7. aşama hukukçu görüşünü mü bekler, yoksa risk
   kabul edilip dahili testte açılır mı?
4. **İhracat uyumu beyanı:** App Store Connect her derlemede şifreleme
   kullanımını sorar. Cevap platform sahibinin beyanıdır; hukukçu listesine
   eklenmesi önerilir.
5. **Apple incelemesi için giriş:** harici test ve mağaza incelemesi bir
   test hesabı ister. Sıra Notion'da yazılı (Mağaza Sayfası, Yapılacaklar:
   pilot öncesi sıfırlama → demo verisi → inceleme Google hesabı →
   bilgilerin Play Console ve App Store Connect'e girilmesi); iOS için ayrı
   bir karar gerekmiyor, yalnızca 8. aşamadan önce yapılmış olmalı.

## Değerlendirilen alternatifler

- **Codemagic ya da başka bir barındırılmış derleme servisi:** ADR-0009'da
  reddedildi; gerekçe değişmedi.
- **fastlane (match, pilot):** imza ve yüklemeyi kolaylaştırır; ama Ruby
  bağımlılık ağacı ve sertifikaları tutan ayrı bir depo getirir.
- **Sertifika ve profili secret olarak saklamak (`.p12`):** Mac olmadan
  üretmesi zahmetli, yıllık yenileme elle; API anahtarıyla otomatik imza
  tek secret kümesiyle aynı işi görür.
- **Apple ile giriş için hazır Flutter paketi:** daha az kod; ama kimlik
  akışına üçüncü kişi bir paket girer. Köprü birkaç çağrıdan ibaret olduğu
  için kendi köprümüz seçildi.
- **iOS'u tek büyük PR'la çıkarmak:** v3'te seçilen tek seferde geçişin
  (ADR-0033) aksine, burada cihazsız çalışıldığı için hata ayıklaması çok
  zorlaşırdı.
- **İkinci el bir iPhone ya da kiralık bulut Mac:** doğrulamayı
  hızlandırırdı; platform sahibi 2026-11-24'te cihazsız ilerlemeyi seçti.
  Sonradan eklenirse bu ADR değişmez, yalnızca §4 kolaylaşır.
