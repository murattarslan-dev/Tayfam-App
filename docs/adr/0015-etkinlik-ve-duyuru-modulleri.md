# ADR-0015: Etkinlik ve duyuru modülleri, tayfa ana sayfası

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0002](0002-modul-yapisi.md), [ADR-0003](0003-gezinme-iskeleti.md), [ADR-0004](0004-tema-ve-bilesen-dili.md), [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0014](0014-tayfa-listesi-katilim-ve-olusturma.md); Tayfam-Api ADR-0008 (konum); Notion: Proje Planı §3, §4; Özellik Haritası "Etkinlik", "Duyuru ve soru-cevap"; Tasarım Standartları "Etkinlik türü renkleri"

## Bağlam

Tayfa ana sayfası şu an yalnızca mor üst bölümü gösteriyor. Sunucuda
duyurular (liste, oluşturma, düzenleme, silme, sabitleme) ve etkinlikler
hazır:

- tür, mod, katılım ve bekleme listesi,
- varış bildirimi (check-in, 300 m),
- iptal, tekrar (RRULE) ve `.ics`,
- türe özel araçlar: konvoy araçları, kamp malzemeleri, yürüyüş
  yoklaması, av günlüğü.

Modülleri sunucunun `modules` alanı açar (ADR-0002).

## Karar

### 1. Tayfa ana sayfası: iki bölüm

Platform sahibinin kararı (2026-11-11). Mor üst bölümün altında sırasıyla:

1. **Yaklaşan etkinlikler:** `GET /events`'ten en yakın üç kart ve
   "Tümü" bağlantısı.
2. **Duyurular:** önce sabitlenenler, sonra son üç duyuru ve "Tümü"
   bağlantısı.

Kurallar:

- Modül kapalıysa ilgili bölüm hiç görünmez.
- Boş bölümde kısa bir boş durum gösterilir. Yetkili kullanıcıya
  "Etkinlik aç" ya da "Duyuru yaz" kısayolu eklenir; yetkiyi sunucu
  verir (`caller_can_manage`, rol), istemci yalnızca kolaylık sağlar.
- Aşağı çekince yenilenir. Veri yalnızca bellekte tutulur (ADR-0006).

### 2. Duyurular

- **Liste:** önce sabitlenenler, sonra en yeniden eskiye, sayfalı.
- **Detay:** başlık ve gövde. Gövde düz metin olarak gösterilir; markdown
  ya da HTML yorumlanmaz. Bağlantılar dokunulabilir değildir.
- **Yazma ve düzenleme:** başlık (1–120 karakter) ve gövde (en çok 5000
  karakter). `client_request_id` form açılınca bir kez üretilir.
- **Sabitleme, kaldırma ve silme:** silmede onay istenir.
- Moderatör silmesini geri alma (`restoration`) yönetim ekranlarıyla
  gelir.

### 3. Etkinlikler

**Liste ve kart.** Kartta şunlar bulunur: tür çipi (renk ve ikon tür
kaydından, ADR-0004 Notlar), başlık, tarih ve saat (`tr_TR`, Europe/Istanbul),
yer adı ya da "Çevrimiçi", gelen/kontenjan bilgisi ve senin cevabın.
İptal edilen etkinlik soluk görünür ve "İptal edildi" etiketi taşır.

**Detay** şunları gösterir:
- açıklama,
- yer (harita önizlemesi; dokununca sistemin harita uygulaması açılır),
- çevrimiçi bağlantı (yalnızca üyelere gelir),
- organizatör,
- katılım sayıları ve katılımcılar listesi,
- türe özel bölüm.

**Katılım.** "Geliyorum", "Belki" ve "Gelmiyorum" seçenekleri var.
Kontenjan doluysa "Geliyorum" seçimi bekleme listesine düşer ve bu
gösterilir.

**Takvime ekleme.** `.ics` dosyası indirilip sistemin paylaşım menüsüyle
takvim uygulamasına verilir (`share_plus`).

**Oluşturma: adım adım sihirbaz** (platform sahibi, 2026-11-11). Adımlar:
1. Tür.
2. Başlık, açıklama, başlangıç ve bitiş.
3. Yüz yüze ise buluşma noktası (harita seçici), il ve ilçe. Çevrimiçi ise
   bağlantı.
4. Türe özel alanlar, kontenjan ve tekrar. Tekrar, "Her hafta / Her ay",
   aralık ve bitiş seçimleriyle verilir; RRULE istemcide üretilir.

Sihirbazın kuralları ADR-0014 §4'teki gibidir: girilenler korunur,
`client_request_id` bir kez üretilir. Kapak görseli dosya altyapısı (R2)
gelene kadar yoktur.

**Düzenleme ve iptal.** `caller_can_manage` ise gösterilir. İptalde gerekçe
istenir. Seri etkinlikte düzenlemenin yalnızca bu etkinliği değiştirdiği
söylenir.

### 4. Buluşma noktası: OpenStreetMap harita seçici

Platform sahibinin kararı (2026-11-11):

- **Paket:** `flutter_map`, OpenStreetMap karolarıyla. Anahtar ve
  faturalandırma gerekmez.
- **Kullanım:** haritada iğne bırakılır ya da ad aranır. Ad araması
  Nominatim ile, yalnızca "Ara"ya basınca yapılır; anlık otomatik tamamlama
  yoktur. Bunun nedeni Nominatim'in kullanım kuralı: saniyede en çok bir
  istek ve otomatik tamamlama yasağı. İsteklerde uygulamayı tanıtan bir
  `User-Agent` gönderilir; OSM atfı haritada gösterilir.
- **Gizlilik:** karo ve arama istekleri OSM'ye kullanıcının IP adresini ve
  bakılan bölgeyi gösterir. Cihazın konumu gönderilmez. Seçici açılınca
  harita il düzeyinde bir varsayılanla başlar; cihaz konumu bu ekranda
  **istenmez**. Bu yurt dışına aktarım aydınlatma metnine eklenir
  (hukukçu listesi).
- **Yük:** OSM karo sunucularının kullanım kuralı yoğun trafiği kabul
  etmez. Pilottan sonra kullanım büyürse karo sağlayıcısı yeniden
  değerlendirilir; `flutter_map` sağlayıcı değişimine izin verir.

### 5. Varış bildirimi ("Geldim")

- Düğme yalnızca pencere açıkken ve cevabın "Geliyorum" ise görünür.
  Pencere başlangıçtan 30 dakika önce açılır, bitişte kapanır.
- **Konum izni** yalnızca bu düğmeye basılınca, "uygulamayı kullanırken"
  kapsamıyla istenir. Paket: `geolocator`.
- Konum tek seferlik okunur, yalnızca istek gövdesinde gider; saklanmaz,
  önbelleğe alınmaz, loglanmaz (kesin kural 3).
- Hata metinleri uzaklık söylemez.
- Çevrimiçi etkinlikte konum istenmez; düğmenin adı "Katıldım" olur.

### 6. Türe özel araçlar

| Tür | Araç | Kim kullanır |
| --- | --- | --- |
| Konvoy | Araç listesi; kendi aracını ekleme | Herkes kendi aracı için |
| Kamp | Ortak malzeme listesi | Ekleme ve çıkarma: yönetim ve organizatör |
| Yürüyüş | "Çıktım" ve "Döndüm" düğmeleri | Katılımcılar |
| Balık | Av günlüğü | Katılımcılar |
| Oyun, spor | Yalnızca bilgi alanları | — |

- Plaka isteğe bağlıdır (sunucu 30 günde siler).
- Yürüyüşte dönmeme alarmı sunucudadır.
- Av günlüğünde mera gizliliği sunucunun alanlarına göre gösterilir.
- Organizatörün katılım düzeltmesi katılımcılar listesindedir.

### 7. Paketleme

Üç iş paketi:
1. **Duyurular ve ana sayfa bölümleri.** Etkinlik kartı salt okunur.
2. **Etkinlik çekirdeği:** liste, detay, katılım, katılımcılar, takvim,
   sihirbaz, harita seçici, düzenleme, iptal, tekrar.
3. **Varış bildirimi ve türe özel araçlar.** 2'den sonra yapılır.

## Gerekçe

- İki bölümlü ana sayfa, tayfanın iki ana sorusunu ("ne zaman, nerede?"
  ve "ne duyuruldu?") ilk ekranda cevaplar.
- Tür seçimi sonraki adımları belirlediği için sihirbaz doğal bir yapı;
  tayfa oluşturmayla da tutarlı.
- Koordinat, varış bildiriminin 300 m kontrolü için şart; harita seçici
  bunu güvenilir biçimde alır. OSM anahtar ve faturalandırma istemez.

## Sonuçlar

- Yeni paketler: `flutter_map` (yanında `latlong2`) ve `geolocator`
  (kesin kural 8; PR'larda gerekçe).
- Android'de konum izni (`ACCESS_FINE_LOCATION` ve
  `ACCESS_COARSE_LOCATION`) manifeste eklenir. CI'daki "yalnızca INTERNET"
  denetimi bu iki iznin gerekçesiyle güncellenir. iOS'ta kullanım
  açıklaması metni iOS işiyle gelir.
- Aydınlatma metnine OSM ve Nominatim'e IP adresi ve bakılan bölge
  aktarımı eklenir.

## Değerlendirilen alternatifler

- **Tek akış ya da sekmeler:** platform sahibi iki bölümü seçti.
- **Tek uzun form:** tür değişince alanlar yer değiştirir; sihirbaz
  seçildi.
- **Google Maps:** anahtar ve faturalandırma ister.
- **Metin ve harita linki:** paket gerektirmez, ama koordinatı güvenilir
  biçimde almak zahmetli.

## Notlar

- **2026-11-11 (platform sahibi, issue #38 / PR #39):**
  1. **Saat.** Etkinlik zamanları cihazın saat diliminde gösterilir ve
     girilir. Cihaz UTC+3 değilse saat diliminin adı belirtilir. Bu
     ADR-0008 ile uyumludur ve §3'teki "Europe/Istanbul" ifadesinin yerini
     alır. Tekrar kuralının `time_zone`'u `Europe/Istanbul`'dur. Sonu bir
     günle verilen tekrarın `UNTIL`'i o günün sonudur (Türkiye saati).
  2. **Katılımcı ve organizatör adları.** Sözleşmede katılımcı listesi
     yalnızca `user_id` döndürür. Ad, profil ucundan
     (`GET /v1/users/{id}/profile`) bir bellek önbelleğiyle alınır
     (`core/kullanici/`):
     - Ad yalnızca ekrana gelen satır için istenir.
     - Aynı kimlik için istekler tek uçuşta birleşir; aynı anda en çok
       dört profil isteği yapılır.
     - Önbellek oturum boyunca yalnızca bellekte tutulur (ADR-0006) ve
       oturum değişince sıfırlanır.
     - Bulunamayan kullanıcı "Silinmiş kullanıcı" olarak gösterilir;
       başka hatalar önbelleğe alınmaz.
     - Kullanım büyüyünce sözleşmeye `display_name` eklenmesi yeniden
       değerlendirilir.
  3. **Türe özel form alanları.** Bu alanlar şimdilik oluşturma
     sihirbazında, türe göre `switch` ile yazılır. Bu, ADR-0002'deki
     `EtkinlikTuru.formAlanlari` kaydından bir sapmadır. Gerekçe:
     arayüzün `formAlanlari(BuildContext)` imzası sihirbaz durumunu
     taşıyamaz. Detaydaki `aracBolumu` kancası kayıttan bağlıdır.
  4. **Konvoy rotası** (`ConvoyDetailsInput.route`) sihirbazda girilmez;
     §7'deki 3. paketle (türe özel araçlar) gelir.
- **2026-11-11 (PR #42):**
  - `EtkinlikTuru.aracBolumu` artık etkinlik kimliği yerine `Event` alır,
    çünkü türe özel araçlar tayfa kimliğine ve tek etkinlik yanıtındaki
    ayrıntılara ihtiyaç duyar. Ortak taban `KayitliEtkinlikTuru`.
  - Yürüyüşte "Geldim" gösterilmez; katılım "Çıktım" ile doğrulanır.
  - Organizatör düzeltmesi yalnızca bitişten sonraki 7 gün içinde gösterilir.
  - Kamp malzemesine kişi atama arayüzü yoktur; atanmışsa gösterilir.
  - Oturumdaki kullanıcının kimliği profil ucunun `self` alanından ad
    önbelleğiyle öğrenilir ("kendi aracım" gibi ayrımlar için; yetki kararı
    değildir).
  - Android izinleri: INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION.
    Arka plan konumu ve ön plan servisi izinleri `tools:node="remove"` ile
    engellenir. `USE_BIOMETRIC` ve `USE_FINGERPRINT` de kaldırılmıştır;
    Google girişi bunlar olmadan telefonda doğrulanmalıdır. CI, izinleri
    derlenen APK'dan denetler.
- **2026-11-12 (issue #113, Tayfam-Api #150):**
  - Oturumdaki kullanıcının kimliği artık `GET /v1/me/account`'un
    `user_id` alanından okunur (`kendiKimligimProvider`, yalnızca bellekte,
    oturum değişince yeniden). `kendisiMiProvider` bununla karşılaştırır;
    profil ucunun `self` alanına ve ad önbelleğine dolaylı başvuru
    kalktı. Ad önbelleği yalnızca adı tutar.
  - Profil ucu ad ve avatarı ortak tayfa ya da arkadaşlık olmadan da
    döndürür; engel ya da silinmiş hesapta `user-not-found`. Bildirim
    kartında bu durumda ad yerine "Biri" yazılır.
- **2026-11-13 (platform sahibi, sohbette; tayfa ana sayfası yeniden
  tasarımı, Notion: Proje Planı §4 madde 5):** Ana sayfa §1'den şu üç
  noktada sapar; sapmalar onaylıdır.
  1. **Sıradaki etkinlik ve katılım ana sayfadan.** Mor üst bölüme taşan
     büyük "Sıradaki" kartı: iptal edilmemiş ve bitmemiş en yakın
     etkinlik; tür çipi, geri sayım ("3 gün sonra", cihazın saat
     diliminde takvim gününe göre), gün ve saat, yer, gelen/kontenjan
     çubuğu ve **Geliyorum / Belki / Gelmiyorum** düğmeleri. Katılım
     cevabı detaya gitmeden verilir; mantık detaydakiyle aynıdır (sunucunun
     kaydettiği cevap ve sayıların yerel tahmini hemen, ardından liste
     yeniden okunur). Kontenjan doluysa yeni bir davranış yoktur: detaydaki
     gibi "Geliyorum" seçilir, sunucu bekleme listesine alır; kartta
     "Kontenjan dolu …" ya da "Bekleme listesindesin …" yazar. Altında
     "Yaklaşan" bölümünde sonraki iki etkinliğin kısa satırı (tarih kutusu,
     "Tür · gün saat · yer", cevap ya da "Cevap ver").
  2. **Tek "Oluştur" düğmesi.** Bölümlerdeki "Etkinlik aç" / "Duyuru yaz"
     kısayolları kaldırıldı; sağ alttaki "Oluştur" alttan sayfayı açar:
     Etkinlik aç, Duyuru yaz, Anket aç, Soru sor ve Tayfaya davet et.
     Seçenekleri modüller `TayfaModule.olusturmaSecenegi` ile verir;
     görünürlüğü sunucunun alanlarından (rol, `members_can_create_events`)
     türetilir, yalnızca sadeleştirir (kesin kural 5). Boş bölümde yalnızca
     kısa boş durum metni kalır. Bölümler kısaldı: Duyurular sabitlenenler
     ve son 2, Açık anket 1, Son sorular 2 (kısa satır, "3 cevap · dün").
     Duyurularda yazar adı gösterilmez (sözleşmede yalnızca kimlik var).
  3. **Yeni tayfada "Tayfanı birlikte kuralım".** Yöneticiye, tayfa
     açılalı 7 gün olmadıysa (`created_at`) ya da tayfayı bu oturumda
     kendisi oluşturduysa; eski davet kısayolunun yerine geçer. Adımlar:
     kuruldu (her zaman tamam), arkadaşlarını çağır (davet linki + kodu
     kopyala; `member_count > 1` olunca tamam), açık modüllerin adımları
     (`TayfaModule.kurulumAdimi`: ilk etkinlik — en az bir yaklaşan
     etkinlik; bir duyuru sabitle — sabitlenmiş duyuru). Tamamlanma
     yalnızca sunucu verisinden hesaplanır, diske yazılmaz; hepsi tamamsa
     kart gizlenir. Kurulum döneminde üye sayısı 3'ün altındaysa "7 günde 3
     üye" kuralı yazılır (Notion: Proje Planı §7).
  - Yöneticiye ve moderatöre bekleyen katılım isteği satırı
    (`pending_join_request_count`); dokununca katılım istekleri açılır.
  - Silme planlanmış tayfanın durum şeridi mor yüzeyde ink kutudur;
    yöneticiye "Silmeyi iptal et" gösterilir (kayıtla bağlanan düğme,
    `tayfaSilmeIptaliProvider`). Tayfa sekmesindeki modül alt gezinmesi
    kaldırıldı (bkz. ADR-0003 Notlar 2026-11-13).
- **2026-11-13 (platform sahibi, sohbette; issue #146, PR #147 ve
  sihirbaz PR'ı): etkinlik detayı ve sihirbaz yeniden tasarımı.** Tasarım:
  Etkinlik-Detay, -Koyu, -Gunu, -Dolu, -Iptal, -Menu, -Katilimcilar,
  -Turler; Sihirbaz-Tur, -Koyu, -Bilgi, -Yer, -Harita, -Ayrinti, -Turler,
  -Rota, -Tekrar, -Tekrar-Tarih, -Onizleme. Notifier, depo, katılım,
  varış, konum, takvim, RRULE ve harita mantığı değişmedi; arayüz yeniden
  giydirildi. Aşağıdaki maddeler §3'ün "Detay" listesinden ve "dört
  adım"ından **sapar**; sapmalar onaylıdır.
  1. **Detay düzeni (§3 "Detay"ın yerini alır).** Üst bölüm etkinlik
     türünün renginde (tür kaydındaki renk; kapak görseli varsa kapak ve
     koyu perde; iptalde nötr zemin ve "İptal edildi" çipi): geri ve ⋯,
     ink zeminli tür çipi, geri sayım çipi ("2 gün sonra", "Yarın",
     "Bugün · 25 dk sonra", "Şimdi", "Bitti"; takvim gününe göre, cihazın
     saat diliminde), başlık ve tayfa adı. Üst bölüme taşan **özet
     kartı**: tarih ve saat, buluşma noktası adı + "ilçe, il" (yer
     gizliyse "Yer bilgisi yok"), organizatör ve katılım (Geliyorum /
     Belki / Gelmiyorum, gelen/kontenjan çubuğu, bekleme listesinde
     "Sırada"); iptal ya da bitmişte düğmeler yerine "artık cevap
     verilemez", iptal gerekçesi tint-nar kutuda. Varış penceresinde
     "Geldim" kartı özet kartının hemen altındadır (§5 kuralları aynen).
     Sonra buluşma noktası haritası ya da çevrimiçi bağlantı, açıklama,
     türe özel bölümler (bilgi ızgarası ve liste kartları), katılımcı
     özeti ve seri notu.
  2. **Takvime ekle** üst çubuktan özet kartının tarih satırına taşındı
     (simge düğmesi; `.ics` akışı aynı).
  3. **Katılımcılar ayrı ekranda** (§3'teki "katılımcılar listesi" ve §6'daki
     "Organizatörün katılım düzeltmesi katılımcılar listesindedir"
     detaydan çıktı): `/t/<tayfaId>/etkinlikler/<etkinlikId>/katilimcilar`;
     durum çipleri (Geliyor / Belki / Bekleme listesi / Gelmiyor;
     "Gelmiyor"un sayısı sözleşmede olmadığı için yazılmaz), "Katıldı"
     etiketi, organizatöre bitişten sonraki 7 gün bilgi kutusu ve satırda ⋯
     ile düzeltme. Detayda yalnızca özet: gelenlerin ilk 5 avatarı (ilk
     sayfadan), "N kişi geliyor", "K belki · W bekleme listesinde".
  4. **⋯ alttan sayfa** (ADR-0004 Notlar 2026-11-13, madde 5'teki
     kullanım listesi genişledi): `caller_can_manage` ise Düzenle (seride
     "Seride yalnızca bu etkinlik değişir") ve yıkıcı "Etkinliği iptal
     et"; değilse ve etkinlik kendi değilse Şikâyet et. Yönetebilen
     kullanıcıya şikâyet seçeneği artık gösterilmez.
  5. **Sihirbaz beş adım** (§3'teki "dört adım"ın yerini alır): 1 tür,
     2 başlık ve zaman, 3 yer, 4 ayrıntılar (türe özel alanlar, kontenjan,
     tekrar), **5 önizleme** ("Her şey doğru mu?"). Önizlemedeki her
     satırın "Değiştir"i ilgili adıma götürür, oradan "İleri" önizlemeye
     döner; sunucu hatası önizlemede gösterilir. Üstte X (girilen bir şey
     varsa "Vazgeçilsin mi?"), "Adım n / N" ve parçalı ilerleme çubuğu;
     altta sabit Geri ve İleri. Düzenlemede tür adımı yoktur (tür
     değişmez), bu yüzden dört adımdır; seri notu her adımın üstündedir.
     `client_request_id` ve doğrulama kuralları aynen.
  6. **Tür adımı:** tayfanın ilgi alanlarındaki türler "Tayfanın ilgi
     alanları" başlığıyla önce, diğerleri "Diğer türler" altında; iki
     sütunlu kutular, her türün kısa açıklaması. **Zaman** iki büyük kutu
     (gün küçük, saat büyük; bitiş aynı günse "Aynı gün"). **Yer:**
     Yüz yüze / Çevrimiçi iki parçalı seçici, buluşma noktası kartı, il ve
     ilçe yan yana. **Kontenjan** sayaç ve "Sınırsız" anahtarı ("boş =
     sınırsız" kuralı). Türe özel alanlar seçim çipleriyle (kamp su ve
     tuvalet, yürüyüş zorluğu 1–5, balıkta nokta görünürlüğü, oyun
     platformu, spor dalı).
  7. **Tekrar ekranı** (4. adımdaki "Tekrar" satırı açar; §3'teki
     "Tekrar, 'Her hafta / Her ay', aralık ve bitiş seçimleriyle verilir"
     ayrı ekrana taşındı): sıklık, aralık sayacı, "Ne zaman bitsin?" ve
     seçimi düz Türkçe özetleyen kutu ("Her cumartesi 08:30, 6 kez: son
     etkinlik 19 Aralık."). Özet RRULE'un açacağı etkinliklerden istemcide
     hesaplanır (`tekrarAnlari`; aylıkta o günü olmayan aylar atlanır ve
     sayılmaz). Sayaç sınırları sözleşmeninkilerdir (aralık 1–52, sayı
     1–500, son gün en çok beş yıl); tasarımdaki 1–12 ve 2–52 öneriydi.
  8. **Rota çizme ekranı** tam ekran harita: noktalar numaralı daireler
     (başlangıç ve bitiş büyük, bitiş koyu) ve mor çizgi; alt panelde
     nokta sayısı, "En çok 500 nokta", "Son noktayı sil", onaylı
     "Temizle" ve "Rotayı kaydet". **Harita seçici** tam ekran: geri ve
     içinde "Ara" düğmesi olan arama alanı, ipucu, altta "Bu noktayı
     seç"; §4'teki Nominatim ve OSM kuralları aynen.
  9. **Etkinlik sohbeti girişi** (Etkinlik-Sohbet) tasarlandı ama
     kodlanmadı: etkinlik kanalı sözleşmede yok, Tayfam-Api #183
     bekleniyor (ADR-0018 §2'deki kural).
  - Yeni ölçüler (`TayfamSizes`): `ilerlemeParcasi` (6), `sayacGenisligi`
    (240), `rotaUcNoktasi` (28), `rotaAraNoktasi` (22), `turKutusu`
    (112), `seciliIsareti` (24).
  - Kapak fotoğrafı alanı mevcut `FotografAlani` bileşeniyle kaldı;
    tasarımdaki kesik çizgili alan ayrı bir bileşen işidir.
- **2026-11-13 (platform sahibi, sohbette; issue #154): duyuru ekranları
  yeniden tasarımı.** Tasarım: Duyurular, Duyuru-Detay, Duyuru-Menu,
  Duyuru-Form (`docs/tasarim/15-duyuru-anket-soru-cevap/`). Liste,
  detay, sabitleme, silme ve form mantığı değişmedi; arayüz yeniden
  giydirildi. §2'ye şu maddeler eklenir:
  1. **Liste:** başlıkta tayfa adı ve yönetimde "Duyuru yaz" (tint hap).
     Sabitlenenler mango kenarlı kartla üstte, ardından "Son duyurular"
     kartları: "Sabitlendi" etiketi, kısa tarih ("Bugün 11:05", "8 Kas"),
     başlık ve metnin ilk iki satırı.
  2. **Yazar yalnızca detayda** (platform sahibi kararı): avatar + ad, ad
     önbelleğinden (Notlar 2026-11-11 madde 2); yazar yoksa "Silinmiş
     kullanıcı". Listede ve ana sayfada yazar adı yoktur. Tarihin yanında
     `updated_at` > `created_at` ise "düzenlendi" yazar.
  3. **⋯ alttan sayfa** (ADR-0004 Notlar 2026-11-13 madde 5'teki kullanım
     listesine eklenir): yönetimde Düzenle, Sabitle / Sabitlemeyi kaldır
     ve yıkıcı Sil (onay penceresinde dolu yıkıcı düğme); üyede, duyuru
     kendi değilse Şikâyet et.
  4. **Form** tam ekran: X, başlık, sağ üstte "Yayınla" / "Kaydet";
     başlık ve metin sayaçlı; altta düz metin notu. Yeni duyuruda
     yönetime "Yayınlayınca sabitle" anahtarı: sözleşmede oluşturma
     isteğinde `pinned` olmadığı için önce `POST …/announcements`, sonra
     `PUT …/pin` yapılır. Sabitleme başarısız olursa duyuru yayınlanmış
     sayılır (form kapanır, ikinci duyuru açılmaz) ve "yayınlandı ama
     sabitlenemedi" bildirimi gösterilir.
  - **Sözleşme boşluğu:** `Announcement.updated_at` sözleşmeye göre
    sabitleme ve sabitlemeyi kaldırmada da değişir. Bu yüzden "düzenlendi"
    metni hiç düzenlenmemiş ama sabitlenmiş (ya da "Yayınlayınca sabitle"
    ile yayınlanmış) duyuruda da görünür. Ayrı bir `edited_at` alanı Tayfam-Api'de
    değerlendirilmelidir; o zamana kadar README'deki kural uygulanır.
