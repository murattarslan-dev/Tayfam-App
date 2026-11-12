# ADR-0012: Açılış, giriş, kayıt ve yeniden onay akışı

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-10
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0003](0003-gezinme-iskeleti.md), [ADR-0004](0004-tema-ve-bilesen-dili.md), [ADR-0005](0005-api-istemcisi.md), [ADR-0008](0008-ceviri-ve-yerel-ayar.md), [ADR-0009](0009-test-ci-ve-ios.md); Tayfam-Api ADR-0004, ADR-0012, ADR-0016, ADR-0017; Notion: Proje Planı §4 Kullanıcı Akışı, Özellik Haritası "Hesap ve kimlik", KVKK Aydınlatma Metni

## Bağlam

Sunucu tarafı hazır: `GET /v1/client-config` (en düşük sürüm),
`POST /v1/auth/sign-in` (Google ID token + nonce), `registration_pending`
ise `GET /v1/registration/requirements` → `POST /v1/registration`,
`consent_required` ise `GET`/`POST /v1/me/consents`. Kayıtta doğum tarihi
16 yaşın altındaysa hesap **kalıcı** kapanır (`age-blocked`). Sözleşme
aydınlatma metni ve kullanım koşullarının yalnızca **sürümünü** verir;
metinlerin kendisi hiçbir yerde yayımlanmış değil. Apple ile giriş sonraya
bırakıldı (Proje Planı §11). ApiClient ve SessionStore (#7) ile gezinme
iskeleti (#14) main'de; oturum durumu henüz SessionStore'a bağlı değil.

## Karar

### 1. Açılış sırası

1. `GET /v1/client-config`. Uygulamanın sürümü platformun
   `min_supported_version`'ının altındaysa **"Güncelleme gerekli"** ekranı
   gösterilir (mağazaya bağlantı); başka bir şey yapılamaz. Denetim
   oturum okumasıyla paralel çalışır, açılışı beklemez; uç ulaşılamazsa
   açılış engellenmez; herhangi bir istek `client-outdated`
   (426) dönerse aynı ekrana geçilir.
2. SessionStore'daki kayıt okunur ve `oturumDurumuProvider` ondan beslenir:
   kayıt yok → giriş; `registration_pending` → kayıt; `consent_required` →
   yeniden onay; aksi halde açık (ADR-0003'teki yönlendirme koruması).
3. Uygulama sürümü yeni bir paketle değil, derleme sırasında
   `--dart-define=TAYFAM_SURUM=<pubspec sürümü>` ile verilir; CI bunu
   `pubspec.yaml`'dan okur. Aynı değer `X-Tayfam-Client-Version:
   android/<sürüm>` başlığında gönderilir (Tayfam-Api ADR-0016).

### 2. Giriş

- Tek ekran, `MarkaYuzeyi` (mor) üzerinde logo, slogan ("Birlikte yapınca
  güzel.") ve **"Google ile devam et"** düğmesi. Düğme Google'ın oturum açma
  marka kurallarına uyar (resmi "G" işareti; renk ve yazı kurallara göre).
- Paket: **`google_sign_in`** (yayıncı flutter.dev; Android ve iOS).
  `serverClientId` olarak API'nin kabul ettiği web OAuth istemci kimliği
  verilir (public bir değerdir, kesin kural 6); ID token'ın `aud`'u budur.
- **Nonce:** `Random.secure()` ile 32 bayt, base64url. `google_sign_in`
  nonce'u yalnızca `initialize` sırasında aldığı için uygulama süreci başına
  bir nonce üretilir; nonce loglanmaz, diske yazılmaz. Sunucunun ürettiği
  tek kullanımlık nonce Tayfam-Api ADR-0011 madde 15'te açık; gelince
  istemci ona geçer.
- ID token yalnızca `POST /v1/auth/sign-in` gövdesine gider; saklanmaz,
  loglanmaz. Google hesabının görünen adı yalnızca kayıt formunu önceden
  doldurmak için bellekte tutulur.
- Hatalar `ProblemType`'a göre: `account-sanctioned` → hesap kısıtlandı
  ekranı (tekrar deneme yok); `rate-limited` → bekle ve tekrar dene;
  bağlantı yok → "Bağlantı yok". Kullanıcı Google penceresini kapatırsa
  hata gösterilmez.

### 3. Kayıt

- Form: **ad** (Google adıyla dolu, düzenlenebilir, 1–40 karakter; değişmediyse
  gönderilmez), **doğum tarihi** (tarih seçici, `tr_TR`, ön seçili tarih yok,
  bugünden ileri seçilemez), **aydınlatma metni** ve **kullanım koşulları**
  için ayrı onay kutuları, isteğe bağlı **referans kodu** (elle; Play mağaza
  referansı sonraki iş).
- **Doğum tarihi onayı:** gönderimden önce pencere: "Doğum tarihin 12 Mart
  2009. Doğru mu?" — "Düzelt" / "Doğru, devam et". Pencere yaş sınırını ya da
  sonucunu söylemez; yalnızca girilen tarihi teyit ettirir.
- Başarılı (204) → SessionStore `yenile()` → oturum açık → karşılama /
  tayfa ana sayfası. `age-blocked` → oturum sunucuda kapanmıştır; yerel
  kayıt silinir ve sade bir bilgi ekranı gösterilir (yeniden deneme yolu
  yok). `consent-outdated` → gereksinimler yeniden okunur.
  `already-registered` → kayıt zaten tamamlanmıştır; SessionStore
  `yenile()` ile güncel bayraklar alınır (gereksinimleri yeniden okumak
  kullanıcıyı döngüde bırakırdı; 2026-11-10, PR #26).

### 4. Hukuki metinler

- Aydınlatma metni ve kullanım koşulları **tayfam.app'te sürümlü
  sayfalarda** yayımlanır: `https://tayfam.app/yasal/aydinlatma-metni/<sürüm>`
  ve `https://tayfam.app/yasal/kullanim-kosullari/<sürüm>`. Uygulama sürümü
  sunucudan alır, `^[A-Za-z0-9._-]{1,32}$` ile doğrular ve sayfayı sistem
  tarayıcısında açar (paket: **`url_launcher`**, yayıncı flutter.dev). Metin
  güncellenince uygulama güncellemesi gerekmez.
- Sayfalar yayımlanmadan pilota çıkılmaz. Kullanım koşulları metni henüz
  yazılmadı (Proje Planı §11).

### 5. Yeniden onay

- `consent_required` → tek ekran: değişen metinlerin bağlantıları, tek onay
  kutusu, `POST /v1/me/consents` gösterilen sürümlerle. `consent-outdated`
  (409) → sürümler yeniden okunur. Onaydan sonra `yenile()`.

### 6. Uygulama kimliği

- Android `applicationId` ve iOS bundle kimliği **`com.murattarslan.tayfam`**
  (platform sahibi, 2026-11-10). Proje iskeletindeki `app.tayfam` bu işle
  değişir. Geliştirme (dev'e bağlı) ve yayın (prod'a bağlı) sürümleri aynı
  kimliği kullanır; bir telefonda aynı anda yalnızca biri kuruludur.
  Kimlik Play'de yayımlandıktan sonra değiştirilemez.

### 7. Android geliştirme imzası

- Google girişi Android'de uygulamanın imza parmak izine bağlıdır. CI'daki
  geliştirme APK'sı bir kez üretilen **sabit geliştirme anahtarıyla**
  imzalanır; anahtar ve parolaları yalnızca GitHub secret'ıdır, repoya
  girmez (kesin kural 6). Secret yoksa (fork PR'ı) derleme varsayılan debug
  anahtarıyla sürer. Sürüm (mağaza) imzası ayrı iştir (#13).

## Gerekçe

- Kalıcı kapanan bir hesap için yanlış girilmiş tek bir tarih bedeli çok
  yüksek; teyit penceresi sınırı öğretmeden hatayı yakalar.
- Metinleri sitede sürümlü tutmak, sunucunun istediği sürümle kullanıcının
  gördüğü metnin aynı olmasını uygulama güncellemesine bağlamaz.
- Sürüm bilgisini derleme tanımıyla vermek `package_info_plus` gibi yeni
  bir bağımlılık getirmez.

## Sonuçlar

- Yeni paketler: `google_sign_in`, `url_launcher` (kesin kural 8; PR'da
  gerekçe). Bu ortamda pub.dev'e erişim yok; `pubspec.lock` CI'da üretilir.
- Platform sahibinin işleri (bir kez, tek listede): geliştirme imza
  anahtarı ve secret'ları, Google Cloud'da Android OAuth istemcisi
  (`com.murattarslan.tayfam` + geliştirme anahtarının SHA-1'i), tayfam.app'te iki sürümlü
  sayfa, Google oturum açma düğmesi varlıkları.
- iOS'ta giriş, Apple ile giriş ve iOS derlemesiyle birlikte gelir.
- Profil tamamlama formu ve hesap silmedeki yeniden giriş ayrı işlerdir.

## Değerlendirilen alternatifler

- **Metinler uygulamaya gömülü:** çevrimdışı okunur, ama sunucu sürümü
  değişince uygulama güncellemesi gerekir.
- **Doğrudan gönderim:** bir yazım hatası hesabı kalıcı kapatabilir.
- **Kendi bilgisayarında derleme:** CI'dan çıkan APK ile giriş denenemez.
- **Play Install Referrer:** referans kodunu otomatik doldurur, ama ek paket
  ve izin getirir; sonraya bırakıldı.

## Notlar

- **2026-11-10 (PR #26, platform sahibi onayladı):** `already-registered`
  durumunda `yenile()` çağrılır; sürüm denetimi oturum okumasıyla paralel
  çalışır (yukarıdaki metne işlendi). Uygulama kimliği değişikliği aynı
  PR'la geldi. Logo artık monogram + "tayfam" yazısı
  (`TayfamMonogram`, PR #34); logo yazısı sistem yazı ölçeğiyle büyümez,
  görsel sayılır ve dar alanda orantılı küçülür. Genel `ProblemType` → çeviri eşlemesi (ADR-0005 §4)
  ayrı iş; bu akış yalnızca kendi hata kodlarını eşler.
- **2026-11-12 (platform sahibi; PR #99, #101, #106):** Yukarıdaki notta
  geçen monogram (`TayfamMonogram`) yerini yeni logoya bıraktı:
  `TayfamLogo` (ADR-0004 Notlar 2026-11-12). Logo yazısı kuralları (sistem
  yazı ölçeğiyle büyümez, dar alanda orantılı küçülür) aynen geçerlidir.
  - **Açılış (§1):** açılış ekranı native açılış ekranının devamıdır
    (açık temada brand, koyu temada ink zemin; ortada logo, altta yazı);
    logo bir kez bloklarla kurulur, ekranda ilerleme göstergesi yoktur.
  - **Giriş (§2):** mor üst alan (alt köşeler 32), etkinlik türü çipleri
    ve slogan; altta başlık, açıklama, Google düğmesi (temaya göre
    Google'ın açık/koyu biçimi) ve hukuki metinlerin bağlantıları. Giriş
    öncesi metin sürümü bilinmediği için bağlantılar güncel sürüme
    yönlenen sabit adreslerdir: `https://tayfam.app/gizlilik` ve
    `https://tayfam.app/kullanim-kosullari` (ikincisi metin yayımlanınca
    sitenin `_redirects`'ine eklenir); onay §3–§4'teki gibi kayıtta,
    sürümlü sayfayla alınır.
  - **Davet:** bekleyen davet varsa giriş ekranı davet görünümündedir
    (ekran yalnızca "davet bekliyor mu" bilgisini alır, token gelmez).
    Davet önizlemesi oturum istediği için tayfa adı giriş öncesi
    gösterilmez.
  - **Apple ile giriş:** iOS'ta düğmenin yeri Google'ın üstündedir; iOS
    + `TAYFAM_APPLE_GIRIS` derleme bayrağı + Apple girişinin yerel düğmesi
    verilmeden gösterilmez (Apple girişi hâlâ ertelenmiş durumda).
- **2026-11-12 (#104, kayıt sihirbazı):** §3'teki form, kuralları
  değişmeden adım adım sihirbaza ("Tayfam'la tanışma") çevrildi: ad →
  doğum tarihi (teyit penceresi "Devam et"te) → isteğe bağlı referans kodu
  → iki onay kutusu; gönderim yalnızca son adımda tek istekle. Başarıda
  yönlendirici oturum açılınca bir kez `/tanisma-tamam` hoş geldin ekranına
  gider (bellekteki bayrak; bekleyen davet orada mevcut davet akışıyla,
  ADR-0018 §6, işlenir). `age-blocked` bilgi ekranı giriş ekranından
  ayrıldı (`/hesap-acilamadi`; oturum kapalıyken yalnızca o gösterilir,
  "Kapat" uygulamayı kapatır). Kodla katılım sayfasının görünümü yenilendi;
  mantık ADR-0014 §3'teki gibi.
