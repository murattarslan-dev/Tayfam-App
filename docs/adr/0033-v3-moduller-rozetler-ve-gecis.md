# ADR-0033: v3 modülleri, rozetler ve tek seferde geçiş (istemci)

- **Durum:** Kabul edildi (platform sahibi, 2026-11-18, sohbette)
- **Tarih:** 2026-11-18
- **Karar veren:** Murat Arslan (2026-11-18). Ürün kararları Notion "Faz 3 —
  Katalog ayrıntıları ve şema ekleri (2026-11-18)" §E.
- **İlgili:** [ADR-0002](0002-modul-yapisi.md),
  [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md),
  [ADR-0015](0015-etkinlik-ve-duyuru-modulleri.md),
  [ADR-0021](0021-fotograf-yukleme-ve-goruntuleme.md),
  [ADR-0024](0024-dinamik-tur-katalogu-ve-bilesen-kaydi.md),
  [ADR-0031](0031-katalog-bilesen-ekleri.md); Tayfam-Api ADR-0039,
  ADR-0040, ADR-0041
- **Değiştirdiği:** ADR-0024 Sonuçlar (geçiş dönemi yok). ADR-0024'e
  revizyon notu düşüldü.

## Bağlam

Tayfam-Api ADR-0039 rozetleri, ADR-0040 dört tayfa modülünü ve ders-konu
listesini, ADR-0041 v3'ün tek seferde yayınlanmasını karara bağladı. Bu ADR
istemci karşılıklarını belirler. Her modül ADR-0002'deki gibi ayrı bir
özellik klasörüdür ve birbirini import etmez; böylece ayrı iş kayıtlarında,
ayrı oturumlarda geliştirilir.

## Karar

### 1. Tek seferde geçiş

- `EventType` enum'u, `etkinlik_turu_kaydi.dart` ve `features/etkinlik/
  turler/` **doğrudan** kaldırılır; geçiş dönemi kodu yazılmaz (Tayfam-Api
  ADR-0041). Sürüm 0.3.0; en düşük sürüm sunucuda aynı anda 0.3.0 olur ve
  eski uygulama bugünkü "Güncelleme gerekli" ekranını gösterir (ADR-0012).
- Faz 3 PR'ları `dev`'e birleşir; iş bitene kadar sürüm PR'ı açılmaz.

### 2. Modül klasörleri

| Modül | Klasör | Ana sayfa kartı | Ekranlar |
|-------|--------|-----------------|----------|
| Ortak kütüphane | `features/kutuphane/` | "Ortak eşya" (son eklenenler, ödünçteki sayısı) | liste (tür filtresi), kalem detayı, kalem formu, ödünç isteği, "Ödünçlerim" |
| Soru havuzu | `features/soru_havuzu/` | son sorular | ders/konu filtresi, soru detayı ve cevaplar, soru ve cevap formu (foto/metin) |
| Materyal kütüphanesi | `features/materyal/` | son eklenenler | ders/konu filtresi, bağlantı ve not formu, dış bağlantı uyarısı |
| Üye garajı | `features/garaj/` (profil) + tayfa kartı | tayfada görünen araçlar | Profil → Garajım, araç formu, tayfa başına görünürlük |

- Her modül `TayfaModule` kaydına ve ana sayfa bileşeni kaydına
  (ADR-0024 §6) kendi dosyasıyla eklenir; görünürlüğe sunucunun `modules`
  alanı karar verir.
- Soru havuzu, Soru-Cevap'ın (`features/soru_cevap/`) dışa açık
  widget'larını kullanabilir; Soru-Cevap soru havuzunu import etmez.
- **Dış bağlantı:** materyalde bağlantıya dokununca alt sayfa: alan adı
  büyük yazılır, "Tayfam dışına çıkıyorsun" ve "Aç"; açma sistem
  tarayıcısında (uygulama içi web görünümü yok). Bağlantı önizlemesi
  yoktur; istemci de bağlantıyı açmadan önce hiçbir istek atmaz.
- **Ders/konu seçici:** katalogdaki `study_tags`'ten (ADR-0024 §1 katalog
  önbelleği) üç seviyeli seçici, `core/bilesenler/` altında ortak widget;
  `retired` etiketler seçilemez ama gösterilir.
- **Garaj ve araçlar bileşeni:** `vehicles` bileşeninin formu "Garajımdan
  seç" listesini gösterir; plaka alanı yalnızca etkinlik formundadır.

### 3. Rozetler

- `features/rozet/`: profilde "Rozetler" bölümü (kişinin kendisine her
  zaman, başkasına sunucu döndürürse), tayfa sayfasında tayfa rozetleri,
  Keşfet vitrin kartında tayfa rozetleri (sunucu döndürürse).
- Rozet adı ve ikonu katalogdan (`labels`, ikon haritası; ADR-0024 §2).
- `badge_earned` uygulama içi bildirimi bildirim listesinde rozet kartı
  olarak; push yok.
- Sıralama ya da sayıya göre liste yok.

### 4. Testler

- Her modül ekranı açık ve koyu temada, 2× yazı ölçeğinde widget testiyle.
- Dış bağlantı uyarısının bağlantıyı onaysız açmadığı; `https` dışı ya da
  sunucunun döndürmediği alan adının gösterilmediği.
- Ödünç akışının durum geçişleri (istemci yalnızca sunucunun döndürdüğü
  durumu çizer).

## Gerekçe

Modüller birbirinden bağımsız klasörlerde olduğu için ajan oturumları aynı
dosyalara dokunmadan paralel çalışır; ortak noktalar yalnızca kayıt
dosyaları ve ARB'dir.

## Sonuçlar

- ARB: modül, rozet ve uyarı metinleri; problem tipleri `module-disabled`,
  `blocked-link`.
- Arayüz işleri `ui-ux-pro-max` skill'iyle (`--stack flutter`) yapılır ve
  teslim öncesi kontrol listesinden geçer (CLAUDE.md).

## Değerlendirilen alternatifler

- **Modülleri tek "v3 modülleri" klasöründe toplamak:** Reddedildi;
  paralel çalışmayı ve ADR-0002'deki sınırları bozar.
