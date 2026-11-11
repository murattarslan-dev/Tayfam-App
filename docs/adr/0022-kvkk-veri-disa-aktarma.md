# ADR-0022: KVKK veri dışa aktarma (istemci)

- **Durum:** Önerildi
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0010](0010-signal-kutuphanesi.md), [ADR-0011](0011-yalnizca-mobil.md), [ADR-0018](0018-faz1-kalan-moduller.md) §2 (hesap silmedeki yeniden giriş); Tayfam-Api ADR-0021 ve `docs/data-export-format.md`; issue #79; Notion: KVKK Aydınlatma Metni md. 8 ("Verilerimi indir"), İstemci Geçiş Özeti (2026-11-11)

## Bağlam

Tayfam-Api ADR-0021, KVKK md. 11 kapsamındaki veri dışa aktarmayı
sunucuda kurdu: kullanıcı 30 günde bir talep açar, sunucu verisini kendi
token'ıyla toplar, zip'ler, **talep başına bir anahtarla AES-256-GCM** ile
mühürler ve R2'ye koyar. Dosya 7 gün indirilebilir; indirme linki
(5 dakika) ve 32 baytlık anahtar aynı yanıtta, yalnızca son 10 dakikada
Google ile giriş yapılmış oturuma verilir (`reauthentication-required`).
Çözme **istemcide** yapılır. Birebir mesajlar dosyada yoktur (E2E).

İstemci için kararlaştırılması gerekenler: anahtarın ve dosyanın cihazda
nerede durduğu (ADR-0006 "içerik diske yazılmaz"), çözmenin hangi
kütüphaneyle yapıldığı (kesin kural 4), zip'in kullanıcıya nasıl verildiği,
artık dosyaların temizliği ve log.

## Karar

### 1. Akış

Profil → Gizlilik → **"Verilerimi indir"** (`/profil/verilerim`).

1. **Talep:** "Verilerimi hazırla" → token önce yenilenir
   (`SessionStore.yenile()`; toplama sunucuda kullanıcının token'ıyla hemen
   başlar) → `POST /v1/me/data-exports {client_request_id}`. Bağlantı ya da
   süre hatasında aynı `client_request_id` korunur (tekrar denemede aynı
   talep döner); sunucu yanıt verdiyse bir sonraki talep yeni kimlik alır.
2. **Liste ve durum:** `GET /v1/me/data-exports`. Talep kartında durum
   (`pending` Sırada, `processing` Hazırlanıyor, `ready` Hazır, `expired`
   Süresi doldu, `failed` Hazırlanamadı + `failure_reason` metni), talep,
   son indirme ve ilk indirme zamanları, hazırsa boyut. Süren talep varken
   liste 15 saniyede bir yoklanır (ekran açıkken); `next_request_at`
   gelecekteyse düğme yerine "Yeni bir talebi … tarihinden sonra
   açabilirsin" yazar. Bu yalnızca arayüz kolaylığıdır; karar sunucudadır
   (`data-export-limit`, `data-export-in-progress`; kesin kural 5).
3. **Hazır:** `data_export_ready` bildirimine (hedef `data_export`)
   dokununca bu ekran açılır (`bildirimAdresi`).
4. **İndirme:** "İndir" → `POST /v1/me/data-exports/{id}/download`.
   `reauthentication-required` gelirse hesap silmedeki yeniden giriş akışı
   (`YenidenGiris`: Google → `POST /v1/auth/sign-in` → aynı kullanıcı mı
   denetimi → oturum) çalışır ve istek **bir kez** tekrarlanır. Kullanıcı
   Google penceresini kapatırsa akış sessizce biter. Son 10 dakikada
   giriş yapılmışsa ikinci bir giriş istenmez.
5. **Dosya:** yanıttaki imzalı linkten **`ApiClient` dışında**, düz bir
   HTTP GET ile indirilir (`core/api/imzali_indirme.dart`): erişim token'ı,
   `X-Tayfam-*` başlıkları ya da çerez gönderilmez; yalnızca `https`,
   yönlendirme izlenmez, gövde akışla okunur ve `size_bytes`'ı aşan yanıt
   kesilir; boyut tam olarak `size_bytes` olmalı ve 16 MiB + 29 baytı
   geçmemelidir.
6. **Biçim doğrulama** (`docs/data-export-format.md`): `format` =
   `aes-256-gcm-v1`; anahtar 32 bayt; bayt 0 = `0x01`; nonce 12 bayt;
   şifreli metin + 16 bayt etiket; AAD = ASCII `tayfam/data-export/v1/` +
   talep UUID'sinin 16 baytı (ağ sırası). Uymayan dosya çözülmeye
   verilmez.
7. **Çözme:** Signal köprüsünün `aes256GcmCoz` çağrısıyla (libsignal
   `Aes256GcmDecryption`, ADR-0010'daki resmi paket; kendi kriptomuz yok).
   Etiket doğrulanamazsa içerik hiçbir zaman kullanılmaz ("Dosya
   doğrulanamadı"). Çözülen içeriğin zip imzası (`PK`) da denetlenir.
8. **Teslim:** zip **sistem paylaşım sayfasıyla** (`share_plus`, mevcut
   bağımlılık) verilir; kullanıcı "Dosyalara kaydet", Drive, e-posta vb.
   seçer. Dosya adı `tayfam-verilerim-YYYY-AA-GG.zip`'tir; kimlik ya da
   içerik taşımaz.

### 2. Bellek, disk ve ADR-0006'ya dar istisna

- **Anahtar ve link yalnızca bellektedir:** provider durumuna bile
  yazılmaz (eylemin yerel değişkenleridir); güvenli depoya, diske,
  önbelleğe yazılmaz. İş bitince (başarısız olsa da) anahtar ve çözülen
  içerik tamponları sıfırlanır.
- **Dosya bellekte indirilir ve bellekte çözülür.** Sunucu sınırı
  16 MiB olduğu için şifreli dosya, düz zip ve platform kanalının kopyası
  birlikte birkaç on MB'ı geçmez; geçici dosyada akışlı çözme
  gerekmez. Sınır büyürse (Tayfam-Api ADR-0021 §4 "geçici dosya") bu madde
  yeniden değerlendirilir.
- **İstisna:** paylaşım sayfası dosya yolu istediği için **yalnızca açık
  zip**, paylaşım süresince uygulamanın kendi geçici dizinindeki
  `tayfam_paylasim/` klasörüne yazılır (Android'de `code_cache`, iOS'ta
  sandbox `tmp`; başka uygulamalar okuyamaz) ve paylaşım biter bitmez
  (başarısız olsa da) silinir. Bu, ADR-0015 §3'teki `.ics` paylaşımıyla
  aynı kalıptır; kural betiğinde `diske-yazma` istisnası olarak işaretlidir.
- **Android'de `share_plus` kopyası:** eklenti paylaşılan dosyayı
  `cache/share_plus/` altına kopyalar ve bir sonraki paylaşımda siler.
  Alıcı uygulama kopyayı paylaşımdan sonra da okuyabildiği için kopya
  hemen silinmez.
- **Açılış temizliği:** uygulama paylaşım sırasında kapanırsa artık dosya
  kalabilir; her açılışta (`main`) `tayfam_paylasim/` ve Android'de
  `cache/share_plus/` silinir. Web'de bir şey yapılmaz.
- Kullanıcının seçtiği yere kaydedilen zip **açık** veridir; bu
  bilinçlidir (veri onundur, Tayfam-Api ADR-0021 §2). Ekran bunu söyler.

### 3. Log ve hata

- İmzalı link (sorgusundaki imza dahil), anahtar, dosya içeriği ve geçici
  dosya yolu log'a, hata mesajına, analitiğe yazılmaz (kesin kural 3).
  İstisnalar (`ImzaliIndirmeHatasi`, `DisaAktarmaHatasi`) yalnızca tür
  taşır; `http.ClientException` (adresi içerir) yakalanıp türe çevrilir.
  `DataExportDownload` üretilmiş modelinin `toString`'i yoktur.
- Problem türleri ortak eşlemeden çeviri metnine gider:
  `data-export-limit`, `data-export-in-progress`, `data-export-not-ready`,
  `data-export-expired`, `data-export-not-found`,
  `reauthentication-required`, `unavailable`. İstemci hataları: biçim,
  indirilemedi, doğrulanamadı, desteklenmiyor.

### 4. Platform ve bağımlılık

- **Web geliştirme derlemesi** (ADR-0011): liste ve talep çalışır; indirme
  yoktur ("bu sürümde indiremiyorsun").
- **Signal köprüsü:** arayüz (`SignalMotoru.aes256GcmCoz`) bu dala
  `feat/e2e-signal-kopru`'dan alındı. Köprünün motor provider'ı main'e
  girene kadar `disaAktarmaCozucuProvider` "desteklenmiyor" döner;
  provider gelince tek satırla `SignalDisaAktarmaCozucu`'ya bağlanır.
- Yeni paket yoktur (`http`, `share_plus` mevcut).

### 5. Kapsam dışı (sonraki adımlar)

- **Birebir mesajlar** sunucu dışa aktarımında yoktur; E2E arşivinden
  cihazda ayrı bir dışa aktarma adımıyla verilecektir (E2E işi, ayrı
  issue).
- **Kendi fotoğraflarım:** dosyaların kendisi zip'te yoktur
  (`core/uploads.json` listesi vardır); "Fotoğraflarımı da indir"
  (`POST /v1/media/urls`) fotoğraf işinden sonra ayrıca ele alınır.
- **Aydınlatma metni md. 8** güncellemesi mimari oturumundadır.

## Gerekçe

- Anahtar ile dosya aynı yanıtta gelir; ikisini de yalnızca bellekte
  tutmak, cihaz ele geçirilse bile indirme bilgisinin geride kalmamasını
  sağlar (5 dakikalık link de zaten kısa ömürlüdür).
- Çözme için ayrı bir kripto paketi eklemek yerine ADR-0010'da seçilen
  libsignal'in AES-256-GCM'i kullanılır: yeni bağımlılık yok, kural 4'e
  uygun.
- Sistem paylaşım sayfası "dosyaya kaydet"i de kapsar; depolama izni ya da
  dosya seçici paketi gerekmez (en az izin).
- Yeniden girişi önce denemeden zorlamamak, son 10 dakikada giriş yapmış
  kullanıcıya ikinci bir Google penceresi açmaz; sunucu kuralı aynen
  korunur.

## Sonuçlar

- Profil sekmesine "Gizlilik" bölümü eklenir.
- `YenidenGiris` hesap silmeden çıkarılıp iki akışta ortak kullanılır.
- `core/api/imzali_indirme.dart`: `ApiClient` dışındaki tek HTTP GET
  (yalnızca sunucunun verdiği imzalı linkler için).
- `core/cihaz/gecici_dosyalar.dart`: paylaşım dosyaları ve açılış
  temizliği.
- Testler: biçim ayrıştırma (bozuk başlık, kısa/uzun dosya, yanlış anahtar
  uzunluğu, yanlış AAD → çözülmez), akış (talep, token yenileme, aynı
  istek kimliğiyle tekrar, yeniden giriş, Google kapatılırsa, indirme
  hataları), geçici dosya temizliği, ekranlar açık/koyu + 2× yazı.

## Değerlendirilen alternatifler

- **Diske indirip akışlı çözme:** büyük dosyada bellek dostu; 16 MiB
  sınırında gereksiz, diske şifreli de olsa içerik yazar ve libsignal'in
  tek parça GCM API'siyle akış yoktur.
- **Platform API'si (Android `Cipher`, iOS CryptoKit) ile ayrı köprü:**
  mümkün, ama zaten paketlenen libsignal'in aynı işi yapan çağrısı varken
  ikinci bir yerel kod yolu demektir.
- **Dart kripto paketi (`cryptography`, `pointycastle`):** yeni bağımlılık
  ve kural 4'ün ruhuna aykırı.
- **Dosya seçici / "İndirilenler"e doğrudan yazma:** depolama izni ya da
  ek paket ister; paylaşım sayfası aynı işi izinsiz yapar.
- **Talepte de yeniden giriş:** sunucu istemiyor (Tayfam-Api ADR-0021 §6);
  istemci fazladan engel koymaz.
