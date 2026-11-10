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
   gösterilir (mağazaya bağlantı); başka bir şey yapılamaz. Uç
   ulaşılamazsa açılış engellenmez; herhangi bir istek `client-outdated`
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
  yok). `consent-outdated` / `already-registered` → gereksinimler yeniden
  okunur.

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

### 6. Android geliştirme imzası

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
  (`app.tayfam` + geliştirme anahtarının SHA-1'i), tayfam.app'te iki sürümlü
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
