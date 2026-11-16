# ADR-0025: Etkinlik fotoğraf albümü (istemci)

- **Durum:** Kabul edildi (mimari oturumu, 2026-11-16; PR #202'deki sorular cevaplandı)
- **Tarih:** 2026-11-16
- **Karar veren:** Ürün kararları platform sahibinindir (2026-11-15, Notion
  "Faz 2 (v2) — Medya ve Sosyal" §2, §9; issue #195). Bu ADR onların
  istemci mimarisine taşınmasıdır.
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md),
  [ADR-0005](0005-api-istemcisi.md),
  [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md),
  [ADR-0015](0015-etkinlik-ve-duyuru-modulleri.md),
  [ADR-0021](0021-fotograf-yukleme-ve-goruntuleme.md);
  Tayfam-Api ADR-0028 (sözleşme: PR #213); tasarım
  [`docs/tasarim/25-etkinlik-albumu/`](../tasarim/25-etkinlik-albumu/README.md)

## Bağlam

Tayfam-Api ADR-0028 etkinliğe albüm ekledi: `GET/POST
.../events/{event_id}/photos`, `DELETE .../photos/{photo_id}`, yükleme
amacı `event_photo`, şikâyet hedefi `event_photo` ve yeni hata
`album-closed`. Yükleme yalnızca katılımı doğrulanmış (`attended`)
kişiye, başlangıçtan bitiş + 7 güne kadar açıktır; kişi başı 30, albüm
başına 500 fotoğraf. Liste link taşımaz; linkler `POST /v1/media/urls`
ile alınır.

ADR-0021 tek fotoğraflık bir form alanı (`FotografAlani`) kurmuştu.
Albümde kişi bir seferde birçok fotoğraf ekler; bu da seçicinin çoklu
seçimini, yükleme sırasının bellekte tutulmasını ve tam ekran
görüntüleyiciyi gerektirir.

## Karar

### 1. Yer ve veri

- Albüm `features/etkinlik/` içindedir (etkinliğin parçası; ayrı özellik
  değil): `data/etkinlik_deposu.dart` (üç uç), `application/etkinlik_albumu.dart`
  (liste ve yükleme kuyruğu), `presentation/album_*.dart`.
- Liste `SayfaliListeNotifier<EventPhoto>`'dur (`family(etkinlik)` +
  `autoDispose`), sayfa boyutu 60, eskiden yeniye. Detaydaki önizleme
  aynı sağlayıcının ilk sayfasının ilk 6 öğesidir. Linkleri `MedyaGorseli`
  toplu uçtan alır (aynı turdaki kimlikler tek istekte; ADR-0021 §5).
- Adres: `/t/<tayfaId>/etkinlikler/<etkinlikId>/album`. Görüntüleyici
  `Navigator` ile tam ekran açılır (adresi yoktur; içerik albüm
  listesinin bellekteki hâlidir, derin linkle açılmaz).

### 2. Çoklu seçim

- `FotografSecici`'ye `secCoklu(enCok)` eklenir: `image_picker`'ın
  `pickMultiImage(limit:, requestFullMetadata: false)`'ı (yeni paket yok,
  izin yok; Android Photo Picker, iOS PHPicker). Kamera tek fotoğraftır.
- Seçici her fotoğrafı geçici klasöre kopyalar. Seçim
  `SecilenFotograf` tutamaçları olarak döner: `oku()` baytları belleğe
  alır ve o kopyayı **hemen siler**; `birak()` okunmayan kopyayı siler.
  Hazırlık sırayla yapılır, böylece bellekte aynı anda yalnızca bir ham
  fotoğraf bulunur; hazır görüntüler (tam ≤ 1600 px + önizleme) kalır.
  Vazgeçilince okunmamış kopyalar silinir (ADR-0006, ADR-0021 §1).
- Hazırlama ADR-0021 §2–3'ün aynısıdır (EXIF/GPS dahil bütün metadata
  silinir, denetçiden geçmeyen gönderilmez).

### 3. Yükleme kuyruğu (yalnızca bellek)

- `albumYuklemeProvider(etkinlik)`: hazır görüntülerin sırası. Her öğe iki
  `client_request_id` alır (yükleme ve albüme ekleme); tekrar denemede
  ikisi de aynı kalır (ADR-0005). Yükleme tamamsa tekrar deneme yalnızca
  ekleme adımını yineler.
- Öğeler sırayla işlenir: `MedyaYukleyici.yukle(event_photo, tayfaId)` →
  `POST .../photos` → albüm listesinin sonuna eklenir; baytlar medya
  önbelleğine konur (yeniden indirilmez).
- `album-closed`, `not-attended`, `event-limit`, `event-cancelled` bütün
  albüm için geçerlidir: gelen öğe ve sıradaki öğeler aynı hatayla durur,
  tekrar denenmez, istek gönderilmez; etkinlik sessizce yeniden okunur.
  Bağlantı, zaman aşımı, depo ve 5xx hataları tekrarlanabilir ("Tekrar
  dene"); ret ve hazırlama hataları tekrarlanamaz ("Kaldır").
- Kuyruk doluyken sağlayıcı `keepAlive` ile yaşar (detaydan çıkılsa da
  yükleme biter), boşalınca bırakılır. Oturum kapanırsa (`OturumYok`)
  kuyruk boşaltılır. Hiçbir şey diske yazılmaz; uygulama kapanırsa kuyruk
  kaybolur (sunucudaki bağlanmamış yükleme 7 gün sonra silinir).

### 4. Yetki ve görünürlük (kolaylık; karar sunucunun, kesin kural 5)

- "Fotoğraf ekle": iptal edilmemiş, katılım `attended`, şimdi
  `[starts_at, ends_at + 7 gün)` içinde.
- "Fotoğrafı sil": kendi fotoğrafı, yönetim (moderatör/yönetici) ya da
  etkinliğin organizatörü (`created_by_user_id` kendisi).
- "Şikâyet et": kendi fotoğrafı değil ve fotoğrafı silemiyor. Silebilen
  (yönetim ya da organizatör) şikâyet etmez, siler (ADR-0018 §8'in
  albüme genişletilmesi; 2026-11-16).
- Sunucunun reddi `type`'a göre çevrilir; albüme özel dört metin
  `albumHataMetni` ile, gerisi ortak eşlemeden.

### 5. Görüntüleyici

- `PageView` + `InteractiveViewer`; tam varyant `MedyaGorseli` ile
  (`Image.memory`, ağ görseli yok). Her temada koyu yüzey (tema koyu
  token'larla yeniden kurulur). Önceki/Sonraki düğmeleri kaydırmanın
  alternatifidir; sona 3 fotoğraf kala sonraki sayfa okunur.
- Açıklama düz metindir (bağlantı/markdown yorumlanmaz).

### 6. İncelemede alınan kararlar (2026-11-16)

PR #202'deki sorular cevaplandı: bölüm anketlerden sonra, Katılımcılar'dan
önce ve önizlemede 6 fotoğraf; açıklama yalnızca tek fotoğrafta;
görüntüleyici her temada koyu; dört alan hatası kuyruğu durdurur;
silebilen (organizatör dahil) şikâyet etmez; uygulama kapanınca kuyruğun
kaybolması kabul (ADR-0006); okunmamış sayfa varken yeni fotoğraf son
sayfayla görünür.

## Gerekçe

- Çoklu seçim kişinin bir etkinliğin fotoğraflarını tek seferde
  eklemesinin doğal yoludur; aynı paketin çoklu yöntemi yeni paket ve izin
  getirmez.
- Sıralı hazırlık ve okunur okunmaz silinen geçici kopyalar, bellek ve
  disk izini en aza indirir.
- Alan kuralı hataları (pencere, katılım, sınır, iptal) sonraki öğelerde
  de aynıdır; kuyruğu durdurmak boşuna yükleme ve kotayı korur.

## Sonuçlar

- Yeni paket ve izin yok. `FotografSecici` arayüzüne bir yöntem eklenir.
- Yeni ARB anahtarları (`album_*`, `hata_album_closed`).
- Uygulama yükleme sırasında kapatılırsa kuyruk kaybolur (diske yazmama
  kararının bilinen bedeli).

## Değerlendirilen alternatifler

- **Her fotoğraf için ayrı form (FotografAlani):** 30 fotoğrafta 30 kez
  açılır; reddedildi.
- **Paralel yükleme:** saatlik 30 yükleme sınırı ve mobil bağlantıda
  kazancı küçük, hata yönetimi karmaşık; sıralı seçildi.
- **`cached_network_image` ile ızgara** (ui-ux-pro-max önerisi): görüntüyü
  diske yazar (ADR-0006) ve adres log'a girebilir (ADR-0021 §5);
  kullanılmaz.
- **Görüntüleyiciyi adresle açmak:** fotoğraf kimliği adreste olurdu ve
  listenin dışından açılınca sayfalama bozulurdu; gerek görülmedi.

## Notlar

- **2026-11-16 (issue #208; platform sahibi PR #206 açık sorusu 3'te
  onayladı):** §5'teki görüntüleyici iskeleti (koyu yüzey, ✕, ⋯ kancası,
  `PageView` + `InteractiveViewer`, alt bilgi, Önceki/Sonraki, hareketi
  azalt) sohbetinkiyle (ADR-0028) birlikte `core/bilesenler/`'deki ortak
  `TamEkranFotograf`'a taşındı. Albüme özgü olanlar (sayaç, sil/şikâyet
  menüsü, yükleyen ve açıklama, sona 3 kala okuma) etkinlik özelliğinde
  kaldı. Davranış değişmedi; yeni karar yoktur.
