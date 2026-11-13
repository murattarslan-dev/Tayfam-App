# ADR-0004: Tema, token'lar ve bileşen dili

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0003](0003-gezinme-iskeleti.md); Notion: Tasarım Standartları, Marka

## Bağlam

Renk, tipografi, boşluk, yarıçap, bileşen, hareket ve erişilebilirlik
kuralları Notion'daki **Tasarım Standartları** sayfasında verilmiştir ve
bağlayıcıdır. Bu ADR yalnızca o kuralların Flutter'a nasıl aktarılacağını ve
Standartlar'ın açık bıraktığı noktaları belirler.

## Karar

### 1. Font uygulamaya gömülür

- Bricolage Grotesque (SIL OFL) `assets/fonts/` altına gömülür; lisans
  dosyası yanında durur. Yalnızca kullanılan ağırlıklar eklenir.
- `google_fonts` paketi kullanılmaz; çalışma anında fonttan ötürü hiçbir
  dış sunucuya istek gitmez. Gerekçe: kullanıcının IP adresinin Google'a
  gitmemesi (KVKK, yurt dışı aktarım) ve çevrimdışı açılış.
- Yedek font: platformun sistem fontu.

### 2. Koyu tema MVP'de, cihaz ayarını izler

- Uygulama açık ve koyu temayla gelir; varsayılan `ThemeMode.system`.
  Profil → Ayarlar'da açık / koyu / sistem seçilebilir.
- Standartlar'daki "surface → ink, metin → beyaz, logo gövdesi → teal"
  kuralı uygulanır. `ink-muted` koyu zeminde 2.47:1 kaldığı ve `brand` ink
  üzerinde 2.44:1 olduğu için koyu tema şu ek token'ları kullanır
  (platform sahibi onayladı, 2026-11-09):

| Token (koyu) | Hex | Rol | Kontrast (ink #1B1036 / card-dark) |
| --- | --- | --- | --- |
| surface | #1B1036 (ink) | Sayfa zemini | — |
| card-dark | #261A47 | Kart yüzeyi | — |
| line-dark | #3A2D60 | Ayırıcı, kart kenarı (süs) | 1.47 / 1.31 |
| text | #FFFFFF | Ana metin | 17.89 / 15.90 |
| text-body-dark | #DCD6EE | Uzun gövde metni | 12.69 / 11.28 |
| text-muted-dark | #B4ABD1 | İkincil metin, giriş alanı kenarı | 8.25 / 7.33 |
| brand-dark | #A98BFF | Seçili durum, bağlantı, etkin sekme; üzerinde ink metin (6.66) | 6.66 / 5.92 |
| tint-brand-dark | #3B2A70 | Etiket zemini; üzerinde #CDBBFF metin (6.94) | — |
| tint-mango-dark | #4A3A1A | Vurgulu sayaç/balon zemini; üzerinde #FFD27A metin (7.72) | — |
| bubble-in-dark | #33255C | Gelen sohbet balonu; beyaz metin (13.46) | — |

- Vurgu renkleri (teal, mango, nar) koyu zeminde de aynıdır; hepsi ink
  üzerinde 4.5:1'in üstündedir (5.21–9.76). Giden sohbet balonu iki temada
  da `brand` zemin + beyaz metindir (~7:1).
- Açık temaya eklenen token: **honey** `#7A5A1E`, `tint-mango` üzerinde
  metin (5.62); tayfam.app'teki "faydalı" sayacından alındı.
- Giriş alanı kenarı gibi etkileşimli öğelerin sınırı en az 3:1 olmalıdır;
  `line-dark` yalnızca süs ayırıcıdır.
- Her renk çifti bir birim testinde WCAG kontrast eşiğine karşı denetlenir
  (metin 4.5:1, büyük metin ve arayüz öğesi 3:1).

### 2a. Marka yüzeyi ve tanıtım sayfasıyla birlik

tayfam.app incelendi (2026-11-09). Tanıtım sayfası morla tam yüzey
(giriş ve gizlilik bölümleri) kullanır ve özellik kartları uygulamanın
bileşenlerini gösterir. Buna göre:

- **Tayfa ana sayfasının üst bölümü mordur:** `brand` zemin, beyaz tayfa
  adı ve metin, birincil eylem mango zemin + ink metin. İki temada da aynı.
  Diğer ekranların üst çubuğu sade (`surface`) kalır; tam yüzey mor yalnızca
  tayfanın kendi ana sayfasındadır.
- **Bileşenler tanıtım sayfasındaki kartlarla aynıdır:** etkinlik kartı
  (tür etiketi, zorluk, baş harf avatarları, katılım satırı, nar zemin + ink
  metin "Buradayım"), soru-cevap kartı (honey "faydalı" sayacı), anket
  çubukları, sohbet balonları ve "Uçtan uca şifreli" satırı. Uygulama ile
  tanıtım sayfası aynı ürün gibi görünür.
- **Çok renkli kelime vurgusu** (tür adlarının brand/nar/mango hap içinde
  yazılması) yalnızca karşılama ve boş durum ekranlarında kullanılır.
- Dalga geçişleri ve uçuşan noktalar tanıtım sayfasına özgüdür; uygulamada
  kullanılmaz (Standartlar: süs hareketi yok).

### 3. Temel yapı

- Material 3 bileşenleri temel alınır; marka bunun üzerine `ThemeData` ve
  `ThemeExtension` ile verilir.
- Renkler `TayfamColors` (`ThemeExtension`), boşluk adımları `TayfamSpacing`,
  yarıçaplar `TayfamRadii`, süreler `TayfamMotion` olarak `core/tema/`
  altında tanımlanır; açık ve koyu değerler aynı token adlarını taşır.
- Ekranlarda ve widget'larda sabit renk (`Color(0x…)`, `Colors.*`), sabit
  boşluk ve yarıçap sayısı kullanılmaz; yalnızca token'lar. Bu kural CI'da
  bir kontrol betiğiyle denetlenir (`core/tema/` hariç).
- Ortak bileşenler (birincil/ikincil eylem, kart, etiket, etkinlik türü
  çipi, sohbet balonu, anket çubuğu, "çok yakında" rozeti) `core/bilesenler/`
  altında, Standartlar'daki tanımlarıyla bir kez yazılır; özellikler bunları
  kullanır.

### 4. Uygulama içi yazı ölçeği

Standartlar'daki Display (48–106 px) ve H2 (32–51 px) tanıtım sayfası
içindir. Uygulamada:

| Kullanım | Boyut | Ağırlık | Satır aralığı |
| --- | --- | --- | --- |
| Büyük başlık (karşılama, boş durum) | 28 px | 750 | 1.1 |
| Ekran başlığı (H3) | 22 px | 700 | 1.1 |
| Gövde | 17 px | 400 | 1.5 |
| İkincil metin | 15 px | 400 | 1.4 |
| Etiket | 13–15 px | 600–700 | 1.4 |

- Sistemdeki yazı büyütme ayarına uyulur; düzen 2× ölçekte de taşmadan
  çalışır. Gövde metni 13 px'in altına inmez.

### 5. Kırılım noktaları

- Genişlik < 600 px: alt gezinme çubuğu (ADR-0003).
- Genişlik ≥ 600 px: solda dikey gezinme çubuğu.
- İçerik en fazla 1120 px genişliktedir; kenar boşluğu mobilde 16 px,
  geniş ekranda 48 px'e kadar (Standartlar).

### Hareket ve erişilebilirlik

Standartlar'daki kurallar aynen geçerlidir: geçişler 150–250 ms, süs
animasyonu yok, "hareketi azalt" açıkken süs animasyonları kapalı, odak
çerçevesi 3 px (renk aşağıdaki nota göre), dokunma alanı en az 44 × 44 px (Material'in 48 dp
varsayılanı korunur), 320 px genişlikte yatay kaydırma yok. Arayüz PR'ları
ui-ux-pro-max'in teslim öncesi kontrol listesinden geçer (CLAUDE.md).

## Gerekçe

- Standartlar zaten ayrıntılı; burada yalnızca aktarım ve eksikler
  kararlaştırıldı.
- Gömülü font gizlilik ve çevrimdışı çalışma için gerekli.
- Koyu tema token'larla ucuz; açık temanın yalnızca iki rengi koyu zeminde
  yetersiz kaldığı için ek token'lar türetildi.
- Token zorunluluğu, alt oturumların ekran ekran farklı renk ve boşluk
  kullanmasını engeller.

## Sonuçlar

- Koyu tema token'ları, honey ve marka yüzeyi kuralı Notion'daki Tasarım
  Standartları'na eklendi.
- Kontrast testi ve token kontrol betiği CI'ın parçası olur.
- Bağımlılık eklenmez (Material 3 Flutter'la gelir).

## Değerlendirilen alternatifler

- **`google_fonts` ile çalışma anında indirme:** daha küçük uygulama, ama
  Google'a istek ve çevrimdışı sorun.
- **Yalnızca açık tema:** MVP'yi biraz kısaltır; sonradan eklemek token'lar
  olmadan yazılmış ekranlarda pahalı olurdu.
- **Material'den bağımsız kendi bileşen kütüphanesi:** tam kontrol, ama
  erişilebilirlik ve platform davranışlarını yeniden yazmak gerekir.

## Notlar

- **2026-11-10 (platform sahibi, issue #6 / PR #16):**
  1. **Odak çerçevesi rengi.** Mango, açık zeminde (surface, card) yalnızca
     1.74–1.83:1 verir; WCAG 2.2 odak görünümü 3:1 ister. Bu yüzden
     **açık temada açık zeminlerde odak çerçevesi `brand` (#5B2BE0)**:
     surface 6.95, card 7.33, tint-brand 5.97, tint-mango 6.48. **Koyu
     temada ve iki temada da mor yüzeyde (tayfa üst bölümü) mango**
     kalır (koyu zeminde 8.7–9.8, mor yüzeyde 4.0). Kalınlık 3 px, dış
     boşluk Standartlar'daki gibi 3 px (PR #16'daki 2 px düzeltilecek).
     Tasarım Standartları'na da işlendi.
  2. **Büyük başlık 750.** Gömülü font, google/fonts'taki değişken
     fonttan üretilen statik örneklerdir (`tool/font/bricolage_ornekle.py`);
     wght 750 örneği pubspec'te 800 ağırlık yuvasındadır.
  3. **"Çok yakında" rozetindeki nabız** süs değil durum göstergesi
     sayılır; "hareketi azalt" açıkken kapalıdır.
  4. **Beşinci token sınıfı `TayfamSizes`:** dokunma alanı, odak kalınlığı,
     ikon boyutu gibi temaya göre değişmeyen ölçüler. Ekranlarda bu sayılar
     da sabit yazılmaz. (CLAUDE.md'deki "Tema" satırı dört sınıf sayar;
     platform sahibi güncelleyecek.)
- **2026-11-10 (platform sahibi, PR #31): etkinlik türü renkleri.** Her
  etkinlik türünün kendi rengi ve ikonu vardır (Notion: Tasarım
  Standartları). Renk tek başına bilgi taşımaz; tür her zaman ikon ve adla
  gösterilir.

  | Tür (`EventType`) | Dolgu | Metin/ikon | İkon (Material) |
  | --- | --- | --- | --- |
  | konvoy (`convoy`) | mango #FFB000 | ink | `directions_car` |
  | kamp (`camp`) | orman yeşili #2F9E5B | ink | `cabin` |
  | yürüyüş (`hike`) | turkuaz #00C2A8 | ink | `hiking` |
  | balık (`fishing`) | deniz mavisi #3D8BEA | ink | `phishing` |
  | oyun (`gaming`) | açık: brand #5B2BE0; koyu: brand-dark #A98BFF | açık: beyaz; koyu: ink | `sports_esports` |
  | spor (`sports`) | nar #FF3D68 | ink | `sports_soccer` |
  | genel (`general`) | lavanta gri #8A7FA8 | ink | `event` |

  - Renkler `TayfamTurRenkleri` tema uzantısındadır
    (`core/tema/tayfam_tur_renkleri.dart`, `context.turRenkleri`); ham hex
    yalnızca orada. Her çift kontrast testinde 4.5:1'e karşı denetlenir.
  - Tür → görünüm eşlemesi `core/moduller/etkinlik_turu_kaydi.dart`'taki
    `default`'suz `switch`'tedir (API değeri, ARB ad anahtarı, renk
    anahtarı, ikon). Sunucunun henüz tanımadığımız türü
    (`EventType.unknown`) "genel" görünür.
  - Çipler, karşılamadaki tür hapları (§2a'daki brand/nar/mango sırası
    yerine) ve etkinlik kartları bu kayıttan beslenir; `CipVurgusu`
    kaldırıldı.
  - **Yeni tür ekleme:** Tayfam-Api'de sözleşme → üretici
    (`lib/core/api/gen/`) → kayıt girdisi + `TurRengi` anahtarı ve iki
    temada renk çifti + ARB adı (`etkinlik_turu_<değer>`) + kontrast
    testi. Derleyici, girdisi olmayan türü `switch`'te gösterir.
- **2026-11-12 (platform sahibi): yeni logo, hareket ve yazı ölçeği
  istisnaları.**
  1. **Logo "Dörtlü".** Eski "t" monogramı ("Hareket", `TayfamMonogram`)
     bırakıldı (Notion: Marka → Logo). Yeni ortak bileşen `TayfamLogo`
     (`core/bilesenler/tayfam_logo.dart`): tam renk (`TayfamLogo`,
     `TayfamLogo.yazili`), rozet (`TayfamLogo.rozet`) ve tek renk
     (`TayfamLogo.tekRenk`). Dört blok `assets/marka/logo/*.svg`'deki
     yollarla `CustomPainter` ile çizilir; SVG paketi yoktur. Blok renkleri
     sabittir (sol üst mango, sağ üst nar, sağ alt turkuaz); L parçası
     zemine göre: açık zeminde brand, koyu zeminde brand-dark #A98BFF, mor
     zeminde #FAF8FF. Ham renkler `TayfamLogoRenkleri`'ndedir
     (`core/tema/`). Uygulama ikonları, bildirim simgesi ve açılış
     ekranları aynı yollardan üretilir (`tool/ikon/`). PR #99.
  2. **Hareket istisnaları.** "Süs animasyonu yok" kuralının iki izinli
     istisnası vardır; ikisi de "hareketi azalt" açıkken oynamaz:
     - **Açılış logosu** (`AcilisLogosu`, `TayfamMotion.acilis*`): L,
       mango, nar ve turkuaz bloklar sırayla kurulur, yazı yükselir; ~820
       ms, **bir kez** oynar. Hareketi azalt açıksa logo doğrudan görünür.
       PR #101.
     - **Yükleniyor "Dalga"** (`TayfamYukleniyor`,
       `TayfamMotion.yukleniyor*`): bloklar saat yönünde 175 ms arayla
       1400 ms'lik döngüde küçülüp solar. "Çok yakında" nabzı gibi durum
       göstergesidir (Notlar 2026-11-10, madde 3); 1 saniyeden kısa
       beklemede gösterilmez. Hareketi azalt açıksa statik logo ve
       erişilebilir "Yükleniyor" etiketi. PR #103.
     Tanıtım sitesindeki logo kurulumu da aynı dili kullanır (yalnızca
     CSS, `prefers-reduced-motion`'a uyar; ADR-0013, PR #109).
  3. **Yazı ölçeği istisnası (§4).** Karşılama ekranlarında (giriş, kayıt
     sonrası hoş geldin, hoş geldin tanıtımı gibi) büyük ölçek serbesttir:
     48 px marka başlığı/slogan (`TayfamTypography.markaBasligi`: 48 / 800
     (wght 750) / 0.95, harf aralığı −%4.5) ve 24 px başlık
     (`TayfamTypography.girisBasligi`: 24 / 700 / 1.08, −%1). Uygulamanın
     geri kalanında §4'teki ölçek geçerlidir. PR #106.
  4. **Aynı işle gelen token'lar:** `TayfamColors.acilisZemini` (açılış
     zemini: açık temada brand, koyu temada ink); mor marka yüzeyinin
     altında iki temada da koyu temanın tür renkleri kullanılır (oyun
     brand-dark; brand zeminde brand dolgu görünmez).
- **2026-11-13 (platform sahibi, sohbette onaylandı): nar tonları, yıkıcı
  düğme ve tayfa ekranlarının ölçüleri.** Tayfa ana sayfası, menüsü ve
  ayarlarının yeniden tasarımıyla gelir (PR'lar: tayfa menüsü ve paneli,
  ana sayfa, ayarlar).
  1. **Yeni renk token'ları:** `tintNar` (açık #FFE1E8, koyu #4A1A26) ve
     `narMetin` (açık #B0123A, koyu #FF9FB4). Nar (#FF3D68) beyaz ve tint
     zeminde metin için yetersizdir; yıkıcı eylem metni, "Banlı" etiketi
     ve nar rozet bu ikiliyle çizilir. Ölçülen kontrast: açık temada
     nar-metin beyazda 7.0:1, tint-nar'da 5.7:1; koyu temada #FF9FB4
     tint-nar-dark'ta 7.4:1, ink'te 9.3:1.
  2. **Dolu yıkıcı düğme** (`YikiciEylem(dolu: true)`, `yikiciDolgu` /
     `yikiciDolguUstu`): açık temada nar-metin zemin + beyaz yazı (7.0:1).
     Koyu temada nar-metin (#B0123A) ink zeminde ayırt edilmez ve beyaz
     yazıyla zemini arasındaki fark düşer; bu yüzden **koyu temada #FF9FB4
     zemin + ink yazı (9.3:1)** seçildi. Çerçeveli yıkıcı düğme
     (`dolu: false`) nar-metin kenar ve yazıyla çizilir. Değerler
     `kontrast_test.dart`'ta korunur (≥4.5:1). Dolu yıkıcı düğme yalnızca
     yıkıcı onay penceresinin son düğmesidir (çıkarma, ban, silme, link
     iptali); ekrandaki ilk adım çerçeveli olandır.
  3. **Mor yüzeyin katmanları:** `markaYuzeyKutusu` (iki temada ink; mor
     üst bölümdeki "Sıradaki" kartı ve koyu kutular, beyaz yazı) ve
     `markaYuzeyKatmani` (iki temada #6F44E4; mor yüzeyin üstündeki açık
     katman, beyaz yazı 5.8:1; mango yalnızca rozet/ikon için, 3.2:1).
  4. **Yeni ölçüler (`TayfamSizes`, `TayfamRadii`):** tayfa avatarı 44,
     menü ikon kutusu 40, menü satırı 64, sayı rozeti 28, mor taşma 76,
     tarih kutusu 52×56, doluluk çubuğu 8, kurulum adımı dairesi 28,
     "Oluştur" düğmesinin altında bırakılan alan 96; seçim kartı yarıçapı
     16 (`TayfamRadii.secim`).
  5. **Yeni ortak bileşenler** (`core/bilesenler/`): `AltSayfaIcerigi` /
     `altSayfaAc` (alttan sayfa; yalnızca Oluştur, tayfa menüsü, tayfa
     geçişi, üye işlemleri ve yeni davet linki), `MenuSatiri` +
     `SayiRozeti`, `YikiciEylem`, `Etiket` (marka, mango, teal, nar
     tonları), `ListeKarti`. Renk yine tek başına bilgi taşımaz: etiketler
     metinli, rozetlerin ekran okuyucu etiketi vardır.
