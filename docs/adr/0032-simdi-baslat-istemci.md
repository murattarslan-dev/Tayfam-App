# ADR-0032: Şimdi başlat (istemci, v3)

- **Durum:** Kabul edildi (platform sahibi, 2026-11-18, sohbette)
- **Tarih:** 2026-11-18
- **Karar veren:** Murat Arslan (2026-11-18 sohbeti). Ürün kararları Notion
  "Faz 3 — Katalog ayrıntıları ve şema ekleri (2026-11-18)" §D'dedir.
- **İlgili:** [ADR-0003](0003-gezinme-iskeleti.md),
  [ADR-0019](0019-push-bildirimleri.md),
  [ADR-0020](0020-birebir-uctan-uca-sifreleme-istemci.md) (QR tarayıcı),
  [ADR-0026](0026-anlik-etkinlik-istemci.md),
  [ADR-0031](0031-katalog-bilesen-ekleri.md); Tayfam-Api ADR-0038
- **Değiştirdiği:** ADR-0026 §1 (anlık sihirbazın yanına tek ekranlı şimdi
  akışı). ADR-0026'ya revizyon notu düşüldü.

## Bağlam

Anlık etkinlik sihirbazı (ADR-0026) altı adımdır ve en erken bir sonraki
tam saat + 1'i önerir; doğaçlama anı ("masa kurduk, yazboz lazım")
karşılamaz. Tayfam-Api ADR-0038 `starts_now`, QR ile katılım ve şimdi
bildirimini ekledi.

## Karar

### 1. Giriş noktaları

- Tayfa ana sayfasında ve etkinlik listesinde **"Şimdi başlat"** düğmesi
  (sunucu `EventCreateNow` iznini doğrular; istemci rolü yalnızca düğmeyi
  sadeleştirmek için kullanır).
- Tayfa sekmesindeki "+" menüsünde "Şimdi başlat (arkadaşlarla)" → anlık.
- "Boşum" rozetindeki "Bir şey yapalım" (ADR-0026) bugün için açılırsa
  şimdi akışını önerir; başka gün için bugünkü sihirbaz.

### 2. Tek ekran

Adres `/simdi?tayfa=<id>` (tayfa yoksa anlık), kabuğun üstünde tam ekran.

- **Tür:** son kullanılan 6 tür (bellekte; diske yazılmaz, ADR-0006) +
  "Tüm türler" (ADR-0024 §4 listesi). Varsayılan Genel.
- **Başlık:** isteğe bağlı; boşsa ARB'den üretilir
  (`simdi_varsayilan_baslik`: "{ad}'ın {tür}").
- **Yer:** yüz yüze ise yer seçici cihaz konumuyla açık başlar (konum izni
  yalnızca bu an istenir); kullanıcı haritada onaylar. Konum izni yoksa
  bugünkü yer seçici. Online seçilirse bağlantı alanı.
- **Bileşenler:** türde `optional` bileşen varsa aç/kapa satırları
  (ADR-0031 §1); `organizer_choice` varsayılanla gider.
- **Kimler duysun:** tayfa içinde bilgi satırı ("Tayfa üyelerine haber
  verilecek"); anlık için arkadaş seçici (§4).
- Gönder: `starts_now: true`, `client_request_id` ekran açılınca bir kez
  üretilir. Başarıda doğrudan etkinlik detayı açılır ve **QR sayfası**
  önerilir (yüz yüze ise).

### 3. Etkinlik detayında "sürüyor" hali

- Üstte "Şu an sürüyor" bandı ve organizatöre **Bitir** düğmesi (onay
  penceresiyle). Açık uçlu etkinlikte bitiş saati yerine "en geç {saat}"
  gösterilir.
- **QR sayfası** (organizatör, tayfa etkinliğinde yöneticiler): token
  süresi dolmadan (2 dk) otomatik yenilenir; ekran parlaklığı artırılır,
  ekran açık tutulur. Token yalnızca bellektedir; ekran görüntüsü
  engellenmez ama süre zaten kısadır.
- **QR okutma:** cihaz bağlamadaki ZXing tarayıcısı (ADR-0020, kamera
  izni yalnızca okuturken) yeniden kullanılır; okunan değer
  `tayfam.app/q#<token>` biçiminde değilse reddedilir. Token yalnızca
  istek gövdesinde gider, hiçbir yere yazılmaz (kesin kural 9 ile aynı).
  Sonuç: katıldın / katılım isteği gönderildi / geçersiz QR.
- Telefon kamerasıyla okutulan `tayfam.app/q#…` derin linki uygulamayı
  aynı akışa açar. **Kesin kural 9'a yeni yol eklenmesi** CLAUDE.md
  değişikliğidir (platform sahibi) ve `shell/derin_link/` hassas alandır.

### 4. Arkadaş seçici (anlık)

- Liste önceden dolu gelir: bugün "Boşum" demiş arkadaşlar (rozetli),
  sonra arkadaş listesinin sunucu sırası (arkadaşlık puanı; Tayfam-Api
  ADR-0030 §12). En fazla 30 seçili; üst sınır sayaçla gösterilir.
- "Şimdi bildirimlerini kapatmış" arkadaşlar sunucudan işaretli gelmez;
  istemci ayrıca tahmin etmez.
- Günlük 2 yayın sınırı aşılırsa `now-limit-reached`: etkinlik yine
  açılabilir, bildirim gitmez; ekran bunu açıkça söyler.

### 5. Bildirim ve ayarlar

- `now_started` push'u yalnızca çeviri anahtarıyla gelir
  (`push_now_started_title/_body`); dokununca etkinlik adresi açılır ve
  detay REST'ten çekilir (ADR-0019 akışı).
- **Tayfa bildirim ayarları**na "Şimdi bildirimleri" aç/kapa satırı
  (`tayfa_now`).
- **Profil → Gizlilik**'e "Arkadaşlarımdan şimdi bildirimleri: Herkes /
  Yakın arkadaşlarım / Kapalı". Profilleme kapalıysa "Yakın arkadaşlarım"
  seçeneği açıklamayla pasif ("Profilleme kapalıyken yakın arkadaş
  belirlenemez").
- **Tayfa ayarları → Etkinlikler**'e "Şimdi başlatabilenler: Üyeler /
  Moderatörler / Yalnızca yöneticiler" (yalnızca yöneticiye).

### 6. Testler

- Şimdi ekranı: tür/başlık/yer doğrulaması, `starts_now` gövdesi, tekrar
  gönderimde aynı `client_request_id`.
- QR: token yenileme zamanlayıcısı (sahte saat), yanlış alan adı/yol
  reddi, token'ın log ve depoya yazılmadığı.
- Arkadaş seçici: ön sıralama, 30 sınırı, `now-limit-reached` durumu.
- Her ekran açık ve koyu temada, 2× yazı ölçeğinde.

## Gerekçe

- **Tek ekran:** Doğaçlamada her adım bir vazgeçme noktasıdır; zaman ve
  bitiş sunucuda belirlendiği için sorulacak şey tür ve yerden ibarettir.
- **Mevcut tarayıcı:** Yeni QR paketi eklenmez; ML Kit'e veri gitmez
  (ADR-0020 kararı korunur).

## Sonuçlar

- Yeni özellik klasörü `features/etkinlik/presentation/simdi/` ve QR
  sayfası; derin link yolu (CLAUDE.md ve `shell/derin_link/`, platform
  sahibi).
- ARB: şimdi akışı metinleri, push anahtarları, ayar satırları, problem
  tipleri `invalid-join-qr`, `now-limit-reached`.

## Değerlendirilen alternatifler

- **Sihirbaza "şimdi" seçeneği eklemek:** Reddedildi; adım sayısı
  doğaçlama için asıl engel.
- **QR yerine yakın cihaz keşfi (Bluetooth/Nearby):** Reddedildi; ek izin,
  platform farkları ve konum benzeri veri.

## Notlar

- **#249 (sözleşme, Tayfam-Api #307):** §4'teki günlük yayın sınırının
  hata kodu `now-broadcast-limit-reached`'tir (`now-limit-reached` kişi
  başı tek açık şimdi etkinliği sınırıdır). Sınır aşılınca sunucu hiçbir
  şey açmaz; ekran bunu söyler ve "Bildirimsiz başlat"ı önerir (aynı
  `client_request_id` ile `now_recipient_ids`'siz yeniden gönderim). Böylece
  §4'teki "etkinlik yine açılabilir, bildirim gitmez" tek dokunuşla
  karşılanır. `now_started` bildirimi anlık etkinlikte bir davettir:
  alıcı tayfanın etkin üyesi değilse satırda "Katıl"
  (`/v1/me/invitations/{tayfa_id}/acceptance`) ve dokununca gelen davetler
  açılır; üyeyse etkinlik detayı. Şimdi bildirimleri kapalı tayfalar
  Profil → Bildirim ayarları'nda ayrıca listelenir ve oradan açılır.
