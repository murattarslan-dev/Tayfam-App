# ADR-0030: Keşfet sekmesi, bildirim zili ve herkese açık Keşfet akışı

- **Durum:** Kabul edildi (platform sahibi, 2026-11-17, sohbette)
- **Tarih:** 2026-11-17
- **Karar veren:** Murat Arslan (ürün kararları, 2026-11-17 sohbeti; mimari
  oturumunun aktarımıyla; issue #214). Küçük arayüz ayrıntıları mevcut
  desenlere uyan en sade seçenekle bu ADR'de kararlaştırıldı ("UI
  ayrıntıları" bölümü).
- **Değiştirdiği:** [ADR-0003](0003-gezinme-iskeleti.md) "Tayfa merkezli,
  dört sabit sekme" listesindeki üçüncü sekme (Bildirimler → Keşfet) ve
  rozet satırı; [ADR-0027](0027-kesfet-ve-guvenlik-agi.md) §1'deki
  `/kesfet` adresinin yeri ("kabuğun üstünde tam ekran" → sekme).
  ADR-0003 ve ADR-0027'nin geri kalanı geçerlidir; ikisine not düşüldü.
- **İlgili:** [ADR-0002](0002-modul-yapisi.md),
  [ADR-0004](0004-tema-ve-bilesen-dili.md),
  [ADR-0018](0018-faz1-kalan-moduller.md) §3,
  [ADR-0019](0019-push-bildirimleri.md) §6; Tayfam-Api ADR-0035
  (sözleşme: PR #228); Notion "Kötüye Kullanım ve Genç Kullanıcı
  Güvenliği" → "Keşfet tasarımı" → "2026-11-17 kararı"

## Bağlam

Platform sahibi 2026-11-17'de Keşfet'in arkadaş şartını kaldırdı
(Tayfam-Api ADR-0035): Keşfet'e açık ve panelden onaylı tayfaların halka
açık yerde buluşan etkinliklerini herkes görür; arkadaşı olmayan da
katılım isteği gönderebilir. Keşfet böylece her kullanıcı için dolu
olabilecek bir yüzey oldu ve tayfa panelindeki bir satırdan ana gezinmeye
taşınması kararlaştırıldı. Alt çubuk beş öğeyi geçmemeli
(`bottom-nav-limit`); Bildirimler sekmeden çıkarılıp üst çubuktaki zile
taşındı.

Sözleşme değişikliği geriye uyumludur: `DiscoverItem.friends` boş,
`friend_count` 0 olabilir (önceden en az 1). Sıra sunucudandır: görünür
arkadaşı olan öğeler önce, diğerleri başlangıç zamanına göre.

## Karar

### 1. Dört sabit sekme: Tayfa, Sohbet, Keşfet, Profil

- Üçüncü sekme **Keşfet**'tir (`/kesfet`; ikon `explore`, seçiliyken
  dolu). `StatefulShellRoute`'un üçüncü dalı Keşfet rotasıdır; sekme
  kendi geçmişini korur, seçili sekmeye yeniden dokunmak köke döndürür
  (ADR-0003 değişmedi).
- Okunmamış rozeti yalnızca **Sohbet** sekmesindedir.
- Keşfet sekmesi her zaman görünür. Sunucu bayrağı kapalıyken
  (`feature-disabled`) ekran mevcut "Keşfet şu an kullanılamıyor /
  Daha sonra tekrar bakabilirsin." orta durumunu ve "Tekrar dene"yi
  gösterir (ADR-0027 §2; istemci bayrağı sormaz, akışın cevabına bakar).
  Sekmeyi bayrağa göre gizlemek iskeleti değiştirirdi
  (`nav-hierarchy`); ADR-0003'ün "tayfa değişince iskelet değişmez"
  ilkesiyle aynı gerekçe.
- Tayfa değiştirme panelindeki ve karşılama ekranındaki Keşfet satırları
  (ADR-0027 §1, yalnızca akış okunduysa görünür) kalır; artık `push`
  değil `go` ile **Keşfet sekmesine geçer**. Karşılamadaki satır tayfası
  olmayan kullanıcıya Keşfet'i ilk ekranda gösterir.

### 2. Bildirimler: sekme değil, zilden açılan ekran

- `/bildirimler` sekmelerin üstünde açılan tam ekran bir sayfadır (kişi
  profili gibi; ADR-0003 Notlar 2026-11-14). Üst çubukta geri düğmesi ve
  "Bildirimler" başlığı vardır; içerik ve davranış (gruplama, satır içi
  işlemler, sabit güvenlik uyarısı, izin kartı) ADR-0018 §3 ve 2026-11-13
  tasarımıyla aynıdır.
- **Zil** (`core/gezinme/bildirim_zili.dart`, `BildirimZili`) şu üst
  çubuklardadır:
  - Tayfa ana sayfasının mor üst bölümü: tayfa adının sağında, davet
    (kişi+) ve ⋯ menüsünden önce.
  - Karşılama ekranı (tayfası olmayan kullanıcının Tayfa sekmesi): logo
    satırının sağında. Issue "Tayfa ana sayfası" der; karşılama aynı
    sekmenin köküdür ve tayfasız kullanıcının da arkadaşlık isteği, tayfa
    daveti gibi bildirimleri vardır.
  - Keşfet sekmesinin `AppBar`'ı.
- Zile dokununca `context.push('/bildirimler')`; geri tuşu açıldığı
  sekmeye döner. Bildirimler açılınca okunmamış sayısı ve (varsa) liste
  sunucudan okunur; bu, eski "sekme açılınca yenile" davranışının
  yerindedir (ADR-0018 §3). Ön plana dönüşte ve WebSocket `notification`
  olayında yenileme kabukta aynen sürer.
- **Paket sınırı (ADR-0002):** Bildirim paketi tayfa paketini import
  ettiği için tayfa paketi bildirimi import edemez. Zil `core/`'dadır,
  sayıyı `okunmamisBildirimYuvasiProvider` yuvasından okur;
  `shell/kayitlar.dart` yuvayı `okunmamisBildirimSayisiProvider`'la
  doldurur (ADR-0027'deki yuva deseni). Varsayılan 0'dır, rozet yoktur.

### 3. Bildirim ve derin link yönlendirmeleri

- Sekmelerin üstünde açılan adresler `Adresler.sekmelerinUstundeMi` ile
  tek yerde tanımlıdır: `/bildirimler` ve `/kisi/<id>`. Bunlara `push`,
  sekme adreslerine `go` ile gidilir.
- **Push dokunma (ADR-0019 §6):** doğrulanamayan veride ya da ekranı
  olmayan hedefte açılan `/bildirimler` artık `push` edilir; böylece
  kabuk (tek WebSocket bağlantısı ve push dinleyicisi) yığında kalır.
  Bildirimler zaten en üstteyse ikinci kez itilmez. Hedef bir sekme
  adresiyse (`/t/<tayfaId>/…`, `/sohbet/…`, `/profil/…`) `go` aynen
  kalır.
- **Bildirimler listesinden:** sekme adresine `go` Bildirimler'i kapatır
  ve ilgili sekmeye geçer; kişi profili Bildirimler'in üstüne `push`
  edilir (geri tuşu Bildirimler'e döner).
- Derin linkler (davet, referans) değişmedi; `/kesfet` ve `/bildirimler`
  adresleri doğrudan da açılır.

### 4. Herkese açık Keşfet akışı

- `lib/core/api/gen/` Tayfam-Api `dev`'in `69e50d8` commit'ine (PR #228)
  yeniden üretildi; değişiklik açıklamalar ve `friend_count` alt
  sınırıdır, model ve uçlar aynı.
- Kartın üstündeki "Ayşe ve 2 arkadaşın bu etkinlikte" satırı ve
  altındaki çizgi yalnızca `friend_count > 0` ve `friends` doluyken
  görünür (`kesfetArkadasVarMi`). Arkadaşsız kart etkinlik türüyle
  başlar. Sıra sunucudandır; istemci sıralamaz, gruplamaz.
- Arkadaşı olmayan kullanıcı da "Katılım isteği gönder"i görür ve
  kullanır; istek her zaman onay bekler (ADR-0027 §6 aynen).
- Metinler herkese açık akışa göre güncellendi: açıklama ("Keşfet'e açık
  tayfaların, halka açık yerde buluşan etkinlikleri … etkinliğe giden
  bir arkadaşın varsa katılmadan önce ona sorabilirsin"), boş durum
  ("Keşfet'e açık tayfalar halka açık bir etkinlik planlayınca burada
  görürsün"), giriş satırı ("Tayfaların herkese açık etkinlikleri").
  "Güvenilir", "onaylı" denmez; "Tayfam tayfalara kefil olmaz" notu
  kalır (ADR-0027 §8).
- Durumlar: yükleniyor, boş, yükleme hatası ("Tekrar dene"), Keşfet
  kapalı (`feature-disabled`), aşağı çekip yenileme. Yaşa dair hiçbir
  işaret gösterilmez (Tayfam-Api ADR-0035 §4).

### 5. UI ayrıntıları (mimari oturumu; mevcut desenler)

- Zil `IconButton`'dır: en az 48 × 48 dp, ipucu "Bildirimler". Ekran
  okuyucu okunmamış yokken "Bildirimler", varken "Bildirimler, 5
  okunmamış bildirim" okur; rozetteki sayı ayrıca okunmaz (ADR-0003
  rozet kuralı). Rozet canlı bölge değildir; sayı her değişimde
  duyurulmaz (ui-ux-pro-max: tek bağlamsal etiket).
- İkon her zaman çizgi (outline) biçimindedir; okunmamış durumu rozet
  taşır (aynı seviyede dolu/çizgi karışmaz). Rozette 99'un üstü "99+".
- Mor üst bölümde ikon `markaYuzeyUstu` (beyaz); rozet **mango zemin,
  ink metin**. Temanın nar rozeti (`colorScheme.error`) mor üzerinde
  2.1:1'dir ve 3:1 (metin dışı öğe) eşiğini tutmaz; mango 4.0:1, ink
  metin mango üzerinde 9.8:1. Mango mor yüzeyin odak rengidir (ADR-0004
  Notlar), yeni token yok. Açık zeminli üst çubuklarda (karşılama,
  Keşfet) temanın varsayılan rozeti kalır (Sohbet sekmesiyle aynı).
- Bildirimler ekranında "Hepsini okundu say" (yalnızca okunmamış varken)
  `AppBar` eylemi değil, listenin üstünde sağa yaslı bağlantı
  düğmesidir: 2× yazıda dar ekranda başlığı sıkıştırmasın diye.
- Klavye ve ekran okuyucu sırası görsel sırayla aynıdır: karşılamada
  ilk odak sağ üstteki zildir.

## Gerekçe

- **Keşfet sekmesi:** herkese açık akış her kullanıcı için içerik
  taşıyabilir; panelin içindeki bir satır keşfedilebilir değildi.
- **Zil:** bildirimler her ekrandan değil, kullanıcının en çok baktığı
  iki ekrandan (Tayfa, Keşfet) bir dokunuşla açılır; alt çubuk dört
  öğede kalır.
- **`push` + kabuk yığında:** `/bildirimler`'e `go` kabuğu yığından
  çıkarır ve WebSocket bağlantısını kapatırdı (ADR-0007); kişi
  profilindeki desen aynen uygulanır.
- **Yuva:** zil core'da, sayı yuvada; tayfa ve Keşfet paketleri bildirim
  paketini bilmez, döngü yok (ADR-0002, kural betiği).

## Sonuçlar

- Yeni paket yok; yeni izin yok; diske yeni bir şey yazılmaz.
- ARB: `gezinme_sekme_bildirimler` → `bildirimler_baslik`,
  `gezinme_bildirim_okunmamis` → `bildirim_zili_okunmamis`, yeni
  `gezinme_sekme_kesfet`; Keşfet metinleri güncellendi.
- Testler: sekme sırası, Keşfet sekmesi, üç yerdeki zil ve geri dönüş,
  zil rozeti (gizli/sayı/etiket/48 dp/mor yüzey rengi), bildirimden
  sekme hedefi, push dokunmada `/bildirimler`'in kabuğu koruması ve
  ikinci kez itilmemesi, derin adresler, panelden Keşfet sekmesi;
  Keşfet arkadaşsız/hata/boş/kapalı halleri iki temada 2× yazıda.
- Bildirim/FCM kodunda yalnızca push dokunmanın `push`/`go` seçimi
  değişti (`shell/push_olaylari.dart`); FCM katmanına dokunulmadı.

## Değerlendirilen alternatifler

- **Beş sekme (Bildirimler kalır, Keşfet eklenir):** alt çubuk beşe
  çıkar; etiketler 2× yazıda sıkışır; platform sahibi zili seçti.
- **Zil yalnızca tayfa ana sayfasında:** tayfası olmayan kullanıcı
  bildirimlere yalnızca Keşfet'ten ulaşırdı.
- **Bildirimler'i her sekmenin altında ayrı rota:** aynı ekranın üç
  adresi olurdu; push ve derin link tek adres bekler.
- **Zili bayrak/sayıya göre gizlemek:** zil her zaman görünür;
  bildirimlerin yeri değişmez.
