# ADR-0024: Dinamik tür kataloğu, bileşen kaydı ve ana sayfa bileşenleri (istemci, v3)

- **Durum:** Kabul edildi (platform sahibi, 2026-11-15)
- **Tarih:** 2026-11-15
- **Karar veren:** Ürün kararları platform sahibinindir (2026-11-15, Notion
  "Faz 3 (v3) — Dinamik Etkinlik Kataloğu ve Bileşenler"). Bu ADR onların
  istemci mimarisine taşınmasıdır.
- **İlgili:** [ADR-0002](0002-modul-yapisi.md),
  [ADR-0004](0004-tema-ve-bilesen-dili.md),
  [ADR-0005](0005-api-istemcisi.md),
  [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md),
  [ADR-0007](0007-websocket.md),
  [ADR-0008](0008-ceviri-ve-yerel-ayar.md),
  [ADR-0015](0015-etkinlik-ve-duyuru-modulleri.md);
  Tayfam-Api ADR-0025, ADR-0026, ADR-0027, ADR-0016

## Bağlam

Bugün etkinlik türleri istemcide koda gömülüdür: `EventType` enum'u,
`core/moduller/etkinlik_turu_kaydi.dart`'taki ad ve ikon tablosu,
`features/etkinlik/turler/<tür>/` altında tür başına araç bölümü ve
sihirbazda türe göre `switch` ile yazılan alanlar (ADR-0002, ADR-0015).
Yeni tür uygulama sürümü ister.

v3'te (Tayfam-Api ADR-0025) türler sunucudaki katalogda veri olur; ortak
**bileşenlerden** kurulur (rota, liste, yoklama, yazboz, kura, eşleşme
ağacı, ölçüm, günlük…). Yeni tür sürüm istemez; yeni bileşen ister. Tayfa
ana sayfası da yöneticinin açıp kapattığı ve sıraladığı bileşenlerden
oluşur (Tayfam-Api ADR-0027).

## Karar

### 1. Katalog

- `core/katalog/`: `GET /v1/catalog`'u açılışta, oturum açıldıktan sonra
  çeker; `If-None-Match` ile `catalog_version` gönderir. Yanıt **yalnızca
  bellekte** tutulur (ADR-0006; katalog kişisel değil ama diske içerik
  yazmama kuralına istisna açmaya değmez, yanıt küçüktür).
- Katalog yeniden çekilir: uygulama ön plana dönünce, en fazla saatte bir;
  ve tanınmayan bir tür anahtarıyla karşılaşınca bir kez.
- Eski bir etkinliğin tür sürümü güncel katalogda yoksa
  `GET /v1/catalog/event-types/{key}/versions/{version}` ile o sürüm çekilir,
  oturum boyunca bellekte kalır.
- Katalog gelmeden etkinlik listeleri çalışır: türün adı yerine
  "Etkinlik", ikon yerine genel ikon gösterilir; oluşturma sihirbazı katalog
  gelene kadar tür seçimini yükleniyor durumunda tutar.

### 2. Metinler ve ikonlar

- Tür, ilgi alanı ve alan adları katalogdaki `labels`'tan, uygulamanın
  yerel ayarına göre seçilir; seçilen dil yoksa `tr`. Bu, "kodda sabit
  kullanıcı metni yok / metinler ARB'de" kuralının (ADR-0008) **tek
  istisnasıdır**: katalog metinleri sunucudan gelen içeriktir, ARB'de olamaz.
  Bileşenlerin kendi arayüz metinleri, birimler ve hatalar yine ARB'dedir.
- Katalog metinleri kullanıcı içeriği gibi işlenir: düz metin olarak
  gösterilir, biçimlendirme ya da bağlantı yorumlanmaz, uzunluk sınırıyla
  kırpılır.
- İkon: katalogdaki `icon` anahtarı `core/katalog/ikonlar.dart`'taki sabit
  bir haritadan çözülür (Material Symbols alt kümesi; uygulamaya gömülü,
  ağdan ikon yüklenmez). Bilinmeyen anahtar → ilgi alanının ikonu → genel
  ikon. Haritaya yeni ikon eklemek sürüm ister; platform panelindeki ikon
  listesi bu haritadan üretilir (iki repo arasında aynı liste, CI'da
  karşılaştırılır).

### 3. Bileşen kaydı

`EtkinlikTuru` kaydının yerini **bileşen kaydı** alır:

```dart
abstract interface class EtkinlikBileseni {
  String get tur;                      // sözleşmedeki component kind: 'scoreboard'
  Widget? formBolumu(BilesenBaglami b); // oluşturma/düzenleme sihirbazında
  Widget? detayBolumu(BilesenBaglami b); // etkinlik detayında
  Widget? ozetSatiri(BilesenBaglami b);  // kartta tek satır (isteğe bağlı)
}
```

- Kayıt `shell/kayitlar.dart`'ta, koddaki sabit bir listedir (ADR-0002 ile
  aynı ilke: çalışma zamanında dışarıdan kod yüklenmez).
- `BilesenBaglami`: etkinlik, bileşenin tanımdaki `key`'i ve `params`'ı,
  çağıranın etkinlikteki rolü. Parametreler girdi kabul edilir ve
  doğrulanır; tanınmayan parametre yok sayılır.
- Etkinlik detay ekranı, tür tanımındaki `components` sırasıyla kayıttan
  bileşeni bulur ve bölümünü çizer. Bileşen kayıtta yoksa o bölümde
  **"Bu özelliği görmek için uygulamayı güncelle"** kartı (mağaza bağlantılı)
  gösterilir; etkinliğin geri kalanı çalışır.
- Bugünkü `turler/` klasörleri bileşenlere taşınır:
  `features/etkinlik/bilesenler/<bileşen>/` (`rota`, `liste`, `yoklama`,
  `araclar`, `gunluk`…). Konvoy, kamp, yürüyüş ve balık artık birer klasör
  değil, katalogdaki tanımlardır.
- Tür alanları (`fields`) kayda girmez: kapalı alan türü listesi
  (`text`, `long_text`, `integer`, `decimal`, `choice`, `multi_choice`,
  `boolean`, `date`, `duration`) için tek bir **alan çizici** vardır. Sınır
  ve zorunluluk tanımdan okunur ve formda doğrulanır; son söz sunucunundur.
  Tanınmayan alan türü içeren türde etkinlik oluşturma kapatılır (detay
  gösterilir, o alan atlanır).

### 4. Sihirbaz

Etkinlik sihirbazının adımları (ADR-0015 Notlar, 2026-11-13) korunur:
tür → başlık ve zaman → yer ya da bağlantı → türe özel → önizleme.

- **Tür adımı** katalogdan beslenir: önce tayfanın ilgi alanlarındaki
  türler, sonra "Tüm türler" (ilgi alanına göre gruplu, aranabilir).
  `retired` türler listelenmez.
- **Türe özel adım** tanımdaki alanları ve form bölümü olan bileşenleri
  sırayla gösterir. Bileşeni olmayan, alanı olmayan türde (Genel, Yoga…)
  adım atlanır.

### 5. Canlı bileşenler

Yazboz, eşleşme ağacı, kura ve canlı soru, WebSocket'ten gelen
`event.component_changed` çerçevesini dinler (ADR-0007, tek bağlantı).
Çerçeve yalnızca kimlik taşır; bileşen REST'ten yeniden çekilir. Ekran
açıkken abone olunur, kapanınca abonelik bırakılır. Bağlantı yoksa ekran
çekip yenileme ile çalışır.

Skor girişi çevrimdışı kuyruğa **girmez** (aynı skoru iki hakemin farklı
zamanlarda göndermesi sırayı bozar); bağlantı yoksa giriş düğmesi
kapalıdır.

### 6. Ana sayfa bileşenleri

- Ana sayfa (ADR-0015 §1 ve 2026-11-13 yeniden tasarımı) iki parçadır:
  sabit **Sıradaki** kartı ve sunucudan gelen `home_widgets` sırasıyla
  çizilen bileşenler.
- `TayfaModule` kaydı (ADR-0002) korunur; ana sayfa kartı olan modüller ve
  gösterim bileşenleri (`stats`, `goal`, `countdown`, `daily`,
  `champions`, `log_summary`) **ana sayfa bileşeni kaydına** girer:
  anahtar → kart. Tanınmayan anahtar ana sayfada atlanır.
- **Tayfa ayarları → Ana sayfa:** yalnızca yöneticiye görünür
  (sunucu `tayfa.home.update` iznini doğrular). Liste sürükle-bırakla
  sıralanır, her satırda aç/kapa. Tanınmayan bileşen "Uygulamayı güncelle"
  etiketiyle, değiştirilemez olarak listelenir. Kaydet tek istekle bütün
  listeyi gönderir.
- **Günün içeriği yönetimi:** yönetici ve moderatöre açık ayrı ekran:
  havuz listesi (sürükle-bırak), ekle/düzenle formu (metin, kaynak, isteğe
  bağlı tarih ve "Her yıl tekrarla"), sunucu `pin_conflict` dönerse uyarı.
  Kart yalnızca sunucunun o gün seçtiği içeriği gösterir; istemci seçim
  yapmaz.

### 7. Testler

- Test kataloğu (`test/fixtures/katalog.json`): bütün bileşen ve alan
  türlerini en az bir kez kullanan türler. Her kayıtlı bileşen bu katalogla
  açık ve koyu temada, 2× yazı ölçeğinde widget testiyle gelir (CLAUDE.md).
- Tanınmayan bileşen, tanınmayan alan türü, tanınmayan ikon, katalogda
  olmayan tür ve eksik dil için birim testleri.
- Katalog metinleri için uzunluk sınırı ve düz metin gösterimi testleri.

## Gerekçe

- **Kayıt kodda, tanım veride:** Sunucu ne tanımlarsa tanımlasın istemci
  yalnızca kendi bildiği bileşenleri çizer (CLAUDE.md "Doğrula"). Sunucudan
  düzen ağacı çizmek (server-driven UI) saldırı yüzeyini ve test yükünü
  büyütür; bileşenlerin davranışı zaten kod istiyor.
- **Bellek içi katalog:** ADR-0006'nın sadeliği korunur; katalog küçük ve
  her açılışta `304 Not Modified` ile ucuz.
- **Tek alan çizici:** Tür sayısı büyürken form kodu büyümez.
- **Skor kuyruğa girmez:** Çevrimdışı kuyruk tekrar gönderime karşı
  korur, ama birden çok yazarın sırasını korumaz.

## Sonuçlar

- `EventType` enum'u ve `etkinlik_turu_kaydi.dart` kalkar (Tayfam-Api
  ADR-0025 §10'daki geçiş dönemi bitince); `EtkinlikTuru` arayüzü
  `EtkinlikBileseni`'ne dönüşür (ADR-0002'nin "Etkinlik türü kaydı" bölümü
  yerine geçer; kabul edilince ADR-0002'ye not düşülür).
- ARB istisnası CLAUDE.md'ye yazılmalıdır (platform sahibinin
  değişikliği).
- Her yeni bileşen: istemci bileşeni + test + Tayfam-Api'de en düşük istemci
  sürümü kaydı.
- Ana sayfanın bugünkü sabit bölümleri (Yaklaşan, Duyurular, Açık anket,
  Son sorular) ana sayfa bileşeni kaydına taşınır.

## Değerlendirilen alternatifler

- **Tür kaydını korumak, türleri yine kodda eklemek:** v3 hedefiyle
  çelişir.
- **Sunucudan gelen düzen ağacı (server-driven UI):** Bkz. Gerekçe.
- **Katalogu diske yazmak:** Çevrimdışı ilk açılışta tür adlarını gösterirdi,
  ama ADR-0006'ya istisna açar; kazanç küçük.
- **Katalog metinlerini ARB'ye üretmek:** Yeni tür yine sürüm isterdi.
