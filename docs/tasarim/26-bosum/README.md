# "Boşum": boş vakit

Faz 2 (v2) §3; Tayfam-App #196, sözleşme Tayfam-Api ADR-0029 (#211). HTML
dosyaları diğer bölümlerle aynı biçimdedir (390×844, satır içi stil, hex
yalnızca referans; kişi adları örnektir).

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Bosum-Arkadaslar.dc.html`](Bosum-Arkadaslar.dc.html) | Arkadaşlar · "Boş vaktin" girişi ve rozetler |
| [`Bosum-Listem.dc.html`](Bosum-Listem.dc.html) | Boş vaktin · kendi günlerin |
| [`Bosum-Listem-Bos.dc.html`](Bosum-Listem-Bos.dc.html) | Boş vaktin · henüz gün yok |
| [`Bosum-Ekle.dc.html`](Bosum-Ekle.dc.html) | Boş gün ekle |
| [`Bosum-Duzenle.dc.html`](Bosum-Duzenle.dc.html) | Boş günü düzenle · alttan sayfa |
| [`Bosum-Arkadas-Gunleri.dc.html`](Bosum-Arkadas-Gunleri.dc.html) | Arkadaşın boş günleri · alttan sayfa |
| [`Bosum-Arkadas-Durumlar.dc.html`](Bosum-Arkadas-Durumlar.dc.html) | Arkadaşın boş günleri · yükleniyor, hata, boş, görünmüyor |
| [`Bosum-Koyu-Arkadaslar.dc.html`](Bosum-Koyu-Arkadaslar.dc.html) | Arkadaşlar · koyu tema |
| [`Bosum-Koyu-Ekle.dc.html`](Bosum-Koyu-Ekle.dc.html) | Boş gün ekle · koyu tema |
| [`Bosum-Koyu-Arkadas-Gunleri.dc.html`](Bosum-Koyu-Arkadas-Gunleri.dc.html) | Arkadaşın boş günleri · koyu tema |

## Akış

```
Profil ─ Arkadaşlar kartı ─ "Boş vaktin" ─┐
Arkadaşlar ─ "Boş vaktin" kartı ──────────┴─▶ Boş vaktin (/profil/arkadaslar/bos-vakit)
                                               ├─ "Boş gün ekle" ─▶ Boş gün ekle (…/bos-vakit/ekle) ─ Kaydet ─▶ geri
                                               └─ gün satırı ─▶ Düzenle (alttan sayfa): Kaydet · Bu günü sil
Arkadaşlar ─ satırdaki "Cumartesi boş" rozeti ─▶ Arkadaşın boş günleri (alttan sayfa) ─ "Mesaj gönder" ─▶ birebir
Arkadaşlar ─ satırın kendisi ─▶ kişi profili (değişmedi)
```

## Kararlar

Platform sahibinin ürün kararları (Notion Faz 2 §3, §9; ADR-0029): bildirim
yok; tüm arkadaşlar görür; giriş gün + dilim (sabah / öğleden sonra / akşam /
tüm gün; tüm gün tek başına), birden çok gün, en fazla 30 gün ileri, isteğe
bağlı 60 karakter not; rozet yalnızca önümüzdeki 7 gün içinde boş gün varsa;
dokununca 30 günün tamamı ve birebir mesaj. "Bir şey yapalım" (anlık etkinlik)
bu bölümde yok; anlık etkinlik istemci işi (#198) alttan sayfanın eylem
satırına ekler.

Bu bölümün arayüz kararları (mevcut bileşenlerle). PR #203 incelemesinde
(2026-11-16) kabul edildi: iki giriş noktası kalır, rozet ayrı düğmedir
(kişi profiline "Boş günleri" bölümü şimdilik yok), ekli günler devre
dışıdır, silme ayrı onay istemez.

1. **Giriş iki yerde, aynı satır.** Arkadaşlar ekranında üstteki düğmelerin
   ve istek kartının altında tek satırlık kart ("Boş vaktin", açıklama "N gün
   boşsun · arkadaşların görür" ya da "Boş günlerini arkadaşlarınla paylaş"),
   profildeki Arkadaşlar kartında dördüncü satır olarak. Bileşen: `ListeKarti`
   + `MenuSatiri.kartta` (ikon `event_available`, tint-brand kutu).
2. **Boş vaktin ekranı** tam ekran, `/profil/arkadaslar/bos-vakit`. Üstte
   gizlilik açıklaması (kim görür, bildirim yok, geçmiş günler silinir),
   `BirincilEylem` "Boş gün ekle", `BolumEtiketi` "Önümüzdeki günler" ve
   günler `ListeKarti` içinde. Satır: solda tarih kutusu (etkinlik listesindeki
   gün/ay kutusu; ortak bileşene taşındı: `TarihKutusu`), başlık gün adı ve
   tarih (`intl` tr: "21 Kasım Cumartesi"; bugün ve yarın için "Bugün",
   "Yarın"),
   açıklama dilimler ("Sabah · Akşam"), varsa not alıntı olarak. Satıra
   dokununca düzenleme alttan sayfası.
3. **Boş gün ekle** tam ekran, `/profil/arkadaslar/bos-vakit/ekle`; altta
   sabit kaydet çubuğu (`BirincilEylem`, seçilen gün sayısıyla "N günü
   kaydet"; gün ya da dilim seçilmemişse devre dışı). Günler: bugünden
   itibaren 31 gün (bugün + 30), ay başlıklarıyla gruplanmış çok seçimli
   çipler ("Sal 17"; bugün "Bugün", yarın "Yarın"). Zaten girilmiş günler
   kesik kenarlı, takvim ikonlu ve devre dışıdır (değiştirmek için listeden
   açılır); böylece bir kayıt farkında olmadan üzerine yazılmaz. Dilimler
   dört çip; "Tüm gün" seçilince diğerleri, diğerlerinden biri seçilince
   "Tüm gün" kalkar; altında kural yazılı. Not: etiketli tek satır alan, 60
   karakter sayaçlı; satır sonu, kontrol ve görünmez/yön karakterleri
   yazılırken süzülür (sözleşme). Kaydet her gün için ayrı `PUT` gönderir;
   biri başarısız olursa başarılılar seçimden düşer, hata kaydet çubuğunun
   üstünde `HataSatiri` olarak görünür, ekran açık kalır.
4. **Düzenleme** alttan sayfa (`altSayfaAc`): başlık gün, dilim çipleri, not,
   "Kaydet" ve yıkıcı çerçeveli "Bu günü sil". Silme ayrı onay istemez:
   sayfa açıp düğmeye basmak iki adımdır, silinen yalnızca kişinin kendi
   girdiği gündür ve hemen yeniden eklenebilir.
5. **Rozet** arkadaş satırında adın altında: `Etiket` (teal ton, takvim
   ikonu) "Bugün boş" / "Yarın boş" / "Cumartesi boş" (7 gün içinde olduğu
   için gün adı yeter). Rozet satırın içinde ayrı bir düğmedir (en az 48 dp
   dokunma alanı, ekran okuyucu: "Ece Yıldız: Cumartesi boş. Boş günlerini
   gör"); satırın geri kalanı eskisi gibi kişi profilini açar. Renk tek
   başına bilgi taşımaz: ikon ve metin var. Dilimler rozette yazmaz (kısa
   kalsın; alttan sayfada var).
6. **Arkadaşın boş günleri** alttan sayfa: üstte avatar ve ad, alt satır
   "Önümüzdeki 30 gündeki boş günleri", aynı gün satırları (oksuz, dokunulmaz),
   altta kişi profilindeki eylem kancasından gelen "Mesaj gönder" (birebir
   paketi; arkadaş olduğu için görünür, karar sunucuda).
7. **Saat yok.** Gün takvim günüdür; "bugün" Europe/Istanbul tarihidir
   (ADR-0029 §3). İstemci bugünü sabit UTC+3 ile hesaplar
   (`core/zaman/takvim_gunu.dart`; etkinlik tekrarındaki `istanbulFarki`
   aynı sabite bağlandı); dilim saate çevrilmez.
8. **Not sınırı kod noktasıdır.** Sunucu 60'ı Unicode kod noktası olarak
   sayar; sayaç ve sınır da kod noktası sayar (birleşik bir emoji birden çok
   sayılır), böylece sunucu sessizce `invalid-request` döndürmez.

## Durumlar

| Durum | Boş vaktin | Boş gün ekle | Arkadaşın günleri |
| --- | --- | --- | --- |
| Yükleniyor | `ListeDurumu` (Dalga, 1 sn altında görünmez) | Günler okunana kadar çipler yerine Dalga | Dalga |
| İlk yükleme hatası | `YuklemeHatasi` (ikon + tek cümle + Tekrar dene) | aynı | `HataSatiri` + "Tekrar dene" |
| Yenileme hatası (dolu) | Çekip yenileme; alttan kısa bildirim | — | — |
| Boş | "Henüz boş gün eklemedin. Eklediğin günler burada görünür." | Bütün günler girilmişse çipler devre dışı ve açıklama | "Şu an görünen boş günü yok." |
| Görünmüyor (`user-not-found`) | — | — | "Bu profil görüntülenemiyor" + açıklama (engellenme, arkadaşlıktan çıkma, silinme ayrılmaz; 23 ile aynı metin) |
| Kaydetme hatası | Düzenleme sayfasında `HataSatiri` | Kaydet çubuğunun üstünde `HataSatiri`; başarılı günler seçimden düşer | — |
| İzin | Platform izni yok | — | — |

Rozet yalnızca arkadaş listesinin cevabından gelir (`Friend.next_available`);
ayrı istek, bildirim, önbellek yoktur. Kaydetme ya da silmeden sonra kendi
liste ve profildeki açıklama yenilenir; arkadaş listesi kendi rozetini
göstermez (kişi kendi satırında yoktur).

## Tema ve yazı ölçeği

- Renkler yalnızca `TayfamColors` token'ları: rozet `tintTeal` + `tintTealUstu`
  (açık 5.7:1, koyu 8.0:1), seçili çip `marka` + `markaUstu`, devre dışı çip
  `metinIkincil`, yıkıcı düğme `narMetin`. Koyu temada aynı token'lar koyu
  değerlerine döner (koyu ekranlar).
- 2× yazı ölçeğinde: çipler `Wrap` ile satır kırar, rozet metni satır kırar,
  gün satırı yüksekliği büyür; kaydet çubuğu ve alttan sayfa kayar, kırpma yok.
- Hareket: yalnızca çip seçim geçişleri (Material, `TayfamMotion`); yeni
  animasyon yok.

## ui-ux-pro-max danışma notları

Aramalar (`--stack flutter`, `--domain ux`/`icons`; kullanıcı verisi yok):
"multi select date chips", "status badge list row", "chip selection
semantics", "bottom sheet form", "character count input limit", "destructive
delete undo confirmation", "text scaling overflow", "calendar icon available".
Uygulananlar: yerel ayarlı tarih (intl `tr`), çip ve rozette metin taşmasının
satır kırarak çözülmesi, görünür alan etiketi ve sayaç, gönderim sonrası
geri bildirim, rozet ve çiplerde anlamlı ekran okuyucu etiketi, ikonların
metin yanında gizlenmesi, en az 48 dp dokunma alanı. Skill'in "her silmeden
önce onay" önerisi bu ekranda uygulanmadı (karar 4'teki gerekçe). Palet ve
font önerisi alınmadı (Notion Marka ve Tasarım Standartları geçerli).

Metin eşlemesi: yeni anahtarlar `bosum_*` (app_tr.arb); görünmüyor durumu
mevcut `profil_goruntulenemiyor_*`, tekrar dene `yukleme_hatasi_tekrar_dene`.
