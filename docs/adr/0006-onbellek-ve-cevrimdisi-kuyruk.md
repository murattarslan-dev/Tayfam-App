# ADR-0006: Önbellek ve çevrimdışı kuyruk: yalnızca bellekte

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md), [ADR-0005](0005-api-istemcisi.md); Tayfam-Api ADR-0011; Notion: Özellik Haritası (çevrimdışı yazma)

## Bağlam

Özellik Haritası'nda "çevrimdışı yazma (sonra gönderme), çift kayıt
oluşmaz" MVP'dedir. Sözleşmede sekiz oluşturma isteği `client_request_id`
taşır (tayfa, duyuru, etkinlik, soru, cevap, kanal mesajı, birebir mesaj,
av kaydı); aynı id ile tekrar gönderim ikinci kayıt açmaz. Katılım bildirimi
(RSVP) zaten tekrarlanabilir bir istektir.

Diske yazılan her içerik, cihaz kaybolduğunda ya da ele geçirildiğinde
açığa çıkabilir; kapalı tayfaların içeriği de buna dahildir (güvenlik
ilkesi: tutmadığın veri çalınamaz).

## Karar

**Uygulama, token dışında hiçbir kullanıcı içeriğini diske yazmaz.** Mobilde
güvenli depodaki token'lar (ADR-0005) ve kullanıcı ayarları (tema, dil)
dışında kalıcı veri yoktur; web'de tarayıcı deposuna içerik yazılmaz.

### Okuma önbelleği

- Riverpod provider'larının bellekteki durumu önbellektir; ayrı bir disk
  önbelleği (sqlite, Hive, `shared_preferences`, IndexedDB) kullanılmaz.
- Listeler ekran açılınca ve uygulama ön plana dönünce yenilenir; WebSocket
  olayları bellekteki durumu günceller (ayrı ADR).
- Çevrimdışı açılışta liste boş görünür ve "Bağlantı yok" boş durumu
  gösterilir; bağlantı gelince otomatik yenilenir.
- Görsel önbelleği de yalnızca bellektedir (dosyalar Faz 2'de geldiğinde).

### Çevrimdışı yazma kuyruğu

- Kuyruk `core/` altında, `keepAlive` bir provider olarak yalnızca bellekte
  tutulur (ADR-0001 kural 4). Mobilde ve web'de aynı davranır.
- **Kapsam:** kanal mesajı, birebir mesaj (düz sürüm), soru, cevap, katılım
  bildirimi. Duyuru, etkinlik ve tayfa oluşturma kuyruğa girmez; çevrimdışı
  iken form açık kalır, gönderim bağlantı gelince yapılır.
- Her öğe oluşturulduğu anda bir `client_request_id` alır; her denemede
  aynı id gönderilir.
- **Yeniden deneme:** bağlantı gelince ve artan aralıklarla (2, 4, 8 …
  en fazla 60 saniye). `invalid-request`, `permission-denied`, `not-found`
  gibi kalıcı hatalarda denenmez, öğe "gönderilemedi" olur. `rate-limited`
  sunucunun bildirdiği süre kadar bekler.
- Bekleyen öğe arayüzde saat ikonuyla, başarısız olan uyarı ikonuyla
  gösterilir; başarısız öğede "Tekrar dene" ve "Sil" vardır.
- **Bilinçli kabul edilen bedel:** uygulama kapanır ya da sistem tarafından
  sonlandırılırsa bekleyen öğeler kaybolur. Bekleyen öğe varken uygulama
  arka plana alınırsa bir kez uyarı gösterilir (web'de sayfadan çıkarken
  tarayıcı uyarısı).
- Oturum kapanınca, kullanıcı değişince veya hesap silinince kuyruk
  temizlenir (ADR-0001 kural 8).
- Kuyruk içeriği log'a yazılmaz (CLAUDE.md kesin kural 3).

## Gerekçe

- Platform sahibinin kararı (2026-11-09): diskte bir şey tutmaya gerek yok,
  bellekte önbellek yeterli.
- Cihaz kaybında ya da ele geçirilmesinde açığa çıkacak içerik yoktur;
  şifreli yerel veritabanı, anahtar yönetimi ve göç (migration) yükü de
  yoktur.
- `client_request_id` sayesinde bellekteki kuyruk, tekrar gönderimde çift
  kayıt üretmez.

## Sonuçlar

- Bağımlılık eklenmez.
- Özellik Haritası'ndaki "çevrimdışı yazma" maddesi "uygulama açıkken"
  olarak netleşir.
- Testler: aynı id ile yeniden gönderim, kalıcı ve geçici hata ayrımı,
  oturum kapanışında kuyruğun temizlenmesi.
- İleride çevrimdışı okuma istenirse şifreli yerel depo ayrı bir ADR'yle
  değerlendirilir.

## Değerlendirilen alternatifler

- **Şifreli disk kuyruğu (AES-GCM, anahtar güvenli depoda):** uygulama
  kapansa da bekleyen mesaj kaybolmaz; ama diske içerik yazılır ve anahtar
  yönetimi gerekir. Platform sahibi istemedi.
- **Şifreli yerel veritabanı ile çevrimdışı okuma:** çevrimdışı açılışta
  içerik görünür; ama cihazda kalıcı içerik, büyük bağımlılık ve göç yükü.
