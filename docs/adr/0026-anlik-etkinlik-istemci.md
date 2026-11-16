# ADR-0026: Anlık (bireysel) etkinlik (istemci)

- **Durum:** Kabul edildi (ürün kararları platform sahibinin, 2026-11-15;
  istemci seçimleri 2026-11-16'da mimari oturumu aracılığıyla, platform
  sahibinin yetkisiyle onaylandı)
- **Tarih:** 2026-11-16
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0002](0002-modul-yapisi.md), [ADR-0003](0003-gezinme-iskeleti.md),
  [ADR-0005](0005-api-istemcisi.md), [ADR-0014](0014-tayfa-listesi-katilim-ve-olusturma.md),
  [ADR-0015](0015-etkinlik-ve-duyuru-modulleri.md), [ADR-0018](0018-faz1-kalan-moduller.md);
  Tayfam-Api ADR-0032; Notion "Faz 2 (v2) — Medya ve Sosyal" §5, §7a;
  tasarım `docs/tasarim/29-anlik-etkinlik/`; issue #198

## Bağlam

Kullanıcı tayfaya bağlı olmadan arkadaşlarıyla tek seferlik etkinlik
açabilmeli. Sunucu bunu gizli, tek etkinlikli bir tayfayla çözer
(`Tayfa.kind = instant`, `instant_event_id`): organizatör yönetici,
davetliler üye; yalnızca etkinlik modülü açık; linkle gelen her zaman
katılım isteği bırakır; kodla katılım yok; en fazla 3 açık ve günde 5 anlık
etkinlik (`instant-event-limit`); etkinlik bitince 7 gün sonra arşiv;
"Bu ekiple tayfa kur" ile kalıcı tayfaya dönüşür
(`POST /v1/tayfas/{id}/conversion`). Etkinlik sayfası, katılım, varış
bildirimi, sohbet ve albüm mevcut tayfa altyapısıyla çalışır.

## Karar

### 1. Sihirbaz: etkinlik sihirbazının anlık kipi

- Yeni bir sihirbaz yazılmaz. `EtkinlikSihirbaziNotifier`'ın anahtarındaki
  `tayfaId` boş olabilir (`null` = anlık); `AnlikSihirbazNotifier` alt
  sınıfı açılış değerlerini (gün, davetli) taslağa işler ama "girilen"
  saymaz (vazgeç onayı sorulmaz).
- Adımlar: tür → başlık ve zaman → yer → ayrıntı → **Kimleri çağıralım?** →
  önizleme (6 adım). Tür adımında ilgi alanı grubu, bilgi adımında kapak,
  ayrıntı adımında tekrar yoktur (sözleşme: `cover_upload_id` ve
  `recurrence` verilemez). `discoverable` hiç gönderilmez.
- Gönderim `POST /v1/instant-events`; `event.client_request_id` sihirbaz
  açılınca bir kez üretilir (ADR-0014 §4). Başarıda gizli tayfa tayfa
  listesine eklenir ve liste yenilenir; "Etkinlik açıldı" ekranı sihirbazın
  yerine çizilir (yalnızca yanıtla; ek istek yok), "Etkinliğe git" etkinlik
  adresini açar ve aktif tayfa adrese göre değişir (ADR-0014 §1).
- Adres `/anlik-etkinlik?gun=YYYY-MM-DD&davetli=<uuid>`, kabuğun üstünde
  tam ekran; `go` ile açılır (tayfa kurma sihirbazı gibi). Parametreler
  girdi kabul edilir: gün geçerli bir takvim günü olmalı ve bugünden 30 gün
  ileriye kadar; davetli UUID. Geçmeyen değer yok sayılır. Gün verilirse
  başlangıç o gün 19:00 (bir saatten yakınsa bir sonraki tam saat + 1),
  bitiş +2 saat.

### 2. Arkadaş seçimi

- Arkadaş listesi arkadaşlık özelliğindedir; etkinlik özelliği
  `arkadas.dart`'tan `arkadaslarProvider` ve `arkadasDeposuProvider`'ı
  kullanır (yeni bağımlılık yönü etkinlik → arkadaş; döngü yok).
- `ArkadasSecimi` bileşeni hem sihirbaz adımında hem anlık tayfanın
  "Arkadaş davet et" sayfasında kullanılır: yüklü arkadaşlarda yerel arama
  (`turkceKucukHarf`), en çok 10 seçim (sözleşme), canlı bölge sayaç.
  Davetli kimlikleri yalnızca bellekte ve istek gövdesinde tutulur.
- Oluşturmadan sonra davet mevcut uçla
  (`POST /v1/tayfas/{id}/invitations`) kişi kişi gönderilir; biri
  başarısız olursa diğerleri denenir, ilk hata gösterilir.

### 3. Tayfa özelliğinde anlık tayfa

- `TayfaOzeti.anlik` (`kind == instant`) yalnızca arayüzü sadeleştirir;
  izinleri sunucu verir (kesin kural 5).
- Panel: anlık tayfalar kalıcılardan sonra "Anlık etkinlikler" grubunda,
  etkinlik ikonuyla; bekleyen istekte "Anlık" etiketi. Panelin ve
  karşılamanın altında "Anlık etkinlik aç".
- Ana sayfa: kurulum kartı, "7 günde 3 üye" metni ve "Oluştur" düğmesi
  yoktur. Mor bölüme taşan "Anlık etkinlik" kartı arşiv bilgisini ve
  organizatöre (yönetici) "Arkadaş davet et", "Davet linkini paylaş",
  "Bu ekiple tayfa kur" eylemlerini gösterir.
- "Arkadaş davet et" etkinlik özelliğindedir; tayfa özelliği onu
  `arkadasDavetiProvider` kaydıyla açar (`tayfaDavetiProvider` gibi;
  tayfa → etkinlik importu döngü olurdu).
- Davet linki akışı aynıdır; anlık tayfada açıklama ve paylaşım metni
  "katılım isteği / etkinliğe katıl" der. Linkle gelenin "İsteğin
  gönderildi" kutusu, tür yenilenen listeden okunabiliyorsa "Organizatör
  onaylayınca etkinliği görürsün" der.

### 4. "Bu ekiple tayfa kur"

- Tayfa kurma sihirbazının aynı üç adımı (`OlusturmaEkrani.donustur`,
  `DonusturmeNotifier`); adres `/tayfa-donustur/<tayfaId>`, kimlik girdi
  kabul edilir. Gönderim `POST /v1/tayfas/{id}/conversion`.
- "Tayfa kuruldu" ekranı yoktur (üyeler zaten var): başarıda liste ve
  görünüm tazelenir, ana sayfa açılır ve kısa bildirim çıkar. Kurulum
  kartı ve "7 günde 3 üye" dönemi `converted_at`'ten sayıldığı için
  dönüşümden sonraki 7 gün görünür (Notlar 5). `tayfa-create-limit` / `rate-limited` Tayfa-Kur-Limit
  kutusunda.

### 5. Ortak bileşenler

İki kullanıcısı olduğu için özelliklerden `core/bilesenler/`'e taşındı;
yeni görünüm yoktur: `SinirKutusu` (tint-nar sınır kutusu),
`BeyazCerceveliEylem` (mor yüzeyde ikincil düğme), `SihirbazBilgiKutusu`.

### 6. Etkinlik kanalı

Sunucu etkinlik kanalı açmaz; organizatör etkinlik detayındaki mevcut
"Etkinlik sohbetini aç" kartıyla açar (Tayfam-Api ADR-0032 §2). Yeni kod
yoktur.

## Gerekçe

- Sihirbazı ve tayfa ekranlarını yeniden kullanmak, platform sahibinin
  "mevcut tasarım bütünlüğü" kuralını ve sunucunun "anlık tayfa = tayfa
  türü" modelini izler; yeni yüzey yalnızca arkadaş seçimi ve açıldı
  ekranıdır.
- Davetli seçimini sihirbaza koymak (oluşturma isteğinde
  `invitee_user_ids`) davetin tek transaction'da gitmesini sağlar; sonradan
  davet aynı bileşenle yapılır.

## Sonuçlar

- Yeni paket yok.
- `lib/core/api/gen` Tayfam-Api `1ec9228`'e yükseltildi; aynı commit'te
  gelen başka işlerin (sohbet ekleri, albüm, öneri) alanları için yalnızca
  derlemeyi koruyan uyumluluk değişiklikleri yapıldı.
- "Boşum" rozetindeki "Bir şey yapalım" (Tayfam-App #203) bu adresi
  `Adresler.anlikEtkinlik(gun:, davetli:)` ile açar.

## Değerlendirilen alternatifler

- **Ayrı anlık etkinlik sihirbazı:** kod tekrarı; tasarım bütünlüğü kuralına
  aykırı.
- **Arkadaş seçimini oluşturmadan sonraya bırakmak:** davet ayrı isteklerle
  gider, oluşturma ile davet arasında yarım kalabilir.
- **Anlık tayfayı panelde gizlemek, yalnızca etkinlik olarak göstermek:**
  sohbet, katılım istekleri ve dönüştürme tayfa yüzeyinde; platform sahibi
  "panelde ayrı işaretli" dedi.

## Notlar

- **2026-11-16 (platform sahibi, mimari oturumu aracılığıyla; PR #205):**
  PR'daki açık sorular cevaplandı.
  1. İstemci ADR numaraları: 0025 albüm, 0026 anlık etkinlik, 0027 Keşfet,
     0028 sohbet ekleri.
  2. Karşılamadaki ikinci giriş ("Anlık etkinlik aç") uygun.
  3. "Bir şey yapalım" varsayılanı 19:00, süre 2 saat uygun.
  4. Dönüşümde "Tayfa kuruldu" ekranının atlanması uygun.
  5. **`converted_at`:** ~~sözleşmede yoktur; ana sayfadaki kurulum dönemi
     `created_at`'ten sayılır ve dönüşümde kurulum kartı bir kez zorla
     gösterilir~~ (geçici çözüm, kaldırıldı). Alan Tayfam-Api PR #220 ile
     sözleşmeye girdi (`Tayfa.converted_at`); istemci issue #209 ile kurulum
     dönemini `converted_at ?? created_at`'ten sayar (`kurulumBaslangici`).
     Dönüşümde zorla gösterme yoktur; kart dönüşümden sonraki 7 gün
     görünür, sonra kaybolur.
  6. "Arkadaş davet et"te zaten üye olanların süzülmemesi; sunucu hatası
     gösterilir. Yeterli.
  7. Etkinlik kanalı otomatik açılmaz; organizatör detaydaki mevcut
     "Etkinlik sohbetini aç"ı kullanır.
