# ADR-0007: WebSocket bağlantısı, abonelikler ve mesaj gönderimi

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-09, güncelleme 2026-11-12 (birebir mesaj istisnası)
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md), [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0020](0020-birebir-uctan-uca-sifreleme-istemci.md); Tayfam-Api ADR-0005, ADR-0014, ADR-0018 §7; OpenAPI `GET /v1/realtime`

## Bağlam

Sözleşme `GET /v1/realtime` için çerçeveleri, kapanma kodlarını ve
sınırları tanımlar: bağlantı erişim token'ıyla (`Authorization` başlığı)
açılır, token süresi dolunca 4003 ile kapanır;
bağlantı başına en fazla 100 abonelik; mesaj hız sınırı REST ile ortak.
Tayfam-Api ADR-0005'e göre WebSocket yalnızca canlı iletim içindir, kaçırılan
mesajlar REST ile son görülen kimlikten çekilir ve mesaj gönderme "REST
üzerinden de" yapılabilir; iki yol aynı sunucu fonksiyonundan geçer.

## Karar

### Bağlantı

- Paket: Dart ekibinin `web_socket_channel` paketi; `Authorization: Bearer`
  başlığıyla (`IOWebSocketChannel`) bağlanılır. Token URL'ye konmaz.
- Web geliştirme derlemesinde WebSocket kurulmaz: tarayıcı WebSocket
  isteğine `Authorization` başlığı ekleyemez. Orada mesajlar REST ile
  gönderilir, ekranlar açılınca yenilenir; canlı akış mobilde test edilir
  (ADR-0011).
- Uygulama başına **tek bağlantı**, `core/realtime/` altında `keepAlive`
  bir provider'da; ekranlar onun olay akışını dinler, kendi bağlantısını
  açmaz.
- Bağlantı yalnızca oturum açıkken ve kayıt tamamlanmışken kurulur.
- **Arka plan:** uygulama arka plana geçtikten 30 saniye sonra bağlantı
  kapatılır; ön plana dönünce yeniden bağlanılır. Arka planda haber vermek push bildirimin
  işidir.
- Ping/pong protokol düzeyinde platformca yanıtlanır; ayrıca kalp atışı
  çerçevesi gönderilmez.

### Kapanma ve yeniden bağlanma

| Durum | Davranış |
| --- | --- |
| `4003 token_expired` | `SessionStore` ile token yenilenir (ADR-0005), hemen yeniden bağlanılır |
| `4001 session_ended` | Oturum kapatılır, kullanıcı durumu sıfırlanır, girişe dönülür |
| Ağ kopması, `1006`, `4002 slow_consumer`, `1008` | Artan aralıklarla yeniden denenir: 1, 2, 4 … en fazla 30 saniye, ±%20 rastgele sapma |
| `1003`, `1009` | İstemci hatasıdır; hata kodu loglanır, aynı aralıklarla yeniden bağlanılır |

- Her yeniden bağlantıdan sonra abonelikler yeniden kurulur ve açık
  ekranlar kaçırdıklarını REST ile, son gördükleri mesaj kimliğinden
  itibaren çeker.

### Abonelikler

- Yalnızca **aktif tayfanın** görülebilen kanallarına abone olunur;
  okunmamış sayıları canlı güncellenir. Tayfa değişince önceki tayfanın
  abonelikleri bırakılır. 100 sınırına yaklaşılırsa açık ekrandaki kanal
  önceliklidir.
- Birebir mesaj çerçeveleri abonelik gerektirmez.
- `unsubscribed` + `access_lost`: kanal bellekteki durumdan çıkarılır, o
  kanalın ekranı açıksa kullanıcı kanal listesine döner.
  `recheck_failed`: 5 saniye sonra bir kez yeniden abone olunur.
- `tayfa_not_found` / `channel_not_found`: ilgili durum yenilenir; istemci
  erişimi varsaymaz (CLAUDE.md kesin kural 5).

### Mesaj gönderimi

- Bağlantı açıksa kanal mesajı `send` çerçevesiyle gönderilir; bağlantı
  kapalıysa ya da çerçeveye 10 saniyede cevap gelmezse aynı
  `client_request_id` ile REST'e düşülür. Sunucu aynı id'yi ikinci kayıt
  açmadan karşılar.
- **Birebir mesaj istisnası (2026-11-12, Tayfam-Api #151):** birebir mesaj
  yalnızca uçtan uca şifrelidir ve bağlantı açık da olsa kapalı da olsa
  **yalnızca REST'ten** (`POST /v1/direct-messages`, `envelopes`) gider
  (ADR-0020). WebSocket'e birebir mesaj çerçevesi yazılmaz; sunucu
  `dm.send`'i kaldırdı (`unsupported_type`). Tekrar denemede aynı
  `client_request_id` kullanılır. Teslim değişmedi: `dm.message_created`
  (içeriksiz) ve `dm.envelope` WebSocket'ten gelir.
- Çevrimdışı kuyruk (ADR-0006) aynı yolları kullanır.
- Gelen `message.created` ve `dm.message_created` `id` ile tekilleştirilir;
  kendi mesajımız gönderimdeki geçici kaydın yerine geçer.
- `slow_mode` ve `rate_limited`: sunucunun verdiği süre kadar beklenir;
  gönder düğmesi bu sürede geri sayım gösterir. `muted`,
  `channel_archived`, `tayfa_read_only`, `permission_denied`: kalıcı hata,
  mesaj "gönderilemedi" olur.

### Diğer olaylar

- `notification`: bildirim listesi ve rozet REST'ten yenilenir (çerçevede
  içerik yoktur).
- `message.deleted`, `message.restored`, `dm.message_deleted`,
  `dm.conversation_accepted`, `dm.read`: bellekteki durum güncellenir.
- Bilinmeyen çerçeve türü yok sayılır (sunucu yeni tür ekleyebilir).

### Log

- Çerçeve içerikleri hiçbir zaman loglanmaz; yalnızca çerçeve türü, hata
  kodu ve kapanma kodu yazılır (CLAUDE.md kesin kural 3).

## Gerekçe

- Tek bağlantı, sunucudaki abonelik sınırını ve pil tüketimini düşük
  tutar.
- 30 saniyelik arka plan süresi, kısa uygulama geçişlerinde bağlantıyı
  korur; uzun süre arka planda açık bağlantı tutmaz (platform sahibi,
  2026-11-09).
- Gönderimde WebSocket önceliği Tayfam-Api ADR-0005'in öngördüğü yoldur;
  REST yedeği aynı belgenin "bağlantı koptuğunda da çalışsın" amacını
  karşılar. Platform sahibinin kuralı: belge REST'i zorunlu kılmadığı için
  soket.

## Sonuçlar

- Bağımlılık: `web_socket_channel`.
- Testler: kapanma kodu tablosunun her satırı, yeniden bağlanmada
  aboneliklerin yeniden kurulması, WebSocket → REST düşüşünde aynı id,
  tekilleştirme, `access_lost` sonrası durum temizliği; bağlantı açıkken
  birebir mesajın WebSocket'e yazılmadan REST'ten gitmesi.
- Uygulamanın arka plandan dönüşü ve yeniden bağlanma, `SessionStore`'un
  tek uçuşlu yenilemesini kullanır; ayrı bir yenileme yolu yoktur.

## Değerlendirilen alternatifler

- **Her zaman REST ile göndermek:** daha basit; ama sözleşmedeki `send`
  çerçevesini kullanmaz ve her mesaj ayrı HTTP isteği olur.
- **Tüm tayfaların kanallarına abone olmak:** tayfalar arası okunmamış
  sayıları canlı olur; ama 100 sınırına çabuk yaklaşır. Diğer tayfaların
  sayıları tayfa değiştirme panelinde REST'ten alınır.
- **Arka planda bağlantıyı açık tutmak:** pil ve işletim sistemi
  kısıtlamaları nedeniyle güvenilmez; push bu iş içindir.
