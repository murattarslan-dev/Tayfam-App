# ADR-0018: Faz 1'in kalan modülleri ve dahili test sürümü

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Tarslan (kapsam ve hedef); arayüz ayrıntıları mimari oturumu
- **İlgili:** ADR-0002–0017; Notion: Özellik Haritası (MVP), Proje Planı §4–§6, Mağaza Sayfası, Kötüye Kullanım ve Genç Kullanıcı Güvenliği

## Bağlam

Platform sahibi Faz 1'in (MVP) tamamını bu hafta sonu (14–15 Kasım 2026)
Google Play dahili test kanalına göndermek istiyor (2026-11-11). Sürüm
**prod**'a (`api.tayfam.app`) bağlanacak; Play geliştirici hesabı hazır.

Main'de şunlar var:
- giriş ve kayıt,
- tayfa listesi, katılım ve oluşturma,
- etkinlikler, duyurular, hata metinleri, tanıtım sitesi, logo.

Değerlendirme penceresi ve hoş geldin tanıtımı PR aşamasında. Kalan
modüllerin ekran kararları hızlı ilerlemek için burada toplu
verilmiştir. Platform sahibi PR'larda değişiklik isteyebilir; her sapma bu
ADR'nin Notlar bölümüne yazılır.

## Karar

### Genel

- Her modül `features/<özellik>/` altındadır ve kendi rotalarını kayıtla
  ekler (ADR-0002).
- Tayfa ana sayfasında bölüm sırası:
  1. Etkinlikler
  2. Duyurular
  3. Açık anketler
  4. Son sorular

  Modül kapalıysa bölümü yoktur.
- Metinler Türkçe ve sen dilindedir. Gizlilik vaatleri (kesin kural 7)
  istemcide de tutulur.

### 1. Tayfa yönetimi (`tayfa_yonetim`)

- **Giriş noktası:** tayfa üst bölümündeki menüde "Tayfa ayarları"
  (yalnızca yönetim rolüne görünür). Bekleyen katılım isteği varsa
  rozet gösterilir.
- **Katılım istekleri:** onay ve ret; kimin davetiyle ya da referansıyla
  gelindiği gösterilir.
- **Üyeler (sayfalı, rol filtreli):**
  - rol değiştirme,
  - susturma (1 saat, 1 gün, 7 gün),
  - çıkarma,
  - banlama (onaylı; gerekçe isteğe bağlı, kapalı listeden — bkz. Notlar 2026-11-12).

  Kimse kendi seviyesindeki ya da üstündeki birine dokunamaz. İstemci
  yalnızca sadeleştirir; kararı sunucu verir.
- **Tayfa bilgileri:** ad, açıklama, ilgi alanları ve katılım politikası.
  Modüller açılıp kapatılabilir.
- **Tayfa kodu:** yenileme ve paylaşma.
- **Davet linkleri:** oluşturma, paylaşma, listeleme ve iptal.
- **Tayfa silme:** 72 saat bekleme ve iptal.
- **Üyenin kendi işlemleri:** "Tayfadan ayrıl" (onaylı) ve tayfa
  bildirimlerini sessize alma.

### 2. Profil ve hesap (`profil`)

Profil sekmesinde şunlar yer alır:

- **Görünen ad ve referans kodu:** kod kopyalanabilir ve paylaşılabilir.
- **Katılım geçmişi görünürlüğü:** `activity_visibility`.
- **Ayarlar:** tema (sistem, açık, koyu); kullanıcı ayarı olarak güvenli
  depoda tutulur.
- **Oturumlar:** liste, tek oturumu kapatma, "Diğer cihazlardan çık".
- **Hukuki metinler:** bağlantılar (ADR-0012).
- **Çıkış yap.**
- **Hesabı sil:**
  - Önce açıklama gösterilir: içerikler kalır, yazar "Silinmiş kullanıcı"
    olur.
  - Ardından onay istenir, sonra yeniden Google girişi yapılır, en son
    `DELETE /v1/me` çağrılır (CLAUDE.md "Hesap silme").

Profil tamamlama formu sözleşmede karşılığı olan alanlar geldiğinde
eklenir. Bugün `Account` yalnızca referans kodu ve görünürlük taşıyor.

### 3. Bildirimler (`bildirim`)

- **Bildirimler sekmesi:** sayfalı liste, okundu işareti, "Hepsini okundu
  say".
- **Rozet:** sekmede okunmamış sayısı gösterilir. Uygulama ön plana
  gelince ve WebSocket olayıyla güncellenir.
- **Hedefe gitme:** dokununca ilgili ekran açılır (`target_type`).
  Bilinmeyen tür için yalnızca okundu işaretlenir.
- **İçerik:** bildirimde içerik gösterilmez (kesin kural 7). Metin,
  türden ve tayfa adından kurulur.
- **Push (FCM):** bu sürüme girdi (platform sahibi, sohbette,
  2026-11-11); kararlar [ADR-0019](0019-push-bildirimleri.md)'da.

### 4. Soru-cevap (`soru_cevap`)

- **Liste:** arama, Türkçe büyük-küçük harf duyarsızdır; arama sunucuda
  yapılır. Etiket filtresi ve sayfalama vardır.
- **Soru detayı:** cevaplar "faydalı" oyuna göre sıralıdır. Kendi cevabına
  oy verilemez; bunu sunucu reddeder.
- **Yazma:** soru (başlık, gövde, etiketler) ve cevap. Düzenleme ve silme
  yazar ile yönetim içindir. Silinenin geri alınması yönetim ekranındadır.
- **Gövde:** düz metin (ADR-0015 §2 gibi).

### 5. Anket (`anket`)

- **Liste:** açık ve kapanmış anketler. Ankete etkinlikten bağlantı
  verilebilir (`event_id`).
- **Oy:** tek ya da çoklu seçim. Oy değiştirilebilir ve geri alınabilir.
- **Sonuç çubukları:**
  - Açık ankette seçeneğe dokununca oy verenler listelenir.
  - **Gizli ankette** kimin neye oy verdiği hiçbir yerde gösterilmez.
    Toplam oy **5'ten az** iken seçenek sayıları da gösterilmez; yalnızca
    toplam ve "Sonuçlar 5 oydan sonra görünür" yazar. Eşik kesin kural 7
    gereğidir.
- **Oluşturma:** soru, 2–10 seçenek, tek ya da çoklu seçim, açık ya da
  gizli, isteğe bağlı kapanma zamanı.
- **Kapatma:** yazan ya da yönetim kapatabilir.

### 6. Davet linkleri ve derin linkler (`shell/derin_link`)

- **App Links** (`https://tayfam.app/davet`, `/r/<KOD>`):
  - `site/.well-known/assetlinks.json` paket adı
    `com.murattarslan.tayfam` ve hem geliştirme hem Play uygulama imzası
    parmak izleriyle yazılır.
  - Play imzasının parmak izi platform sahibinden gelir.
- **Davet akışı:**
  - Token yalnızca fragment'tadır. Önizleme `POST /v1/invite-previews`,
    katılım `POST /v1/invite-joins` ile yapılır (kesin kural 9).
  - Giriş ya da kayıt gerekiyorsa link korunur ve sonra işlenir; hoş geldin
    tanıtımından sonra da işlenir.
  - Link hiçbir yere yazılmaz ve loglanmaz.
- **Referans linki:** kayıt formundaki kodu doldurur.
- **Site:** `/davet` ve `/r/` için, uygulama yoksa mağazaya yönlendiren
  sade karşılama sayfaları (JavaScript yok).

### 7. Arkadaşlık ve doğrudan davet (`arkadas`)

- **Arkadaş bulma ve istekler:** referans koduyla arkadaş bulunur
  (`POST /v1/referral-lookups`). Arkadaş isteği gönderilir, kabul ya da
  ret edilir.
- **Liste ve yönetim:** arkadaş listesi, arkadaşlıktan çıkarma, engelleme
  ve engeli kaldırma.
- **Doğrudan tayfa daveti:** arkadaşı tayfaya davet etme
  (`invitations`).
- **Profil görünümü:** katılım geçmişi listesi, görünürlüğe göre.

### 8. Şikâyet ve moderasyon (`sikayet`)

- **Şikâyet etme:** her içerikte "Şikâyet et" (gerekçe seçimi). Aynı
  hedefe tekrar şikâyet sunucuda engellenir.
- **Moderasyon kuyruğu:** tayfa ayarlarında (moderatör ve yönetici). Kuyruk
  içeriği gösterir; karar verilir, silinen içerik geri alınabilir.
- **Birebir mesaj şikâyeti:** yalnızca platforma gider; şikâyet eden mesajı
  kendi cihazından açık metin olarak iletir.

### 9. Sohbet (`sohbet`) ve WebSocket (`core/realtime`)

- **WebSocket:** ADR-0007'deki gibi tek bağlantı.
- **Kanallar:**
  - Tayfanın kanal listesi; yönetim kanalı yalnızca yönetime görünür.
  - Mesaj akışı: metin, silme, yavaş mod göstergesi, okundu işaretleme.
  - Kanal oluşturma, düzenleme ve arşivleme yönetim içindir.
- **Birebir mesaj (düz sürüm):**
  - Konuşma listesi ve mesaj akışı.
  - Mesaj istekleri: kabul, ret, reddedilenler.
  - Okundu bilgisi.
- **Sohbet sekmesi:** kanallar (aktif tayfanınkiler) ve birebir
  konuşmalar.
- **Uçtan uca şifreleme (Signal, ADR-0010):** ~~bu dahili test sürümüne
  girmez~~. **Güncelleme 2026-11-11 (platform sahibi):** E2E dahili test
  sürümüne girer; istemci tasarımı [ADR-0020](0020-birebir-uctan-uca-sifreleme-istemci.md).
  - Mobil istemci girişten sonra E2E cihazını kaydeder; birebir mesajlar
    uçtan uca şifreli gider.
  - ~~Düz sürümde yazılmış mesajlar "uçtan uca şifreli değil" etiketiyle
    görünür~~. **Güncelleme 2026-11-12 (Tayfam-Api #151):** düz sürüm
    kalktı, düz mesajlar sunucuda silindi; etiket kaldırıldı (ADR-0020).

### 10. Sürüm hattı

- **İmza:** Play App Signing kullanılır.
  - Yükleme anahtarı (upload key) platform sahibince üretilir ve GitHub
    secret'ı olur.
  - Sürüm imzası debug anahtarına asla düşmez (#13).
- **Yedekleme:** kapatılır (#12).
- **CI çıktısı:** etiketle (`vX.Y.Z`) tetiklenen iş akışı, prod API
  adresiyle imzalı bir `.aab` üretir ve artefakt olarak yükler. Play'e
  yükleme ilk sürümde elle yapılır; Play API'siyle otomatik yükleme
  sonraki iştir (dahili test için yapıldı; aşağıdaki Notlar).
- **Sürüm numarası:** `pubspec.yaml` `version`'ından alınır;
  `versionCode` her yüklemede artar.

#### Notlar (2026-11-11, platform sahibi, sohbette)

Play'e otomatik yükleme (issue #95, `.github/workflows/play-dahili.yml`):

- **Geliştirme anahtarı = yükleme anahtarı.**
  - Play App Signing kullanılır; Play `.aab`'ı kendi uygulama imzalama
    anahtarıyla yeniden imzalar. Ayrı bir yükleme anahtarı üretilmez.
  - `.aab`, mevcut `ANDROID_DEV_KEYSTORE_B64` / `_PASSWORD` /
    `ANDROID_DEV_KEY_ALIAS` / `_KEY_PASSWORD` secret'larıyla, Gradle'ın
    `TAYFAM_UPLOAD_*` ortam değişkenlerine verilerek imzalanır.
  - Gerekçe: anahtar zaten her CI çalışmasında var. Yükleme yetkisi
    anahtarda değil, Play API kimliğindedir; o kimlik yalnızca `main`'e
    ve `play-dahili` ortamına bağlıdır.
  - Anahtar sızarsa Play Console'dan yükleme anahtarı sıfırlanır.
    Kullanıcıların cihazındaki imza (Play'in anahtarı) değişmez.
  - `surum.yml`'nin `play-yayin` ortamındaki `ANDROID_UPLOAD_*`
    secret'larıyla imzalanan `.aab`'ı Play'in kabul etmesi için bu
    secret'lar da aynı anahtarı taşımalıdır.
- **Her `main` birleşmesinde dahili test.**
  - `main`'e her push'ta (ve yalnızca `main`'den elle) prod API'ye
    (`https://api.tayfam.app`, `TAYFAM_GOOGLE_SUNUCU_ISTEMCI_PROD`) bağlı
    imzalı `.aab` derlenir ve Play'in `internal` kanalına yüklenir.
  - Aynı anda tek çalışma; yeni birleşme eskisini iptal eder. Yalnızca en
    son `main` gider.
  - Sürüm notu (tr-TR) son commit başlığıdır; 500 karakterle sınırlanır.
  - Sürüm durumu `PLAY_SURUM_DURUMU` değişkeniyle seçilir (varsayılan
    `completed`). Uygulama Play'de hâlâ taslaksa `draft` gerekir.
- **Anahtarsız Play API kimliği.**
  - Google Cloud Workload Identity Federation ile GitHub OIDC token'ı kısa
    ömürlü (15 dk), yalnızca `androidpublisher` kapsamlı bir erişim
    token'ına çevrilir. JSON servis hesabı anahtarı yoktur.
  - OIDC izni (`id-token: write`) yalnızca yükleme işindedir. Derleme işi,
    üçüncü taraf kodu çalıştırdığı için bu izni almaz.
  - Değişkenler: `GCP_WIF_SAGLAYICI`, `GCP_PLAY_SERVIS_HESABI`. Yoksa
    derleme ve artefakt yine olur; yükleme uyarıyla atlanır. İlk `.aab`
    Play Console'a elle yüklenir.
  - Yükleme betiği `tool/play/dahili_yukle.py` yalnızca Python standart
    kütüphanesini kullanır: `edits.insert` → `edits.bundles.upload` →
    `edits.tracks.update` → `edits.commit`; hata ya da iptalde
    `edits.delete`. Token ve yanıt gövdeleri log'a yazılmaz.
- **versionCode kuralı.**
  - Dahili test derlemesinde `versionCode` = `github.run_number` + 100;
    `versionName` = `pubspec.yaml`'daki `X.Y.Z`.
  - Taban, `pubspec.yaml`'daki `+N` ile (şu an `+1`) çakışmasın diye
    vardır. Aynı çalışmanın yeniden denenmesi aynı kodu üretir. Önceki
    deneme Play'e işlenmişse Play reddeder; yeni bir çalışma başlatılır.
- **`surum.yml`'nin rolü.**
  - `vX.Y.Z` etiketiyle tetiklenen, `pubspec.yaml` sürümüyle eşleşen
    etiketli sürüm derlemesidir. İleride üretim kanalına giden yol odur.
  - Aynı uygulamaya yüklenecekse etiketli sürümün `+N`'i son dahili test
    `versionCode`'undan büyük olmalıdır.

### Dalgalar

| Dalga | İşler |
| --- | --- |
| 1 | Tayfa yönetimi, profil ve hesap, bildirimler, soru-cevap, anket |
| 2 | Derin linkler ve davet, arkadaşlık, şikâyet ve moderasyon, sohbet ve WebSocket |
| 3 | Sürüm hattı (#12, #13, `.aab`), Play hazırlığı, uçtan uca test listesi |

Her dalga paralel alt oturumlarla yürür. Birleştirme sırası çakışmaya
göre mimari oturumunca belirlenir.

### Notlar

- **2026-11-12 (issue #113, Tayfam-Api #150):**
  - Bekleyen katılım isteği rozeti sayılıdır ve tayfanın
    `pending_join_request_count` alanından gelir (tayfa görünümü ve
    Tayfalarım listesi). Alan yalnızca moderatör ve yöneticiye döner;
    alan yoksa ya da 0 ise rozet yoktur. `page_size=1` ile yoklama
    kaldırıldı. Tayfalarım listesinde de rozet gösterilir.
  - Banlamada gerekçe **isteğe bağlıdır** (önceden §1 "gerekçe istenir"
    diyordu): şikâyet nedenleriyle aynı kapalı liste, `staff_conduct`
    hariç, serbest metin yok (platform sahibi kararı, 2026-11-12; istemcide
    isteğe bağlı kalması 2026-11-12 19:55 sohbette teyit edildi).
    Gerekçe denetim kaydına ve platform paneline gider; banlanan kişiye
    ve istemcinin hiçbir yerinde gösterilmez.
  - Anket formu `client_request_id`'yi form açılınca bir kez üretir ve
    tekrarlarda aynısını gönderir.
  - Profil sekmesi kendi görünen adını `GET /v1/me/account`'tan gösterir.

## Sonuçlar

- **Platform sahibinin işleri:**
  - Play'de uygulamayı açma ve dahili test kullanıcıları,
  - yükleme anahtarı ve secret'ları,
  - Play imza parmak izinin Google Cloud'a Android istemcisi olarak
    eklenmesi (prod OAuth istemcisi),
  - Cloudflare token yetkisi (gizlilik ve hesap silme sayfaları için),
  - prod API'nin hazır olması.
- **Yeni paket gerekmez.** WebSocket için `web_socket_channel` zaten
  ADR'de var.
- **Push** ([ADR-0019](0019-push-bildirimleri.md)) ve **uçtan uca
  şifreleme** ([ADR-0020](0020-birebir-uctan-uca-sifreleme-istemci.md))
  platform sahibinin 2026-11-11 kararlarıyla bu sürüme girdi.

## Değerlendirilen alternatifler

- **Her modül için ayrı soru-cevap turu:** hafta sonu hedefine
  yetişmezdi.
- **Uçtan uca şifrelemeyi dahili teste sokmak:** Rust bağlamasının
  incelenmesi ve CI'da derlenmesi en riskli parça; pilotun ilk haftasını
  etkilemeyen bir eksik.
