# ADR-0017: İlk açılışta hoş geldin tanıtımı

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Tarslan
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
  anket çubuğu, sohbet balonu, tür çipi, `MarkaYuzeyi`, monogram. Görsel
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
