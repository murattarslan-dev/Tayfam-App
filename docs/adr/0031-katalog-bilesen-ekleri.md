# ADR-0031: Katalog bileşen ekleri — kronometre, masa, misafir, sözlük ve seçimler (istemci, v3)

- **Durum:** Kabul edildi (platform sahibi, 2026-11-18, sohbette)
- **Tarih:** 2026-11-18 (revizyon 2026-11-23: §7 `vote` kaynakları;
  uygulama notu 2026-11-23, Tayfam-Api #323: §7 `vote` etkileşimi)
- **Karar veren:** Murat Arslan (2026-11-18 katalog oturumu). Ürün kararları
  Notion "Faz 3 — Katalog ayrıntıları ve şema ekleri (2026-11-18)"
  sayfasındadır.
- **İlgili:** [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md),
  [ADR-0008](0008-ceviri-ve-yerel-ayar.md),
  [ADR-0021](0021-fotograf-yukleme-ve-goruntuleme.md),
  [ADR-0024](0024-dinamik-tur-katalogu-ve-bilesen-kaydi.md),
  [ADR-0025](0025-etkinlik-fotograf-albumu.md),
  [ADR-0032](0032-simdi-baslat-istemci.md); Tayfam-Api ADR-0037
- **Değiştirdiği:** ADR-0024 §3 (kayıt listesi, bileşen bağlamı), §4
  (sihirbazda bileşen seçimleri). ADR-0024'e revizyon notu düşüldü.

## Bağlam

Tayfam-Api ADR-0037 tür tanımına `optional`, `organizer_choice`,
`prefill_from`, tür bayrakları (`sensitive_attendance`, `album_notice`),
tayfa sözlüğü, yazbozda masa ve ön ayar, misafir oyuncu ve iki yeni bileşen
(`timer`, `pool_link`) ekledi. ADR-0024'teki bileşen kaydı modeli korunur;
bu ADR eklerin istemcide nasıl karşılanacağını belirler.

## Karar

### 1. Sihirbazda bileşen seçimleri

- Türe özel adım, tanımda `optional` olan bileşenleri **aç/kapa
  satırı** olarak gösterir (varsayılan tanımdan). Kapalı bileşenin form
  bölümü çizilmez.
- `organizer_choice` parametreleri bileşenin form bölümünde **tek seçim**
  (segment ya da liste) olarak çıkar; seçenek adları bileşenin ARB
  anahtarlarındandır (`bilesen_bracket_format_swiss` …). Tanınmayan seçenek
  değeri listelenmez; hepsi tanınmıyorsa varsayılan gönderilir.
- Seçimler etkinlik başlayınca kilitlenir (sunucu da reddeder); düzenleme
  ekranında salt okunur gösterilir.

### 2. Önerilen ölçüm

`prefill_from` olan ölçüm, etkinlik bitince detayda **"Önerilen: 12,4 km —
Onayla / Düzelt"** satırı olarak görünür (yalnızca organizatöre).
Onaylanmamış öneri istatistik ve ana sayfa kartlarında gösterilmez.

### 3. Kronometre (`timer`)

- `features/etkinlik/bilesenler/kronometre/`. Sunucuyla konuşmaz; durum
  yalnızca bellektedir (ADR-0006), ekran kapanınca sıfırlanır.
- Modlar: geri sayım (ön ayar düğmeleri + elle süre), ileri sayım,
  **satranç saati** (iki büyük dokunma alanı, ekranın üst yarısı ters
  döner; tahtanın iki yanındaki oyuncu için).
- Süre bitiminde ses ve titreşim; kronometre ekranı açıkken ekranın
  kapanması engellenir (wakelock yalnızca bu ekranda). Yeni paket
  gerekirse PR'da gerekçelenir (kesin kural 8).
- Tam ekran açılır; etkinlik detayında tek satırlık giriş kartı.
- Kronometre ekranı `TayfamMotion`'daki hareket kuralına tabidir; sayım
  animasyonu yalnızca rakam değişimidir.

### 4. Yazboz: masalar ve misafir oyuncu

- Yazboz bölümü önce **masa listesi** gösterir (masa adı, ön ayar, hakem,
  durum); organizatör "Masa aç" ile ön ayar seçer. Masa ekranı ön ayarın
  `params`'ına göre çizilir (el el tablo, tek maç, ilk N'e, `wdl`).
  Tanınmayan ön ayar parametresi olan masa "Uygulamayı güncelle" gösterir.
- Ön ayar adları katalog metnidir (`labels`; ADR-0024 §2 istisnası).
- **Misafir oyuncu:** oyuncu ekleme sayfasında katılımcılar listesinin
  altında "Misafir ekle" (takma ad, 1–24). Misafir satırı ayrı bir
  işaretle gösterilir; profil bağlantısı yoktur. Skor girişi çevrimdışı
  kuyruğa girmez (ADR-0024 §5 aynen).

### 5. Günlük alanlarında tayfa sözlüğü

- `vocabulary` taşıyan metin alanı **otomatik tamamlamalı** giriş olur:
  yazdıkça `GET …/vocabulary/{namespace}?q=` (300 ms gecikmeli, en az 2
  harf); seçilen değer `vocabulary_id`, yeni değer `value` olarak
  gönderilir. Öneri listesi bellekte, ekran ömrüyle sınırlı.
- **Birleştirme ekranı** (moderatör ve yönetici; sunucu izni doğrular):
  Tayfa ayarları → Sözlükler → ad alanı → değer seç → "Şununla birleştir".
  Onay penceresi birleşmenin istatistiği etkileyeceğini söyler; geri alma
  aynı ekrandan.

### 6. Tür bayrakları

- **`album_notice`:** albüme yükleme akışında (ADR-0025) fotoğraf
  seçildikten sonra onay sayfası: "Yüzü görünenlerden (çocuklarda
  velisinden) izin aldın mı?" — "Evet, izin aldım" ile istek
  `consent_ack: true` taşır. Her yüklemede sorulur; "bir daha sorma" yok.
  `album-consent-required` problem tipi ARB'ye eklenir.
- **`sensitive_attendance`:** etkinlik detayında katılımcı listesi
  organizatör dışındakilere gösterilmez, yalnızca sayı ("12 kişi
  katılıyor"). Profil etkinlik geçmişinde bu türler zaten sunucudan
  gelmez; istemci ayrıca filtrelemez.

### 7. Diğer bileşenler

- **`vehicles` + `seats`:** araç kartında "2 boş koltuk"; katılımcı "Bu
  araçla gelmek istiyorum" der, araç sahibi onaylar. Masraf alanı yok.
- **`vote`:** seçenek kaynağı `album` ise seçenekler albüm küçük
  resimleri, `vehicles` ise araç kartları (plakasız), `participants` ise
  kişiler, `free` ise organizatörün yazdığı etiketlerdir. (`route_stops`
  platform sahibinin 2026-11-23 kararıyla kaldırıldı; durak kartı yoktur,
  Tayfam-Api ADR-0037 §3, #242.) Oy gizlidir: kimin neye oy verdiği hiçbir
  yerde gösterilmez, yalnızca kendi oyun işaretlenir; `results_visible`
  değilken seçenek başına sayı ve kazanan gösterilmez, yalnızca oy veren
  sayısı. Seçenek ekleme/kaldırma yalnızca `free`'de; düğmeler
  `caller_can_vote` / `caller_can_edit_options` / `caller_can_close`'a
  göre.
  Uygulama notu (#242; platform sahibi 2026-11-23'te sohbette onayladı,
  Tayfam-Api #323): oy satıra dokunarak verilir ve onay istemez
  (değiştirilebilir); seçili seçeneğe yeniden dokunmak bir şey yapmaz, oy
  ayrı "Oyumu geri al" bağlantısıyla geri alınır. Seçenek kaldırma ve
  oylamayı kapatma onaylıdır (kapatma geri alınmaz). Kişinin kendi
  seçeneği (kendisi, aracı, fotoğrafı) "Sen" etiketiyle gösterilir ve
  seçilemez (kolaylık; karar sunucuda, `vote-own-option`). Albüm
  seçeneğinin adı listedeki sırasıyla "Fotoğraf N"dir; tam ekran görüntü
  yoktur.
- **`pool_link`:** soru havuzu modülünün ADR'siyle gelir; o zamana kadar
  kayıtta yoktur ("Uygulamayı güncelle" davranışı geçerlidir).

### 8. Testler

- `test/fixtures/katalog.json` yeni bileşenleri, `optional`,
  `organizer_choice`, `prefill_from`, iki tür bayrağını ve en az iki ön
  ayarı kullanacak şekilde genişler.
- Kronometre: üç mod için birim testi (sahte saat), satranç saatinde sıra
  değişimi ve süre bitimi.
- Sözlük girişi: yeni değer / seçilen değer gövdesi; birleştirilmiş değerin
  hedefle gösterimi.
- Albüm onayı: onaysız yüklemenin istek göndermemesi.
- Her yeni ekran açık ve koyu temada, 2× yazı ölçeğinde widget testiyle.

## Gerekçe

- **Kronometre yalnızca cihazda:** Sunucu, olay ve tablo gerekmez; masadaki
  herkes tek telefona bakar. Senkron kronometre ihtiyacı çıkarsa ayrı
  bileşen sürümüyle gelir.
- **Her yüklemede albüm onayı:** Onay, fotoğraftaki kişilere özgüdür;
  bir kez verilmiş onay sonraki fotoğrafları kapsamaz.
- **Sözlük önerileri bellekte:** ADR-0006; içerik diske yazılmaz.

## Sonuçlar

- Yeni bileşen klasörleri: `kronometre`, yazbozda `masa` ve `misafir`
  alt bölümleri; sözlük girişi `core/bilesenler/` altında ortak widget.
- ARB: bileşen seçenek adları, birimler (`night`, `nm`, `box`, `section`,
  `net`), problem tipleri `album-consent-required`, `component-disabled`.
- Tayfam-Api'de en düşük istemci sürümü kaydına `timer` girer.

## Değerlendirilen alternatifler

- **Kronometreyi sunucuda senkron tutmak:** Şimdilik reddedildi; maliyet
  ve WebSocket trafiği, ihtiyaç kanıtlanmadan.
- **Sözlük önerilerini katalogla birlikte indirmek:** Reddedildi; sözlük
  tayfaya özel ve büyüyebilir, yalnızca yazarken gerekir.
