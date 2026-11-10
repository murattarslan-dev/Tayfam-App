# ADR-0011: Yalnızca mobil istemci; web yalnızca geliştirme derlemesi

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-10
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0003](0003-gezinme-iskeleti.md), [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0007](0007-websocket.md), [ADR-0010](0010-signal-kutuphanesi.md); Notion: Proje Planı §8, Özellik Haritası (Platform)

## Bağlam

Notion'daki plan "iOS, Android ve tam web sürümü" diyordu ve web uygulaması
`tayfam.app` adresinde yayınlanacaktı. Web, uçtan uca şifrelemede anahtar
saklamayı (tarayıcıda güvenli depo yok), token taşımayı (HttpOnly çerez,
CORS, CSRF) ve WebSocket kimlik doğrulamasını ayrıca çözmeyi gerektiriyordu;
saldırı yüzeyini de büyütüyordu.

## Karar

1. **Uygulama yalnızca Android ve iOS'ta yayınlanır.** Web istemcisi
   yoktur; `tayfam.app` tanıtım sayfası ve link karşılama sayfası olarak
   kalır (platform sahibi, 2026-11-10).
2. **Web derlemesi yalnızca geliştirme kolaylığıdır.**
   - Hiçbir yerde yayınlanmaz; yalnızca dev API'ye (`api-dev.tayfam.app`)
     yerel makineden bağlanır. Sürüm derlemesi web hedefini içermez.
   - Mobil kod yolunu kullanır: token gövdede gelir, `Authorization: Bearer`
     ile gönderilir, yalnızca bellekte tutulur (sayfa yenilenince yeniden
     giriş). Tarayıcı deposuna hiçbir şey yazılmaz.
   - Uçtan uca şifreleme web derlemesinde yüklenmez; birebir mesaj ekranları
     mobilde test edilir.
   - WebSocket kurulmaz (tarayıcı WebSocket isteğine `Authorization`
     başlığı ekleyemez); mesajlar REST ile gider, canlı akış mobilde test
     edilir (ADR-0007).
   - Web'e özgü kod (`kIsWeb` dalları) yalnızca bu geliştirme kolaylığı için
     yazılır ve en az tutulur.
3. **Linkler uygulamayı açar.** Davet (`tayfam.app/davet#<token>`) ve
   referans (`tayfam.app/r/<KOD>`) linkleri Android App Links ve iOS
   Universal Links ile uygulamaya gelir. Uygulama kurulu değilse
   `tayfam.app`'teki statik sayfa mağaza bağlantısını gösterir ve
   kurulumdan sonra linke tekrar dokunmasını söyler; sayfa JavaScript
   içermez, fragment'taki davet token'ı tarayıcıdan çıkmaz. Doğrulama
   dosyaları (`/.well-known/assetlinks.json`, `apple-app-site-association`)
   imzalama anahtarı belli olunca tanıtım sayfasına eklenir.
4. **Geniş ekran düzeni tablet içindir.** ≥ 600 px'te dikey gezinme çubuğu
   (ADR-0003) tabletler için kalır.

## Sonuçlar

- CLAUDE.md kesin kural 2 ve 4'ten web maddeleri çıkar; ADR-0005, 0006,
  0007 ve 0010'daki web davranışları bu ADR'ye göre düzeltildi.
- Tayfam-Api'de web istemcisine özgü destek (uygulama için HttpOnly
  çerezler, `X-Tayfam-Client: web`, WebSocket'te çerez ve Origin) gereksiz
  kalır; kaldırılması ve dev ortamında yalnızca yerel geliştirme kaynağı için
  CORS izni Tayfam-Api'de iş olarak açıldı. Yönetim paneli
  (`admin.tayfam.app`) kendi çerezleriyle çalışır ve bu karardan
  etkilenmez.
- Notion'da Proje Planı (§1, §8), Özellik Haritası ve Geçiş Özeti
  güncellendi. Tanıtım sayfasındaki "iOS, Android ve web'de" ifadesi
  değişmeli.
- Mağazasız değişiklik yolu olarak web kalmaz; sunucu tarafı yapılandırma
  ve en düşük sürüm kontrolü (Tayfam-Api #114) kalır.

## Değerlendirilen alternatifler

- **Tam web sürümü:** önceki plan. E2E anahtarları için tarayıcı deposu,
  çerez tabanlı oturum, CORS/CSRF ve XSS riskini getiriyordu.
- **Web'de E2E'siz sınırlı sürüm:** gizlilik vaadini platforma göre
  değiştirirdi.
