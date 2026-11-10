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
durumda `refresh-conflict` döner. Uygulama yalnızca mobildir (ADR-0011);
token'lar gövdede gelir ve `Authorization` başlığıyla gönderilir.

## Karar

### 1. Repoda kendi küçük üreticimiz

- `tool/openapi_gen/` altında Dart ile yazılmış bir betik, Tayfam-Api'nin
  belirli bir commit'indeki `gateway.yaml`'ı okur ve `lib/core/api/gen/`
  altına şunları üretir:
  - Şemalar için değişmez model sınıfları (`fromJson` / `toJson`,
    `==`/`hashCode`), enum'lar ve `oneOf`/`anyOf` için mühürlü (sealed)
    sınıflar.
  - Yol kaynağına göre gruplanmış uç sınıfları (sözleşmede tag yok);
    her `operationId` bir metod.
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

- Paket: Dart ekibinin `http` paketi.
- Bütün istekler `core/api/`'deki tek `ApiClient`'tan geçer; özellikler
  kendi HTTP istemcisini kurmaz. `ApiClient`:
  - Her istekte `X-Tayfam-Client: android | ios` (web geliştirme
    derlemesinde Tayfam-Api'de kararlaştırılacak değer) ve
    `X-Tayfam-Client-Version` başlıklarını ekler (sürüm başlığı issue #114
    ile sözleşmeye girince).
  - `Authorization: Bearer <erişim token'ı>` ekler.
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
- **Web geliştirme derlemesi:** token yalnızca bellekte; sayfa yenilenince
  yeniden giriş (ADR-0011). Tarayıcı deposuna hiçbir şey yazılmaz.
- **Yenileme `SessionStore`'da, tek uçuşta:**
  - Erişim token'ının bitmesine 60 saniye kala istek öncesi yenilenir.
  - Bir istek `unauthenticated` alırsa bir kez yenileme denenir ve istek
    bir kez tekrarlanır; ikinci `unauthenticated` oturumu kapatır.
  - Aynı anda gelen istekler süren yenilemeyi bekler (tek `Future`);
    ikinci bir yenileme isteği gönderilmez.
  - `refresh-conflict`: başka bir istek aynı anda yenilemiş demektir;
    oturum kapanmaz. 1 saniye beklenir, depodaki güncel token ile istek bir
    kez tekrarlanır.
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
- `refresh-conflict` için ayrı davranış, arka planda ve ön planda aynı anda
  yenileme denendiğinde kullanıcının sebepsiz yere çıkış yapmasını önlüyor.

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

## Notlar

- **2026-11-10 (issue #5):** Sözleşmede hiç `tags` olmadığı için uç
  sınıfları etiket yerine yol kaynağına göre gruplanır: `/v1/<x>/…` ve
  `/v1/tayfas/{tayfa_id}/<x>/…` → `<X>Api` (`apis/<x>_api.dart`).
  Sözleşmede `oneOf`/`anyOf` da yok; mühürlü sınıf üretimi, bu yapılar
  sözleşmeye girdiğinde eklenir, o zamana kadar üretici bunlarda hata
  verir. `GET /v1/realtime` (WebSocket, ADR-0007) üretilmez.
- **2026-11-10 (issue #7, mimari oturumu):**
  1. **`client_request_id`:** sözleşmede istek modelinin zorunlu alanı
     olduğu için `ApiClient` koyamaz (§2'deki madde bununla düzelir).
     `core/api/istek_kimligi.dart`'taki tek yardımcı (`yeniIstekKimligi()`)
     `Random.secure()` ile UUID v4 üretir; id'yi işi oluşturan katman
     (application / çevrimdışı kuyruk) iş oluşturulurken bir kez üretir,
     aynı iş tekrar gönderilirken aynı id kullanılır.
  2. **Kimlik doğrulamasız uçlar yoldan tahmin edilmez.** Üretici her
     çağrıya işlemin geçerli `security`'sini (işleminki, yoksa kökteki)
     `ApiTransport.send(authenticated: …)` olarak yazar; `security: []`
     uçlarında `ApiClient` token eklemez ve yenileme denemez. Kökte de
     işlemde de `security` yoksa, isteğe bağlı kimlik doğrulaması (`{}`)
     ya da tanımsız şema varsa üretici hata verir.
  3. **Uygulama ayrıntıları (§3):** `HttpTasima` (ham HTTP: adres,
     başlıklar, problem, zaman aşımı, günlük) yalnızca kimliksiz uçları
     gönderir; `SessionStore` yenilemeyi onunla yapar, `ApiClient` kimlikli
     uçlarda token'ı ekler. Gönderilmiş bir yenileme token'ı hiçbir
     koşulda ikinci kez gönderilmez: göndermeden önce `GET /v1/status` ile
     bağlantı yoklanır (bağlantı yoksa token harcanmaz, oturum açık kalır),
     sonra kayıt depodan silinir; yeni çift alınamazsa (`invalid-refresh`,
     ağ kopması, sunucu hatası, depoda yenisi olmayan `refresh-conflict`)
     oturum kapanır. Depoda tek kayıt tutulur: token çifti, süreleri ve
     yönlendirme için `registration_pending` / `consent_required`
     bayrakları. `X-Tayfam-Client` sözleşmedeki gibi GET dışındaki
     isteklere eklenir (web geliştirme derlemesinde `web`). Yönlendirme
     izlenmez. `X-Tayfam-Client-Version` sözleşmede isteğe bağlıdır;
     sürümün kaynağı kararlaştırılınca eklenir. `/v1/status` yoklaması ve
     yenileme yanıtı alınamayınca oturumun kapanması #7'nin PR'ında
     platform sahibinin onayına sunuldu.
