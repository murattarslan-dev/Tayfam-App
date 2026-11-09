# ADR-0004: Tema, token'lar ve bileşen dili

- **Durum:** Kabul edildi (koyu tema renkleri: Önerildi, platform sahibinin onayını bekliyor)
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Tarslan
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
  gitmemesi (KVKK, yurt dışı aktarım), çevrimdışı açılış ve CSP (web).
- Yedek font: platformun sistem fontu.

### 2. Koyu tema MVP'de, cihaz ayarını izler

- Uygulama açık ve koyu temayla gelir; varsayılan `ThemeMode.system`.
  Profil → Ayarlar'da açık / koyu / sistem seçilebilir.
- Standartlar'daki "surface → ink, metin → beyaz, logo gövdesi → teal"
  kuralı uygulanır. `ink-muted` koyu zeminde 2.47:1 kaldığı ve `brand` ink
  üzerinde 2.44:1 olduğu için koyu tema şu ek token'ları kullanır
  (**öneri, onay bekliyor**):

| Token (koyu) | Hex | Rol | Kontrast (ink #1B1036 / card-dark) |
| --- | --- | --- | --- |
| surface | #1B1036 (ink) | Sayfa zemini | — |
| card-dark | #261A47 | Kart yüzeyi | — |
| line-dark | #3A2D60 | Ayırıcı, kart kenarı (süs) | 1.47 / 1.31 |
| text | #FFFFFF | Ana metin | 17.89 / 15.90 |
| text-body-dark | #DCD6EE | Uzun gövde metni | 12.69 / 11.28 |
| text-muted-dark | #B4ABD1 | İkincil metin, giriş alanı kenarı | 8.25 / 7.33 |
| brand-dark | #A98BFF | Seçili durum, bağlantı, etkin sekme; üzerinde ink metin (6.66) | 6.66 / 5.92 |

- Vurgu renkleri (teal, mango, nar) koyu zeminde de aynıdır; hepsi ink
  üzerinde 4.5:1'in üstündedir (5.21–9.76). Giden sohbet balonu iki temada
  da `brand` zemin + beyaz metindir (~7:1).
- Giriş alanı kenarı gibi etkileşimli öğelerin sınırı en az 3:1 olmalıdır;
  `line-dark` yalnızca süs ayırıcıdır.
- Her renk çifti bir birim testinde WCAG kontrast eşiğine karşı denetlenir
  (metin 4.5:1, büyük metin ve arayüz öğesi 3:1).

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
çerçevesi 3 px mango, dokunma alanı en az 44 × 44 px (Material'in 48 dp
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

- Koyu tema renkleri onaylanınca Notion'daki Tasarım Standartları'na
  "Koyu tema" bölümü olarak eklenir.
- Kontrast testi ve token kontrol betiği CI'ın parçası olur.
- Bağımlılık eklenmez (Material 3 Flutter'la gelir).

## Değerlendirilen alternatifler

- **`google_fonts` ile çalışma anında indirme:** daha küçük uygulama, ama
  Google'a istek, çevrimdışı sorun ve CSP genişlemesi.
- **Yalnızca açık tema:** MVP'yi biraz kısaltır; sonradan eklemek token'lar
  olmadan yazılmış ekranlarda pahalı olurdu.
- **Material'den bağımsız kendi bileşen kütüphanesi:** tam kontrol, ama
  erişilebilirlik ve platform davranışlarını yeniden yazmak gerekir.
