# Etkinlik fotoğraf albümü

Issue #195; sözleşme Tayfam-Api #213 (ADR-0028); Notion "Faz 2 (v2) — Medya ve Sosyal" §2, §7a, §9; istemci [ADR-0025](../../adr/0025-etkinlik-fotograf-albumu.md).

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Album-Bolumu.dc.html`](Album-Bolumu.dc.html) | Etkinlik detayında Albüm bölümü · önizleme ızgarası, "Tümü", "Fotoğraf ekle", yükleme kartı |
| [`Album-Tumu.dc.html`](Album-Tumu.dc.html) | Albüm ekranı (Tümü) · 3 sütunlu ızgara, başlıkta ekle düğmesi |
| [`Album-Koyu.dc.html`](Album-Koyu.dc.html) | Albüm ekranı · koyu |
| [`Album-Ekle.dc.html`](Album-Ekle.dc.html) | Albüme ekle · çoklu seçim, biri hazırlanıyor |
| [`Album-Ekle-Tek.dc.html`](Album-Ekle-Tek.dc.html) | Albüme ekle · tek fotoğraf ve açıklama |
| [`Album-Goruntuleyici.dc.html`](Album-Goruntuleyici.dc.html) | Tam ekran görüntüleyici (her temada koyu) |
| [`Album-Goruntuleyici-Menu.dc.html`](Album-Goruntuleyici-Menu.dc.html) | Görüntüleyici ⋯ · Fotoğrafı sil / Şikâyet et |
| [`Album-Durumlar.dc.html`](Album-Durumlar.dc.html) | Bölümün durumları: yükleniyor, boş, katılım yok, başlamadı, kapandı, hata, yükleme hataları |
| [`Album-Durumlar-Koyu.dc.html`](Album-Durumlar-Koyu.dc.html) | Aynı durumlar · koyu |

Renkli kareler fotoğraf yerine geçer; gerçek görüntü değildir.

## Akış

1. **Detay → Albüm bölümü.** Etkinlik detayında türe özel bölümlerden ve anketlerden sonra, Katılımcılar'dan önce. Başlık "Albüm" (`AracBasligi`), sağında fotoğraf varsa "Tümü". Altında ilk 6 fotoğrafın önizlemesi (3 sütun, 4 dp aralık, `TayfamRadii.onizleme`). Ekleyebilene altta "Fotoğraf ekle" (`AracDugmesi`, çerçeveli hap, av günlüğündeki "Av ekle" ile aynı dil).
2. **Tümü → Albüm ekranı** (`/t/<tayfaId>/etkinlikler/<etkinlikId>/album`): sade üst çubuk (geri, "Albüm", altında etkinlik başlığı), ekleyebilene sağda ekle simge düğmesi; ızgara sayfalı (60'ar), sonda "Daha fazla"; çekip yenileme `TayfamYenile`.
3. **Karoya dokun → görüntüleyici** (tam ekran, her temada koyu): üstte Kapat, "4 / 23", ⋯; ortada tam varyant, iki parmakla yakınlaştırma; altta yükleyenin adı (dokununca profil), zaman, açıklama ve Önceki / Sonraki düğmeleri (kaydırmanın düğmeli karşılığı). Sona yaklaşınca sonraki sayfa okunur.
4. **⋯** alttan sayfa (`MenuSatiri`): "Fotoğrafı sil" (yıkıcı; kendi fotoğrafında, yönetimde ve organizatörde) onayla; "Şikâyet et" (kendi fotoğrafı değilse ve silemiyorsa; silebilen — yönetim ya da organizatör — şikâyet etmez, siler). Menüde satır yoksa ⋯ görünmez.
5. **Fotoğraf ekle:** kaynak sorulur (mevcut `fotografKaynagiSor`: Galeri / Kamera). Galeride çoklu seçim (en çok 30, sistemin izinsiz seçicisi). Ardından "Albüme ekle" alttan sayfası (`AracFormSayfasi`): seçilen fotoğrafların önizlemeleri sırayla hazırlanır (EXIF/GPS silinir); tek fotoğrafta "Açıklama (isteğe bağlı)" alanı (200), birden çokta açıklama yok. Gizlilik notu kutusu (`SihirbazBilgiKutusu`). "Vazgeç" + "Ekle" / "N fotoğraf ekle"; hazırlık bitmeden onay devre dışı. Okunamayan fotoğraf karoda hata ikonuyla kalır ve eklenmez.
6. **Yükleme** arka planda, sırayla: bölümde ve albüm ekranında ızgaranın üstünde yükleme kartı ("Fotoğraflar yükleniyor: 1 / 3", küçük önizlemeler, ilerleme çubuğu). Biten fotoğraf albümün sonuna eklenir (eskiden yeniye). Hatalı fotoğraf kartta kalır: metin + "Tekrar dene" (bağlantı/sunucu hatasında; aynı `client_request_id`) ve "Kaldır".

## Durumlar

- **Yükleniyor:** bölümde Dalga (`TayfamYukleniyor`, 1 sn'den kısa beklemede görünmez); albüm ekranında tam ekran Dalga; karolar yüklenirken nötr yüzey (`GorselYuzeyi`).
- **Boş:** "Albümde henüz fotoğraf yok." (+ ekleyebilene "Fotoğraf ekle"). İptal edilmiş ve boş etkinlikte bölüm hiç görünmez.
- **Ekleyemeyen** (kolaylık; karar sunucunun): başlamadan "Albüm etkinlik başlayınca açılır."; pencere açık ama katılım doğrulanmamış "Fotoğraf eklemek için önce varışını bildir."; bitişten 7 gün sonra "Albüm fotoğraf eklemeye kapandı."; iptalde bilgi yok.
- **İlk okuma hatası:** bölümde `HataSatiri` + "Tekrar dene" (av günlüğü gibi); albüm ekranında `YuklemeHatasi` (23 numaralı bölüm). Sonraki sayfa hatası ızgaranın altında satır.
- **Yükleme hataları:** `album-closed` → "Albüm şu an fotoğraf eklemeye kapalı."; `not-attended` → "Fotoğraf eklemek için etkinliğe katıldığın doğrulanmış olmalı."; `event-limit` → "Fotoğraf sınırına ulaşıldı: kişi başı 30, albüm başına 500."; `event-cancelled` → "Etkinlik iptal edildiği için albüme fotoğraf eklenemez." Bu dört hata kuyruğun geri kalanını da aynı metinle durdurur (boşuna yükleme yapılmaz) ve tekrar denenmez. Hazırlama, ret ve medya hataları mevcut `medya_hata_*` metinleriyle.
- **Silme hatası / şikâyet:** alttan kısa bildirim (mevcut `hataBildir`).

## Tema, yazı ölçeği, erişilebilirlik

- Açık ve koyu temada aynı iskelet; renkler `TayfamColors` (kart, çizgi, tint-marka, nar-metin), boşluk `TayfamSpacing`, yarıçap `TayfamRadii`. Görüntüleyici iki temada da koyu yüzeydir (fotoğraf odaklı; koyu tema token'larıyla çizilir).
- 2× yazı ölçeğinde: başlık sağındaki "Tümü" alt satıra iner (`AracBasligi`), yükleme kartı metni kayar, ızgara karoları kare kalır; görüntüleyicinin alt bölümü kayar.
- Ekran okuyucu: her karo "Albüm fotoğrafı 4 / 23" (açıklama varsa sonuna eklenir), düğme olarak; görüntüleyicide sayaç canlı bölge değil, sayfa değişince başlık okunur; ⋯ "Fotoğraf işlemleri"; Önceki/Sonraki düğmeleri kaydırmaya alternatiftir. Dokunma alanları en az 48 dp.
- Hareketi azalt: ek animasyon yok; yalnızca sistem sayfa geçişleri ve Dalga (zaten azaltılmış davranışlı).

## Kararlar ve notlar

Kararlar platform sahibinindir (2026-11-15, Notion §2, §9; Tayfam-Api ADR-0028): yükleme yalnızca katılımı doğrulanmış (organizatör işaretlemesi dahil) katılımcı, başlangıçtan bitiş + 7 güne kadar, kişi başı 30 / albüm 500; tüm tayfa üyeleri görür; silme kendi / yönetim / organizatör, rol hiyerarşisi yok; şikâyet edilebilir; açıklama isteğe bağlı 1–200; sıra eskiden yeniye. Bu bölümdeki ekran akışı (bölüm yeri, önizlemede 6 karo, görüntüleyicinin koyu yüzeyi, çoklu seçimde açıklamanın olmaması, alan kurallarına göre hatanın kuyruğu durdurması) PR #202 incelemesinde onaylandı (2026-11-16); silebilen organizatör de şikâyet etmez.

Yeni bileşen yok: bölüm `AracBasligi` / `AracDugmesi` / `AracBilgisi` / `HataSatiri`, form `AracFormSayfasi` / `SihirbazBilgiKutusu`, menü `altSayfaAc` / `MenuSatiri`, görseller `MedyaGorseli` ile. Ekrana özel yalnızca iki parça var: ızgara karosu ve yükleme kartı (mevcut bileşenlerden kurulur).

Metin eşlemesi: yeni ARB anahtarları `album_*` önekiyle; hata `album-closed` ortak eşlemede `hata_album_closed`.
