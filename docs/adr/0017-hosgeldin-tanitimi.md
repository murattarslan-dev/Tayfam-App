# ADR-0017: İlk açılışta hoş geldin tanıtımı

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0003](0003-gezinme-iskeleti.md), [ADR-0004](0004-tema-ve-bilesen-dili.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0008](0008-ceviri-ve-yerel-ayar.md), [ADR-0012](0012-giris-ve-kayit-akisi.md); Notion: Marka (ton), Tasarım Standartları, Mağaza Sayfası

## Bağlam

Uygulamayı ilk kez açan kullanıcı doğrudan giriş ekranını görüyor ve
Tayfam'da neler yapabileceğini bilmiyor. Platform sahibi 3–5 sayfalık bir
tanıtım istiyor.

## Karar

### 1. Zaman ve kurallar

Platform sahibinin kararı (2026-11-11):

- Tanıtım ilk açılışta, **girişten önce** gösterilir.
- Cihazda **bir kez** gösterilir. "Gösterildi" bayrağı kullanıcı ayarı
  olarak güvenli depoda tutulur (ADR-0006). Bayrak cihaza aittir; oturum
  kapanınca silinmez.
- Her sayfada "Atla" vardır. Atlamak da tanıtımı tamamlanmış sayar.
- Son sayfadaki "Başlayalım" giriş ekranına geçer.
- Davet ya da referans linkiyle açılışta tanıtım yine gösterilir. Link
  kaybolmaz; tanıtım bitince işlenir. Bunu derin link işi bağlar; bu iş
  yalnızca yönlendirmede gecikmeye izin verecek kancayı bırakır.
- Ayarlar ya da profilden "Tanıtımı yeniden göster" seçeneği sonraki bir
  işe kalır.

### 2. Sayfalar

**Beş sayfa** var; katılım sayfası dahil (platform sahibi, 2026-11-11).
Metinler sen dilinde ve kısa; aşağıdakiler taslak metinler.

| # | Başlık | Metin | Görsel |
| --- | --- | --- | --- |
| 1 | Tayfan tek yerde | Kulübün ya da arkadaş grubun: planlar, duyurular, sorular ve sohbet artık grup sohbetinde kaybolmaz. | Mor tayfa üst bölümü (örnek tayfa adı) |
| 2 | Etkinlikler kimin geldiğini bilir | Geliyorum, belki ya da gelmiyorum de. Kontenjan dolunca bekleme listesi işler. Günü gelince "Geldim" demen yeter. | Örnek etkinlik kartı |
| 3 | Sorulan soru kaybolmaz | Duyurular ana sayfada durur. Sorular cevaplarıyla aranabilir kalır, kararlar anketle verilir. | Örnek anket çubukları ve "faydalı" sayacı |
| 4 | Sohbet de var, düzenli haliyle | Kanallar ve birebir mesajlar. Birebir mesajlar uçtan uca şifrelidir; konumun hiçbir yere kaydedilmez. | Sohbet balonları ve "Uçtan uca şifreli" satırı |
| 5 | Tayfana katıl ya da kendininkini aç | Davet linkine dokun, tayfa kodunu gir ya da kendi tayfanı birkaç adımda kur. | Etkinlik türü çipleri ve "Tayfa kodum var" / "Tayfa oluştur" görünümü (dokunulmaz) |

Soru-cevap, anket ve sohbet henüz yapılmadı. Pilottan önce hazır
olacakları için sayfalar şimdiden onları da anlatır (platform sahibi). Bu
modüllerden biri pilota yetişmezse metni çıkarılır.

### 3. Görsel dil

- Görseller **uygulamanın kendi bileşenleriyle** çizilir: etkinlik kartı,
  anket çubuğu, sohbet balonu, tür çipi, `MarkaYuzeyi`, logo (`TayfamLogo`;
  2026-11-12'ye kadar monogramdı, bkz. Notlar). Görsel
  dosyası kullanılmaz. Böylece iki temada ve büyük yazı ölçeğinde doğru
  görünür (platform sahibi).
- Örnek veriler tanıtım sitesindekiyle aynı ruhta ve uydurmadır: örnek
  tayfa ve etkinlik adları, kişi adı yerine baş harfler. Gerçek kullanıcı
  verisi yoktur.
- Görseller süs sayılır ve ekran okuyucudan gizlenir. Anlam başlık ve
  metindedir.
- Sayfa geçişi kaydırmayla ve "İleri" düğmesiyle yapılır. Sayfa
  göstergesi noktalarla gösterilir; ekran okuyucu "Sayfa 2 / 5" okur.
  "Hareketi azalt" açıksa geçiş animasyonsuzdur.
- Tanıtım ekranının üst bölümü mor marka yüzeyidir, metin alanı sade
  zemindir. Düğmeler `BirincilEylem` ve metin düğmesidir.

### 4. Yönlendirme

- Yönlendirme koruması (ADR-0003 `yonlendir`) yeni bir durum alır:
  tanıtım gösterilmediyse oturum yokken `/hos-geldin` adresine gidilir.
- Açılış sırası: sürüm denetimi → tanıtım → giriş (ADR-0012 §1).

## Sonuçlar

- Yeni paket yok.
- Bayrak, değerlendirme penceresinin bayrağıyla (ADR-0016) aynı küçük
  "cihaz ayarları" deposunda tutulabilir.

## Değerlendirilen alternatifler

- **Kayıttan sonra göstermek:** kullanıcı giriş yapmadan neyle
  karşılaşacağını göremez.
- **Yalnızca hazır özellikler:** platform sahibi, pilota kadar
  tamamlanacak modülleri de anlatmayı seçti.
- **İllüstrasyon:** dosya ve tasarım gerektirir, temaya uyumu zor.

## Notlar

- **2026-11-12 (platform sahibi):** §3'teki "monogram" artık yeni logo
  `TayfamLogo`'dur (ADR-0004 Notlar 2026-11-12; eski `TayfamMonogram`
  kaldırıldı, PR #99). Mor yüzeydeki tür çipleri iki temada da koyu temanın
  tür renklerini kullanır (PR #106). Hoş geldin tanıtımı bir karşılama
  ekranı olduğu için büyük yazı ölçeği (48 / 24 px) burada da serbesttir.
- **2026-11-13 (platform sahibi; tasarım `docs/tasarim/18-hosgeldin-tanitimi/`,
  issue #160):** Tanıtım yeniden tasarlandı; §3'teki "üst bölüm mor marka
  yüzeyi" kararının yerini şu alır: üstte küçük logo ve "Atla" (son sayfada
  "Atla" yok; §1'deki "her sayfada Atla" buna göre okunur, son sayfada
  "Başlayalım" zaten tamamlar). Her sayfanın zemininde sırayla marka, mango,
  turkuaz, nar ve marka renginin %14 tonunda açık bir bant
  (`TayfamSizes.tanitimBantSaydamligi`); üst çubuğun bandı kaydırırken iki
  sayfanın rengi arasında geçer. Görseller uygulamanın kartlarından yapılmış,
  hafif eğik örneklerdir (örnek tayfa, etkinlik kartı ve katılım, soru +
  anket, şifreli sohbet, üç katılma yolu); süstür ve ekran okuyucuya
  kapalıdır. Altta "Sayfa n / 5" (görünür; ekran okuyucuya noktalar okur),
  başlık (`TayfamTypography.tanitimBasligi`, 30 px) ve metin; en altta
  nokta ilerleme ve "İleri" / "Başlayalım" yan yana, büyük yazıda düğme
  alta iner. Hareket azaltma açıksa sayfa geçişi ve noktalar animasyonsuz.
  Akış (bir kez, girişten önce) değişmedi.
