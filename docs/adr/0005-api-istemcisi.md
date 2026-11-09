# ADR-0005: API istemcisi, kod üretimi, token yenileme ve hata eşlemesi

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md), [ADR-0002](0002-modul-yapisi.md); Tayfam-Api ADR-0003, ADR-0004, ADR-0011; Tayfam-Api issue #114

## Bağlam

İstemcinin konuştuğu tek sözleşme Tayfam-Api'deki
`api/openapi/gateway.yaml`'dır: OpenAPI 3.1, 144 işlem, `x-problem-types`
altında 95 hata kodu. Sözleşme önce değişir (CLAUDE.md kesin kural 1).
Token kuralları: erişim token'ı 15 dakika; yenileme token'ı her kullanımda
değişir, kullanılmış token tekrar gelirse oturum tamamen kapanır; aynı anda
gelen meşru çift yenilemeler için birkaç saniyelik tolerans vardır ve bu
durumda `refresh-conflict` döner. Mobil token'ları gövdede, web HttpOnly
çerezde taşır.

## Karar

### 1. Repoda kendi küçük üreticimiz

- `tool/openapi_gen/` altında Dart ile yazılmış bir betik, Tayfam-Api'nin
  belirli bir commit'indeki `gateway.yaml`'ı okur ve `lib/core/api/gen/`
  altına şunları üretir:
  - Şemalar için değişmez model sınıfları (`fromJson` / `toJson`,
    `==`/`hashCode`), enum'lar ve `oneOf`/`anyOf` için mühürlü (sealed)
    sınıflar.
  - Etiket (tag) başına bir uç sınıfı; her `operationId` bir metod.
  - `x-problem-types`'tan `ProblemType` enum'u (bilinmeyen kod için
    `unknown` değeri).
- Üretilen kod commit edilir ve elle düzenlenmez. Sözleşmenin hangi
  commit'ten alındığı `lib/core/api/gen/SOURCE` dosyasında yazılıdır.
- CI: üretici yeniden çalıştırıldığında fark kalmamalıdır; sözleşmenin
  kullanılan commit'i değişince üretim aynı PR'da yapılır.
- Üretici yalnızca sözleşmenin kullandığı OpenAPI özelliklerini destekler;
  desteklemediği bir yapıyla karşılaşırsa sessizce geçmez, hata verir.
- Çalışma anında `build_runner`, `freezed`, `json_serializable` kullanılmaz
  (ADR-0001 kural 2 ile uyumlu).
- Elle yazılan kod üretilen modelleri özelliğin `data/` katmanında kullanır;
  arayüze ham API modeli değil, gerekirse özelliğin kendi modeli taşınır.

### 2. HTTP katmanı: tek `ApiClient`

- Paket: Dart ekibinin `http` paketi. Web'de `BrowserClient` ve
  `withCredentials: true` (çerezlerin gitmesi için).
- Bütün istekler `core/api/`'deki tek `ApiClient`'tan geçer; özellikler
  kendi HTTP istemcisini kurmaz. `ApiClient`:
  - Her istekte `X-Tayfam-Client: android | ios | web` ve
    `X-Tayfam-Client-Version` başlıklarını ekler (sürüm başlığı issue #114
    ile sözleşmeye girince).
  - Mobilde `Authorization: Bearer <erişim token'ı>` ekler; web'de eklemez.
  - Oluşturma isteklerinde `client_request_id` (UUIDv4, `Random.secure()`)
    üretir; tekrar gönderimde aynı id kullanılır (çevrimdışı kuyruk ayrı ADR).
  - Yanıt `application/problem+json` ise `ApiProblem` (tür, durum kodu,
    ayrıntı alanları) fırlatır; `title` ve `detail` hiçbir yerde
    gösterilmez ve loglanmaz.
  - Zaman aşımı ve ağ hatası ayrı türlerdir (`ApiOffline`, `ApiTimeout`).
  - Log'a yalnızca yöntem, yol şablonu (`/v1/tayfas/{tayfa_id}`, gerçek id
    değil), durum kodu ve problem türü yazar (CLAUDE.md kesin kural 3).
- Tabanlı adres derleme zamanı değişkeniyle verilir (`--dart-define`):
  dev `https://api-dev.tayfam.app`. Yalnızca `https` kabul edilir.

### 3. Token saklama ve yenileme

- **Mobil:** erişim ve yenileme token'ı `flutter_secure_storage` ile
  (Android Keystore, iOS Keychain; iOS'ta `first_unlock_this_device`,
  yedeğe gitmez). Bellekte yalnızca `SessionStore` tutar; başka hiçbir
  provider token taşımaz.
- **Web:** hiçbir token saklanmaz; çerezler HttpOnly'dir. İstemci yalnızca
  `access_expires_at` ve `refresh_expires_at` zamanlarını bilir.
- **Yenileme `SessionStore`'da, tek uçuşta:**
  - Erişim token'ının bitmesine 60 saniye kala istek öncesi yenilenir.
  - Bir istek `unauthenticated` alırsa bir kez yenileme denenir ve istek
    bir kez tekrarlanır; ikinci `unauthenticated` oturumu kapatır.
  - Aynı anda gelen istekler süren yenilemeyi bekler (tek `Future`);
    ikinci bir yenileme isteği gönderilmez.
  - `refresh-conflict`: başka bir sekme veya istek aynı anda yenilemiş
    demektir; oturum kapanmaz. 1 saniye beklenir, mobilde depodaki güncel
    token, web'de güncel çerez ile istek bir kez tekrarlanır.
  - `invalid-refresh` veya süresi geçmiş yenileme token'ı: oturum kapanır,
    tüm kullanıcı durumu sıfırlanır (ADR-0001 kural 8), giriş ekranına dönülür.
- Çıkışta `POST /v1/auth/sign-out` denenir; başarısız olsa bile yerel
  token'lar silinir.
- `consent_required` ve `registration_pending` yanıtları yönlendiriciye
  iletilir (ADR-0003).

### 4. Hata eşlemesi

- `ProblemType` → çeviri anahtarı eşlemesi `core/api/problem_messages.dart`
  içinde, `switch` ile ve `default` dalı olmadan yazılır; böylece
  sözleşmeye yeni bir kod eklenip üretici çalışınca derleyici eksik dalı
  gösterir.
- Bilinmeyen kod (`unknown`) genel hata metnine düşer.
- Her kodun çeviri anahtarı çeviri dosyasında vardır; eksikse test kırılır.
- Bazı kodlar ekran değil akış tetikler ve `ApiClient`'ta ya da
  yönlendiricide ele alınır: `unauthenticated`, `invalid-refresh`,
  `refresh-conflict`, `consent-outdated`, `reauthentication-required`,
  `client-outdated` (issue #114), `module-disabled`, `rate-limited`.

## Gerekçe

- Kendi üreticimiz, API'deki "sözleşme önce, üretilen kod commit edilir,
  CI güncelliği denetler" düzeninin birebir karşılığı; 144 işlemlik
  sözleşmeyle elle yazılan kodun zamanla ayrışmasını önlüyor.
- Hazır üreticiler (openapi-generator, swagger_parser) ya OpenAPI 3.1'i
  eksik destekliyor ya da `build_runner` ve çok sayıda paket getiriyor;
  tedarik zinciri büyüyor (Tayfam-Api ADR-0011).
- `http` paketi `dio`'dan küçük; ihtiyaç duyulan ara katman (başlıklar,
  yenileme, problem ayrıştırma) zaten tek sınıfta yazılacak.
- `refresh-conflict` için ayrı davranış, birden çok sekme açık web
  kullanıcısının sebepsiz yere çıkış yapmasını önlüyor.

## Sonuçlar

- İlk iş paketlerinden biri üreticidir; özellikler uçları üretilen
  sınıflardan çağırır.
- Bağımlılıklar: `http`, `flutter_secure_storage`, `yaml` (yalnızca
  üreticide, geliştirme bağımlılığı).
- Testler: üreticinin örnek şemalarla birim testleri; `SessionStore`
  için eşzamanlı istek, `refresh-conflict`, `invalid-refresh` ve oturum
  kapanışında durum sıfırlama testleri; her `ProblemType` için çeviri
  anahtarı testi.
- `ApiClient` ve `SessionStore` hassas alandır; CODEOWNERS'a modül
  yapısı netleşince eklenir.

## Değerlendirilen alternatifler

- **Elle yazılmış istemci:** bağımlılık yok, ama sözleşmeyle ayrışma ve
  denetimsizlik.
- **openapi-generator (dart-dio):** Java aracı, 3.1 desteği eksik,
  `built_value` bağımlılığı.
- **swagger_parser + freezed/json_serializable:** hızlı başlangıç; ama
  `build_runner` ve kod üretim zinciri.
- **dio:** hazır ara katmanlar; daha büyük bağımlılık ve bizim yazacağımız
  ara katmanı zaten karşılamıyor.
