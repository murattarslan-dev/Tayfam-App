# ADR-0018: Faz 1'in kalan modülleri ve dahili test sürümü

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Arslan (kapsam ve hedef); arayüz ayrıntıları mimari oturumu
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

- **2026-11-13 (platform sahibi; issue #151): Bildirimler sekmesi ve
  bildirim ayarları yeniden tasarımı (§3).** Tasarım: Bildirimler,
  Bildirimler-Koyu, Bildirimler-Bos, Bildirim-Ayarlari.
  - **Gruplama ve satır:** liste zamana göre gruplanır (Bugün / Dün / Bu
    hafta / Daha eski; cihaz saat diliminde takvim günü, "Bu hafta" son 7
    gün). Satırda kategori renginde tür ikonu (ADR-0004 Notlar
    2026-11-13, bildirim kategorisi renkleri), türden kurulan metin, tayfa
    adı etiketi ve göreli zaman (bugün ve dün saat, bu hafta gün adı,
    sonra "3 Kas"). Okunmamışta tint zemin, kalın metin ve "Okunmadı"
    etiketli nokta. Dokununca okundu + `bildirimAdresi`. Altta "Bildirimler
    90 gün saklanır." (sözleşme).
  - **Satır içi işlem:** arkadaşlık isteğinde Reddet / Kabul et, tayfa
    davetinde Reddet / Katıl (mevcut `/v1/me/friend-requests…` ve
    `/v1/me/invitations…` uçları; istekler ve davetler ekranlarıyla aynı
    sonrası). Sonuç düğmelerin yerinde teal tikle görünür ("Artık
    arkadaşsınız", "Katıldın", onaylı tayfada "İsteğin gönderildi",
    "Reddedildi") ve bildirim okundu olur. Katılım isteğinde "İncele"
    tayfanın katılım istekleri ekranını açar. Sonuç yalnızca bellektedir:
    sözleşmede bildirimin işlem durumu yoktur, liste yeniden açılınca
    düğmeler yine görünür ve sunucu güncel durumu hata olarak bildirir.
  - **Güvenlik uyarısı:** okunmamış `hike_overdue` listenin en üstünde
    sabit nar karttadır (birden çoksa alt alta): kişinin adı, etkinliğin
    adı (`GET …/events/{event_id}`; yalnızca ad, bellekte), tayfa ve
    zaman. "Yoklamayı aç" okundu işaretler ve etkinliğin detayını açar;
    detayda yoklama bölümüne kaydırma yoktur (detay ekranında bölüm
    bağlantısı yok).
  - **Başlık ve kartlar:** "Hepsini okundu say" yalnızca okunmamış varken
    başlıkta. İzin verilmemişse ve açıklama kartı daha önce kapatılmadıysa
    (ADR-0019 §3 bayrağı) listenin üstünde mor izin kartı; "Şimdi değil"
    mevcut erteleme kuralıdır. Boş durumda logo, "Henüz bildirimin yok."
    ve açıklama. Okunmamış/tümü filtresi yok (sözleşmede süzme yok).
  - **Bildirim ayarları (Profil):** cihaz izni durumu ve sistem ayarları
    bağlantısı; sessize alınan tayfalar (`GET /v1/notification-preferences`,
    seviye `none` ya da `mentions`, süresi dolmamış; adlar tayfalarım
    listesinden) ve "Sesi aç" (`DELETE …/tayfas/{tayfa_id}`); birebir
    konuşmalar için yalnızca sessizdeki sayı ve "⋯ menüsünden" yönlendirmesi;
    gizlilik notu. Sessize alma yine tayfa ve konuşma menüsündedir.
  - **Kesin kural 7:** DM bildiriminde (`dm_request`, `dm_message`)
    gönderen yoktur; metin türden kurulur, kişi adı istenmez.
- **2026-11-13 (platform sahibi, sohbette; issue #141, PR #142): Sohbet
  sekmesi yeniden tasarımı (§9).** Tasarım: Sohbet-Kanallar,
  Sohbet-Birebir, Kanal-Akis, Kanal-Koyu, Kanal-Islem, Kanal-Formu,
  Birebir-Konusma, Birebir-Menu, Mesaj-Istekleri, Birebir-Istek.
  - **İki parçalı seçici:** sekme TabBar yerine "Kanallar | Birebir"
    seçicisiyle açılır; her parçada okunmamış toplamı (kanallarda
    `unread_count` toplamı, birebirde konuşmaların `unread_count` toplamı;
    "99+" kuralı). Açılışta okunmamışı olan parça seçili gelir, ikisinde de
    varsa Kanallar. Seçim yalnızca bellektedir; sayılar ilk geldiğinde
    sabitlenir (kanal sayısı bilinmeden Birebir seçilmez) ki parça
    kendiliğinden değişmesin.
  - **Kanallar:** aktif tayfanınkiler; üstteki "Kanalları gösterilen tayfa"
    satırı ana sayfadaki tayfa değiştirme panelini açar, seçilen tayfa
    Sohbet sekmesinde kalınarak aktif olur. Arşivdeki kanallar listenin
    altında açılır bölümdedir. "Kanal aç" yalnızca yönetimde.
  - **Önizlemesiz listeler:** kanal satırında son mesaj önizlemesi yoktur
    (sözleşme döndürmez); birebir satırında da yoktur (mesajlar uçtan uca
    şifreli, diske yazılmaz, sözleşme son mesajı döndürmez). Satırda
    okunmamış sayısı, yavaş mod ya da yönetim bilgisi; birebirde göreli
    zaman (bugün saat, dün, hafta içi gün adı, sonra tarih; tr_TR), sessiz
    simgesi ve "Uçtan uca şifreli" ya da istek durumu.
  - **Mesaj akışı:** aynı yazarın ardışık mesajları (aynı gün, aralık en
    çok 5 dakika) gruplanır; kanalda ad grubun ilk balonunda (kişiye göre
    renk yok), avatar ve saat grubun sonunda; birebirde ad ve avatar yok.
    Gün ayırıcı "Bugün", "Dün", sonra tarih. "Görüldü" yalnızca son kendi
    mesajın altında. E2E uyarıları ("Güvenlik kodu değişti", yeni cihaz)
    akış içinde sarı sistem notudur.
  - **Gönderilemeyen mesaj:** tint-nar zemin + nar-metin kenarlı balon;
    altında "Gönderilemedi", "Tekrar dene" (aynı `client_request_id`,
    çevrimdışı kuyruk; ADR-0006) ve "Sil".
  - **Yavaş mod:** yazma alanının üstünde "Yavaş mod: N saniyede bir
    mesaj"; gönderden sonra gönder düğmesi geri sayıma döner ("12 sn"),
    ipucu "N sn sonra yazabilirsin". Yönetim muaftır (sunucu söyler).
  - **Uzun basma sayfası:** "Mesaj işlemleri" alttan sayfası ve kısa
    alıntı (birebirde yalnızca cihazda çözülmüş metin; loglanmaz). Kanalda
    "Mesajı sil" (kendi ya da yönetim) ve silinmiş, geri alınabilir mesajda
    yönetime "Geri al"; birebirde "Mesajı sil" (kendi) ve "Şikâyet et"
    (gelen). Kanal mesajı şikâyeti sözleşmede yoktur, eklenmedi.
  - **Diğer:** birebir ⋯ alttan sayfası (Profili gör, Sessize al / Sesi
    aç); gelen istekte üstte kart ve altta Reddet / Kabul et (cevap yazmak
    da kabul sayıldığı için yazma alanı korunur); kanal formu alttan
    sayfada, yavaş mod çipleri.
  - **Alttan sayfa kullanımı** (ADR-0004 Notlar 2026-11-13, madde 5) mesaj
    işlemleri, birebir ⋯ menüsü, sessize alma süresi ve kanal formu ile
    genişledi. Yeni ortak bileşenler: `GunAyirici`, `SistemNotu`,
    `MesajAltSatiri`, `GonderilemediSatiri`, `MesajYazmaCubugu`,
    `KimlikAvatari`; `SohbetBalonu` türleri (akış, silinmiş,
    gönderilemedi). Yeni ölçüler: `TayfamSizes.mesajAvatari` (32),
    `konusmaAvatari` (48), `konusmaSatiri` (72), `ustCubukKutusu` (36),
    `parcaRozeti` (22).
  - **Tasarlandı, kodlanmadı:** kanal kitlesi ve kişi seçimi, etkinlik
    kanalı seçimi, kanal katılımcıları, özel kanallı liste, etkinlik bitince
    kapanış bandı ve arşivlenen etkinlik kanalı (Kanal-Kitle,
    Kanal-Kisi-Sec, Kanal-Etkinlik-Sec, Kanal-Katilimcilar,
    Sohbet-Kanallar-Ozel, Kanal-Etkinlik-Bitti, Kanal-Etkinlik-Arsiv)
    sözleşmede karşılıkları olmadığı için kodlanmadı; Tayfam-Api #183
    bekleniyor (§2'deki kural).
- **2026-11-13 (platform sahibi, sohbette; issue #138): profil sekmesi,
  arkadaşlar ve kişi profili yeniden tasarımı.** Tasarım: Profil-*,
  Kisi-Profili*.
  - **Profil düzeni (§2):** en üstte fotoğraf (dokununca alttan sayfa:
    Galeriden seç, Fotoğraf çek, fotoğraf varken Fotoğrafı kaldır), ad ve
    mor referans kodu kartı (Paylaş birincil, Kopyala, onaylı "Yeni kod
    al" simge düğmesi). Ardından Arkadaşlar bölümü (ilk sayfadaki ilk üç
    arkadaşın avatarı, sayı yok; istek ve davetlerde yalnızca nokta, sayı
    ilgili ekranda), katılım geçmişinin son 3 kaydı
    (`GET /v1/users/{kendi id}/activity`, `page_size=3`) ve "Tümünü gör"
    (`/profil/katilimlarim`), başlığın yanında görünürlük çipi (dokununca
    üç seçenekli alttan sayfa, seçince hemen kaydedilir). Uygulama kartı
    (Bildirimler, satır içi üç parçalı tema seçici, Oturumlar), Gizlilik
    kartı (Verilerimi indir, Engellenenler, Aydınlatma metni, Kullanım
    koşulları), çerçeveli "Çıkış yap" ve en altta nar-metin "Hesabı sil"
    bağlantısı. Hesap silme ekranında "Önce verilerini indir" kısayolu
    vardır; akış (onay → Google yeniden giriş → `DELETE /v1/me`)
    değişmedi.
  - **"Başkaları nasıl görüyor":** kendi kişi profilini (`/kisi/<kendi
    id>`, `self: true`) açar; orada ⋯ menüsü ve eylem yoktur.
  - **Arkadaşlar ekranı (§7):** üstte "Arkadaş ekle" (alttan sayfa;
    mevcut kodla bulma mantığı) ve "Kodumu paylaş"; bekleyen gelen istek
    varsa sayılı kart (sayı gelen istek listesinin ilk sayfasından,
    devamı varsa "N+"), arkadaş listesi, altta "Engellenenler". Satırlarda
    alt metin yoktur: arkadaş listesinde ortak tayfa bilgisi sözleşmede
    dönmez, uydurulmaz.
  - **Kişi profiline kullanıcı şikâyeti (§8):** ⋯ menüsü artık alttan
    sayfadır: Arkadaşlıktan çıkar (arkadaşsa), **Şikâyet et** (yeni; hedef
    `user`, gerekçe seçimi mevcut şikâyet sayfası) ve Engelle (yıkıcı).
    Sözleşmede kullanıcı şikâyeti yalnızca bir tayfada yapılır (`POST
    /v1/tayfas/{tayfa_id}/reports`); bu yüzden "Şikâyet et" yalnızca ortak
    tayfa varken görünür, birden çok ortak tayfada tayfa seçtirilir.
    Ortak tayfası olmayan kişiyi platforma şikâyet edecek uç yoktur
    (Tayfam-Api'de karar gerekir).
  - **Alttan sayfa kullanımı (ADR-0004 Notlar 2026-11-13, madde 5)**
    profil fotoğrafı, görünürlük seçimi, arkadaş ekleme, kişi profili ⋯
    menüsü ve şikâyet tayfası seçimi ile genişledi. Yeni ortak bileşenler:
    `BolumEtiketi` (15 px ikincil bölüm başlığı), `CerceveliHapEylem`,
    `BaglantiEylemi`, `MenuSatiri.kartta`, `SatirOku`, `BekleyenNoktasi`;
    yeni ölçüler `TayfamSizes.profilAvatari` (104), `fotografRozeti` (36),
    `avatarYigini` (28), `avatarOrta` (52).
  - **Kişi profilindeki "Mesaj gönder"** birincil eylem oldu (önce nar
    ikincil eylemdi).
  - **Tasarlandı, kodlanmadı:** ad düzenleme, doğum günü görünürlüğü ve
    profil tamamlama formu (Proje Planı §4.7) tasarlandı (Profil-Ad-Duzenle,
    Profil-Dogum-Gunu, Profil-Tamamla) ama sözleşmede karşılıkları
    olmadığı için kodlanmadı; sözleşme gelince eklenir (§2'deki kural).
- **2026-11-13 (platform sahibi; PR #130):** Play hattı uçtan uca
  çalışıyor. İlk `.aab` Play Console'a elle yüklendi; CI Google'a JSON
  anahtarsız, Workload Identity Federation ile girer (havuz `github`,
  sağlayıcı `tayfam-app`; koşul: repo ve sahip kimliği, `refs/heads/main`,
  `play-dahili` ortamı; rolsüz servis hesabı, Play'de yalnızca Tayfam için
  test kanalı yetkisi). Google'ın ilk incelemesi onaylandı.
  - **Kanal:** her `main` birleşmesi artık **kapalı test** kanalına
    (`alpha`) gider; `play-dahili` ortamındaki `PLAY_KANALI` değişkeniyle
    değiştirilebilir (`internal` = dahili test). Kapalı test sürümleri
    Google incelemesinden geçer.
  - **Sürüm notu:** Play'deki "Yenilikler" metni commit başlığı değil,
    `play/surum-notu.tr-TR.txt` (kullanıcıya yönelik Türkçe, en çok 500
    karakter, `#` satırları açıklama). Kullanıcıya görünen bir değişiklik
    birleşirken aynı PR'da güncellenir; dosya boşsa genel bir not gider.
  - Bu bölümdeki "dahili test" ifadeleri tarihsel kayıttır.
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
