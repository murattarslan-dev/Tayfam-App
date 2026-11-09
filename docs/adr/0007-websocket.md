# ADR-0007: WebSocket bağlantısı, abonelikler ve mesaj gönderimi

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md), [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md); Tayfam-Api ADR-0005, ADR-0014; OpenAPI `GET /v1/realtime`

## Bağlam

Sözleşme `GET /v1/realtime` için çerçeveleri, kapanma kodlarını ve
sınırları tanımlar: bağlantı erişim token'ıyla açılır (mobilde
`Authorization`, web'de çerez), token süresi dolunca 4003 ile kapanır;
bağlantı başına en fazla 100 abonelik; mesaj hız sınırı REST ile ortak.
Tayfam-Api ADR-0005'e göre WebSocket yalnızca canlı iletim içindir, kaçırılan
mesajlar REST ile son görülen kimlikten çekilir ve mesaj gönderme "REST
üzerinden de" yapılabilir; iki yol aynı sunucu fonksiyonundan geçer.

## Karar

### Bağlantı

- Paket: Dart ekibinin `web_socket_channel` paketi. Mobilde
  `Authorization: Bearer` başlığıyla (`IOWebSocketChannel`), web'de çerezle
  bağlanılır. Token URL'ye konmaz.
- Uygulama başına **tek bağlantı**, `core/realtime/` altında `keepAlive`
  bir provider'da; ekranlar onun olay akışını dinler, kendi bağlantısını
  açmaz.
- Bağlantı yalnızca oturum açıkken ve kayıt tamamlanmışken kurulur.
- **Arka plan:** mobilde uygulama arka plana geçtikten 30 saniye sonra,
  web'de sekme 5 dakika görünmez kaldığında bağlantı kapatılır; ön plana
  dönünce yeniden bağlanılır. Arka planda haber vermek push bildirimin
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

- Bağlantı açıksa kanal mesajı `send`, birebir mesaj `dm.send` çerçevesiyle
  gönderilir; bağlantı kapalıysa ya da çerçeveye 10 saniyede cevap
  gelmezse aynı `client_request_id` ile REST'e düşülür. Sunucu aynı id'yi
  ikinci kayıt açmadan karşılar.
- Çevrimdışı kuyruk (ADR-0006) aynı yolu kullanır.
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
  tekilleştirme, `access_lost` sonrası durum temizliği.
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
