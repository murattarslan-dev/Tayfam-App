# ADR-0027: Keşfet ilk aşama ve güvenlik ağı (istemci)

- **Durum:** Önerildi (mimari oturumu cevaplayınca kabul; açık sorular
  PR'da ve tasarım bölümünde)
- **Tarih:** 2026-11-16
- **Karar veren:** Ürün kararları platform sahibinindir (2026-11-12
  "Keşfet tasarımı", 2026-11-16 ayrıntı kararları; Notion "Faz 2 (v2) —
  Medya ve Sosyal" §6, §9; issue #199). Bu ADR onların istemci
  mimarisine taşınmasıdır. Açık ayrıntılarda mimari oturumunun önerisi
  geçerlidir (platform sahibi yetkilendirdi).
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md),
  [ADR-0002](0002-modul-yapisi.md), [ADR-0003](0003-gezinme-iskeleti.md),
  [ADR-0005](0005-api-istemcisi.md),
  [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md),
  [ADR-0014](0014-tayfa-listesi-katilim-ve-olusturma.md),
  [ADR-0015](0015-etkinlik-ve-duyuru-modulleri.md),
  [ADR-0019](0019-push-bildirimleri.md); Tayfam-Api ADR-0033 (sözleşme:
  PR #218); tasarım
  [`docs/tasarim/30-kesfet-ve-guvenlik/`](../tasarim/30-kesfet-ve-guvenlik/README.md)

## Bağlam

Tayfam-Api ADR-0033 Keşfet'in ilk aşamasını (arkadaş ağı akışı,
Keşfet'ten katılım isteği, "Her şey yolunda mıydı?") ve güvenlik ağını
(güvenlik kişisi, "Döndüm", güvenlik kişisinin gördüğü en az bilgi)
ekledi. İki sunucu bayrağı vardır: `DISCOVER_ENABLED` (varsayılan
kapalı; kapalıyken akış, katılım ve geri bildirim uçları `404
feature-disabled`) ve `SAFETY_CONTACT_ENABLED` (varsayılan açık; kapalıyken
seçme, okuma ve paylaşımlar `feature-disabled`; "Döndüm" ve kaldırma
bayraksız). Tayfanın Keşfet ayarı, etkinliğin `discoverable` işareti ve
üyenin `joined_via_discover` etiketi bayraktan bağımsızdır.

## Karar

### 1. Yer

- Yeni özellik `features/kesfet/`: `data/kesfet_deposu.dart` (Keşfet,
  geri bildirim, güvenlik kişisi, paylaşımlar ve tayfanın Keşfet ayarı
  uçları; arkadaş seçimi için `GET /v1/me/friends`'in ilk sayfası),
  `application/` ve `presentation/`. Güvenlik ağı Keşfet'le aynı
  pakettedir (sözleşmede aynı servis, aynı ADR); bayrakları ayrıdır.
- Başka paketlere **yuvalarla** bağlanır, böylece döngü olmaz
  (ADR-0002): etkinlik detayındaki kartlar `etkinlikEkBolumleriProvider`
  (etkinlik paketinde, sohbet yuvasının modeli), tayfa değiştirme paneli
  ve karşılama ekranındaki giriş `kesfetGirisiProvider` (tayfa
  paketinde), tayfa ayarlarındaki bölüm `tayfaAyarEkBolumleriProvider`
  (tayfa yönetimi paketinde). Kabuk (`shell/kayitlar.dart`) doldurur.
  Profil paketi Keşfet'in dışa açık dosyasından paylaşımlar girişini
  doğrudan import eder (Keşfet profili import etmez).
- Adresler: `/kesfet` (kabuğun üstünde tam ekran, tayfa sihirbazı gibi)
  ve `/profil/guvenlik` (güvenlik kişisi olduğun etkinlikler).

### 2. Bayrak: ayrı uç yok, cevabın `type`'ı

- İstemci bayrağı sormaz; **ilgili ucun cevabı** belirler
  (`ProblemType.featureDisabled`). Keşfet girişleri akışın kendisinin
  okunmasına bağlıdır (`kesfetAkisiProvider`, oturum boyunca bellekte):
  akış okunduysa giriş görünür, `feature-disabled` ya da başka bir hata
  ise görünmez. Böylece istemci kapalı bir özelliği "kimse yok" diye
  göstermez (sunucunun 404 seçiminin gerekçesi) ve fazladan istek yoktur.
- Güvenlik kişisi kartı `GET …/safety-contact`'a bakar; geri bildirim
  kartı `GET …/feedback`'e. Biri `feature-disabled` dönerse yalnızca o
  kart gizlenir.
- Bayrak bir yetki kararı değildir: istemci ne gösterirse göstersin,
  sunucu kapalı özelliği çalıştırmaz (kesin kural 5).

### 3. Veri ve bellek

- Bütün durum yalnızca bellektedir (ADR-0006): akış, paylaşımlar,
  güvenlik kişisi ve geri bildirim `autoDispose`; tayfaya ve etkinliğe
  bağlı olanlar `family`. Oturum değişince sıfırlanır.
- Akış ve paylaşımlar sayfalanmaz (sözleşme: en çok 50).
- Güvenlik kişisinin gördüğü bilgi (kim, saat aralığı, durum) sözleşmenin
  döndürdüğünden fazlası değildir; istemci tayfa ya da etkinlik bilgisini
  bu ekranla birleştirmez.
- Hiçbir cevap, kimlik, kişi adı ya da geri bildirim cevabı log'a yazılmaz
  (kesin kural 3). Konum kullanılmaz.

### 4. Güvenlik kişisi kartının görünürlüğü

- Yüz yüze ve iptal edilmemiş etkinlik. Kişi seçilmemişse: cevap
  `going` ve etkinlik bitmemiş. Seçilmişse: bitiş + tolerans + 24 saate
  kadar (sunucunun paylaşım penceresi); alarm ya da "Döndüm" bilgisi bu
  sürede kaybolmaz.
- Seçim yalnızca kabul edilmiş arkadaşlar arasından; tolerans 30, 60, 120
  ya da 240 dakika (sözleşme 15–1440; varsayılan 60).
- "Döndüm" etkinlik başladıktan sonra gösterilir; kaldırma onay ister ve
  alarmdan sonra gösterilmez (sözleşme reddeder).

### 5. Geri bildirim ve şikâyet

- Kart yalnızca `discoverable`, yüz yüze, iptal edilmemiş, katılımı
  doğrulanmış etkinlikte, bitişten bitiş + 7 güne kadar.
- `serious` kaydedilince şikâyet önerilir ve hedef **tayfadır**
  (`SikayetHedefi.tayfa`, yalnızca platforma gider). Etkinlik şikâyeti
  tayfanın moderasyon kuyruğuna düşer; Keşfet'ten gelen az sayıdaki
  üyeyi yöneticilere ele verirdi.

### 6. Keşfet'ten katılım

- Her zaman onay bekler; istemci başarıda tayfa listesini yeniler
  (bekleyen istek panelde görünür, ADR-0014 §2). `already-pending`
  başarı sayılır.

### 7. Bildirim ve push

- `safety_alert` bildirimi `hike_overdue` gibi okunmamışken listenin
  üstünde sabit durur; satır `target_id`'nin adını profilden okur;
  dokununca `/profil/guvenlik`. Push metinleri ARB'den
  (`push_safety_alert_title` / `_body`), ad ve yer içermez (ADR-0019).

### 8. Arayüz dili

- "Güvenilir", "onaylı", "doğrulanmış tayfa" kullanılmaz; sunucunun
  `approved` kavramı istemciye gelmez (`TayfaDiscover.state`). Akışta
  tayfanın olgularının altında "Tayfam tayfalara kefil olmaz" notu
  bulunur.

## Gerekçe

- **Cevaba bakmak:** ayrı bir "özellikler" ucu sözleşmede yok (kesin
  kural 1); akış zaten okunacak veridir.
- **Yuvalar:** etkinlik, tayfa ve tayfa yönetimi paketleri Keşfet'i
  bilmeden kart ve giriş taşır; Keşfet kapalı ya da kaldırılmış olsa bile
  bu paketler değişmez.
- **Tayfa şikâyeti:** güvenlik sinyali şikâyet edeni ele vermemeli
  (Tayfam-Api ADR-0033 §7, maske gerekçesi).

## Sonuçlar

- Yeni paket yok; yeni izin yok.
- `lib/core/api/gen/` sözleşmenin `8ce2110` commit'ine yeniden üretildi;
  bu, paralel işlerin (anlık etkinlik #205, sohbet ekleri #206) uçlarını
  da getirir. Derleme için gereken en küçük uyarlamalar yapıldı (tükenmiş
  `switch`'lere yeni değerler, `MyTayfa.kind`); asıl ekranlar o işlerdedir.
- Keşfet bayrağı açılınca istemcide değişiklik gerekmez.

## Değerlendirilen alternatifler

- **Bayrağı açılışta ayrı istekle sormak:** sözleşmede uç yok.
- **Güvenlik kişisini etkinlik paketine koymak:** etkinlik paketi büyürdü
  ve arkadaş listesine bağlanırdı; Keşfet paketinde ve yuvayla daha
  ayrık.
- **Akışı her girişte yeniden okumak:** giriş satırı her çizimde istek
  atardı; oturum boyunca bellekte tutup ekranda aşağı çekerek yenilemek
  yeterli.
