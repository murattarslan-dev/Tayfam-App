# CLAUDE.md — Tayfam istemcisi (Flutter)

Bu dosya, bu repoda çalışan her oturumun (insan ya da ajan) uyması gereken
kuralları içerir. İnceleme bu dosyaya ve `docs/adr/` altındaki kararlara
göre yapılır. Bir kuralla çelişen bir şey yapman gerekiyorsa **dur, PR
açıklamasında açıkça belirt**; sessizce sapma.

Bu dosya Tayfam-Api reposundaki `CLAUDE.md`'nin istemciye uyarlanmışıdır.
İki dosya çelişirse sunucuyla ilgili konularda API reposu, istemciyle ilgili
konularda bu dosya geçerlidir; çelişkiyi platform sahibine bildir.

## Proje

Repo public'tir ve MIT lisanslıdır. Yazdığın her şeyin herkes tarafından
okunacağını varsay: koda, testlere, commit mesajlarına ve PR açıklamalarına
gerçek kullanıcı verisi, secret, imzalama anahtarı veya iç adres/parola
girmez.

Tayfam; kulüplerin ve arkadaş gruplarının (tayfaların) etkinlik, duyuru,
soru-cevap ve sohbet ihtiyaçlarını tek uygulamada karşılar. Bu repo Flutter
istemcisidir: Android, iOS ve tam web sürümü. İlk hedef platform Android.

- Mimari özet: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Kararlar ve gerekçeleri: [`docs/adr/`](docs/adr/README.md)
- Sunucu sözleşmesi: Tayfam-Api reposunda `api/openapi/gateway.yaml`
- Ürün kararları, veri modeli, tasarım standartları ve marka: Notion'daki
  "Tayfam — Proje Planı" ve alt sayfaları. İstemciye geçiş özeti:
  "İstemci Geçiş Özeti (API → Flutter)".

## Kararlar ve Notion

Ürün kararlarının kaynağı Notion'daki **"Tayfam — Proje Planı"** sayfası ve alt
sayfalarıdır (özellik haritası, veri modeli, tasarım standartları, marka, KVKK
aydınlatma metni, topluluk kuralları, kötüye kullanım ve genç kullanıcı
güvenliği). İstemcinin mimari kararlarının kaynağı bu repodaki `docs/adr/`,
sunucunun kararlarınınki Tayfam-Api'deki `docs/adr/`'dir.

- **Karar almadan önce oku.** Bir ekran, akış veya modül tasarlamadan, bir
  kuralı yorumlamadan ya da seçenek önermeden önce Notion'daki ilgili sayfayı,
  ilgili ADR'leri ve OpenAPI sözleşmesini oku (Notion MCP bağlantısıyla).
  Notion'da zaten verilmiş bir kararı yeniden tasarlama.
- **Çelişkiyi sakla değil, söyle.** Notion, ADR, OpenAPI veya kod çelişiyorsa
  ya da bir karardan sapmak gerekiyorsa bunu açıkça belirt ve platform
  sahibine sor. Sapma kabul edilirse hem ADR'ye hem Notion'daki ilgili sayfaya
  yazılır.
- **Yeni kararı yaz.** Platform sahibiyle birlikte yeni bir karar alınırsa
  aynı oturumda Notion'daki ilgili sayfaya işlenir (ürün kararı) ve gerekiyorsa
  ADR eklenir veya güncellenir (mimari karar). Proje planının yol haritası
  tamamlanan işlerle güncel tutulur.
- **Erişim yoksa varsayma.** Notion'a ulaşılamıyorsa bunu söyle; Notion'da ne
  yazdığını tahmin ederek ilerleme.
- Notion'a gerçek kullanıcı verisi, secret veya iç adres/parola yazılmaz.

## Güvenlik ilkesi

Hedef: sisteme sızmak olabildiğince zor olmalı; **sızılsa bile verilebilecek
hasar en aza inmeli** (Tayfam-Api ADR-0011). İstemci için bunun anlamı:

- **İstemci güvenilmez bir ortamdır.** Cihaz kaybolabilir, root'lanabilir,
  uygulama tersine mühendislikle açılabilir, web sayfasına zararlı betik
  enjekte edilebilir. Güvenlik kararı istemcide verilmez; arayüzde bir düğmeyi
  gizlemek kolaylıktır, yetki kontrolü değildir.
- **Hasarı sınırla.** "Bu cihaz veya bu tarayıcı oturumu ele geçirilirse
  saldırgan neye ulaşır?" sorusunun cevabı dar olmalı: kısa ömürlü token'lar,
  güvenli depoda anahtarlar, diskte gereğinden fazla veri yok.
- **Tutmadığın veri çalınamaz.** Gerekmeyen veriyi önbelleğe alma, diske
  yazma, loglama, analitiğe veya hata raporuna gönderme.
- **Doğrula.** Derin linkten, bildirimden, panodan veya sunucudan gelen her
  veriyi girdi kabul et ve doğrula.
- **En az izin.** Uygulama yalnızca gereken platform iznini, gerektiği anda
  ister (örneğin konum yalnızca check-in sırasında).

## Kesin kurallar

Bunların ihlali PR'ın reddedilmesi için yeterlidir.

1. **Sözleşme önce gelir.** İstemci sunucuyla yalnızca
   `api/openapi/gateway.yaml`'daki uçlar ve alanlarla konuşur. Sözleşmede
   olmayan bir uç, alan veya davranış varsayılmaz; gerekiyorsa Tayfam-Api'de
   issue açılır ve önce sözleşme değişir.
2. **Token'lar güvenli saklanır.** Mobilde erişim ve yenileme token'ları
   yalnızca platformun güvenli deposunda (Android Keystore / iOS Keychain)
   tutulur; düz dosyaya, `SharedPreferences`'a veya veritabanına yazılmaz.
   Web'de token'lar HttpOnly çerezlerdedir (`tayfam_at`, `tayfam_rt`);
   JavaScript/Dart tarafı token görmez, `localStorage`/IndexedDB'ye token
   yazılmaz. Token yenileme tek noktadan yapılır (ayrıntı: aşağıda "API ile
   konuşma").
3. **Kişisel veri log'a girmez.** Log, analitik, hata raporu ve hata
   ayıklama çıktısına mesaj metni, konum, e-posta, doğum tarihi, token,
   yenileme token'ı, davet token'ı, tam URL (fragment dahil) veya gizli anket
   oyu yazılmaz. Cihazın anlık konumu yalnızca check-in isteğinde kullanılır;
   saklanmaz, önbelleğe alınmaz, loglanmaz. Kullanıcının bilerek paylaştığı yer
   (buluşma noktası, rota, av yeri) içeriktir (Tayfam-Api ADR-0008).
4. **Kendi kriptografini yazma.** Birebir mesajlarda E2E için Signal protokolü,
   ADR ile seçilen kütüphaneyle kullanılır. Rastgele değerler yalnızca
   kriptografik üreteçle (`Random.secure()` veya platform CSPRNG'si) üretilir.
   Web'de anahtarlar WebCrypto ile dışa aktarılamaz (non-extractable) üretilir.
5. **Yetki sunucudadır.** İstemci rol veya üyeliğe göre arayüzü
   sadeleştirebilir, ama bir işlemin yapılabileceğine kendisi karar vermez;
   sunucunun cevabına (`forbidden` vb. hata `type`'larına) göre davranır.
6. **Gizli bilgi repoya girmez.** İmzalama anahtarları (`.jks`, `.keystore`,
   `key.properties`, `.p12`, `.p8`), servis hesabı dosyaları ve parolalar repoya
   girmez; CI'da yalnızca GitHub secret'ı olarak bulunur. İstemciye gömülen her
   değer (OAuth istemci kimliği, API adresi) public sayılır; istemciye gizli
   kalması gereken hiçbir değer gömülmez.
7. **Gizlilik vaatleri istemcide de tutulur.** Gizli ankette kimin neye oy
   verdiği gösterilmez ve az oyda sayım kimlik açabileceği için eşik
   uygulanır; bildirimlerde içerik gösterilmez; DM bildiriminde gönderen adı
   bile yoktur; kapalı (gizli) tayfaların içeriği üye olmayana hiçbir yerde
   (önizleme, paylaşım kartı, önbellek) görünmez.
8. **Bağımlılıklar sabitlenir ve gerekçelenir.** `pubspec.lock` commit edilir.
   Yeni paket eklemeden önce Flutter/Dart standart kütüphanesinin yetip
   yetmediğine bak; eklediğin her paketi PR'da gerekçele (yayıncı, bakım
   durumu, izinler, web desteği). GitHub Actions commit SHA'sıyla sabitlenir.
9. **Derin linkler doğrulanır.** Davet linki `https://tayfam.app/davet#<token>`
   biçimindedir: token fragment'tadır, sunucuya URL ile gitmez; istemci onu
   yalnızca istek gövdesinde API'ye iletir ve hiçbir yere yazmaz. Referans linki
   `tayfam.app/r/<KOD>`'dur. Yalnızca beklenen alan adı ve yol kabul edilir.

## API ile konuşma

Ayrıntının kaynağı OpenAPI sözleşmesi ve Tayfam-Api ADR-0004, ADR-0005,
ADR-0014'tür. Özet:

- **Giriş:** Google ID token (nonce zorunlu) → `POST /v1/auth/sign-in`.
  `registration_pending: true` ise kayıt (doğum tarihi + onay sürümleri);
  `consent_required: true` ise yeniden onay (`/v1/me/consents`).
- **Token yenileme:** Erişim token'ı 15 dakikadır. Yenileme token'ı her
  kullanımda değişir; eski token 10 saniyelik tolerans dışında yeniden
  kullanılırsa sunucu oturumu güvenlik gereği iptal eder. Bu yüzden yenileme
  tek noktadan yapılır, eşzamanlı istekler yenileme bitene kadar kuyruklanır.
- **CSRF:** Durum değiştiren her istekte `X-Tayfam-Client: android | ios | web`.
- **Hatalar:** RFC 9457 `application/problem+json`. İstemci `type` alanındaki
  koda (`https://tayfam.app/problems/<kod>`) göre davranır; `title` metni
  kullanıcıya gösterilmez. Bilinmeyen `type` için genel bir hata metni
  gösterilir.
- **Arayüz metinleri** çeviri dosyalarındadır; kodda sabit kullanıcı metni
  yoktur. API Türkçe metin döndürmez.
- **Sayfalama:** `page_size` + opak `page_token` → `next_page_token`. Token
  ayrıştırılmaz, üretilmez.
- **Tekrar gönderim:** Oluşturma isteklerinde istemcinin ürettiği
  `client_request_id` (UUID) gönderilir; aynı iş tekrar gönderilirken aynı id
  kullanılır. Çevrimdışı kuyruk buna dayanır.
- **Hesap silme:** Son 10 dakikada yeniden Google girişi gerekir
  (`reauthentication-required`); akış: yeniden giriş → `DELETE /v1/me`.
- **WebSocket:** `GET /v1/realtime`; mobilde `Authorization: Bearer`, web'de
  çerez. `4003 token_expired` → token yenilenir, sessizce yeniden bağlanılır.
  `4001 session_ended` → oturum kapanmıştır, girişe dönülür. `rate_limited`
  çerçevesinde gönderim yavaşlatılır.

## Klasör yapısı, durum yönetimi ve kodlama kuralları

Mimari kararlar soru-cevapla alınıp `docs/adr/`'ye yazıldıkça bu bölüm
doldurulur. Sıradaki kararlar (Notion: "İstemci Geçiş Özeti", §4):

- Modül yapısı ve modül kaydı (registry)
- Durum yönetimi ve navigasyon (davet ve referans derin linkleri)
- API istemcisi (OpenAPI'den üretim mi elle mi), token yenileme, hata eşlemesi
- Çevrimdışı kuyruk
- Güvenli token ve anahtar saklama
- WebSocket yeniden bağlanma ve abonelik yönetimi
- Signal kütüphanesi seçimi (mobil + web)
- Tema token'ları ve çeviri dosyaları
- CI ve iOS derlemesi (GitHub Actions macOS runner'ı ya da Codemagic)

Karar verilmemiş bir konuda kod yazılmaz; önce ADR.

## Arayüz ve kullanıcı deneyimi

UI/UX işi mimarinin parçasıdır; ekran akışları, bileşenler ve tasarım
kuralları da soru-cevapla alınır ve ADR'ye yazılır.

- **Kaynak sırası.** Notion'daki **Marka** ve **Tasarım Standartları**
  sayfaları (Tropik palet, tipografi, logo, ton) ve bu repodaki ADR'ler
  bağlayıcıdır. `ui-ux-pro-max` skill'i (`.claude/skills/ui-ux-pro-max/`)
  erişilebilirlik, dokunma, düzen, hareket ve Flutter'a özgü uygulama için
  **danışma kaynağıdır**; önerisi Notion'daki bir kararla çelişirse Notion
  geçerlidir, çelişki platform sahibine söylenir. Skill'in ürettiği palet veya
  font önerisi onaysız uygulanmaz.
- **Ne zaman kullanılır.** Ekran, bileşen, akış veya tema işinde; arama
  yaparken `--stack flutter` ve ilgili `--domain` kullanılır. Bir arayüz
  PR'ı açılmadan önce skill'in `references/pro-rules.md`'deki teslim öncesi
  kontrol listesinden geçirilir.
- **Gizlilik.** Skill aramalarına kullanıcı verisi veya iç bilgi yazılmaz.
  `--persist` ve `--force` platform sahibinin onayı olmadan kullanılmaz.

## Test beklentileri

Test stratejisi ADR ile netleşir. Şimdiden geçerli olanlar:

- Her PR testleriyle gelir.
- Token yenileme, hata `type` eşlemesi, derin link ayrıştırma ve çevrimdışı
  kuyruk birim testleriyle korunur.
- Hata düzeltmesi, hatayı yeniden üreten bir testle gelir.

## İş akışı

- Her iş bir GitHub issue'dur. Bir oturum yalnızca bir issue üzerinde çalışır.
- Dal adı: `<tür>/<kısa-açıklama>` (`feat/giris-ekrani`, `fix/token-yenileme`).
- Commit mesajları Conventional Commits biçimindedir (`feat:`, `fix:`,
  `docs:`, `refactor:`, `test:`, `chore:`).
- PR şablonundaki her başlık doldurulur.
- **`main`'e doğrudan push yapılmaz.** `main` bir kural setiyle korunur
  (Tayfam-Api ADR-0010 ile aynı model: PR zorunlu, squash, CI geçmeden
  birleştirme yok, onay zorunluluğu yok).
- **CI geçmeden hiçbir PR birleştirilmez.**
- **Platform sahibinin işi en aza indirilir.** Yalnızca platform sahibinin
  yapabileceği işler (mağaza ve Firebase konsolu, imzalama anahtarı, hesap
  ayarları), yapılabilecek her şey önceden hazırlandıktan sonra tek bir
  listede, kopyalanıp uygulanabilir halde istenir. Aynı şey iki kez istenmez.
- **Hassas alanlar** (`.github/CODEOWNERS`'taki yollar) değiştiren PR'ları
  yalnızca platform sahibi birleştirir. Bu PR'ları açarken açıklamaya
  "Hassas alan" etiketini ve hangi alana dokunduğunu yaz.
- **Pilot öncesi esneme (süreli, Tayfam-Api ADR-0010 ile aynı):** İlk gerçek
  kullanıcı verisine kadar mimari oturumu hassas alanların çoğunu
  birleştirebilir: CI tamamen yeşil olmalı, içerik platform sahibiyle sohbette
  konuşulmuş olmalı ve PR açıklamasında "Sohbette onaylandı" notu bulunmalıdır.
  `.github/`, imzalama yapılandırması ve `CLAUDE.md` her zaman yalnızca
  platform sahibine kalır. Pilottan önce bu madde kaldırılır.
- Mimari bir kararı değiştiren PR, yeni bir ADR ekler.

## Komutlar

Flutter projesi oluşturulunca eklenir.
