# Etkinlik türü formları ve iptal

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Etkinlik-Av-Ekle.dc.html`](Etkinlik-Av-Ekle.dc.html) | Av ekle (balıkçılık) |
| [`Etkinlik-Malzeme-Ekle.dc.html`](Etkinlik-Malzeme-Ekle.dc.html) | Malzeme ekle (kamp) |
| [`Etkinlik-Malzeme-Liste.dc.html`](Etkinlik-Malzeme-Liste.dc.html) | Malzeme listesi · Ben getiririm |
| [`Etkinlik-Arac-Ekle.dc.html`](Etkinlik-Arac-Ekle.dc.html) | Aracını ekle (konvoy) |
| [`Etkinlik-Iptal-Penceresi.dc.html`](Etkinlik-Iptal-Penceresi.dc.html) | Etkinliği iptal et |

## Kararlar ve notlar

Platform sahibi kararları (2026-11-15): ekleme formları alttan sayfa; altta Vazgeç + Ekle, sayfa klavyeyle yukarı kayar. Av ekle: tür (60), boy cm (zorunlu, 0–1000), fotoğraf isteğe bağlı (GPS temizlenir), yer isteğe bağlı (harita seçici; cihaz konumu yok), 'Yerini kim görsün?' varsayılan Yalnızca ben (visibility self); yalnızca katılımı doğrulanan ve bitişten sonraki 7 güne kadar (not-attended, event-ended). Malzeme ekle: ad (60), adet sayaç (1–999), 'Kim getirecek?' Ben / Henüz kimse / Kişi seç (Kişi seç yalnızca organizatöre ve yönetime; etkinliğe gelenlerden). Listede boştaki malzemede 'Ben getiririm', kendi üstlendiğinde 'Vazgeç' — bunun için sözleşmede malzeme atamasını değiştiren uç gerekir (Tayfam-Api issue). Araç ekle: marka zorunlu (40), model (40), yıl, renk (30), plaka (16, isteğe bağlı; yalnızca gelenlere ve organizatöre görünür); yalnızca 'Geliyorum' diyenler. İptal: onay penceresi, gerekçe isteğe bağlı (500), dolu yıkıcı 'İptal et'; menüdeki 'Gerekçe istenir' metni 'Katılımcılara bildirim gider' olur.
