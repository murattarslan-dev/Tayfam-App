# Çekip yenileme

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Yenile-Cekiliyor.dc.html`](Yenile-Cekiliyor.dc.html) | Çekiliyor · bloklar yerine oturuyor |
| [`Yenile-Esik.dc.html`](Yenile-Esik.dc.html) | Eşik geçildi · Bırak, yenilensin |
| [`Yenile-Yenileniyor.dc.html`](Yenile-Yenileniyor.dc.html) | Yenileniyor · Dalga |
| [`Yenile-Ana-Sayfa.dc.html`](Yenile-Ana-Sayfa.dc.html) | Ana sayfa · mor zeminde |

## Kararlar ve notlar

Platform sahibi kararı (2026-11-15): Material'ın aşağı inen oku yerine sayfanın kendisi aşağı kayar; açılan boşlukta Yükleniyor animasyonunun logosu (03-yukleniyor, TayfamYukleniyor). Başlık çubuğu sabit kalır, altındaki içerik kayar; mor üst bölümlü ekranlarda (tayfa ana sayfası) boşluk mor ve L beyaz. Çekerken bloklar sırayla yerine oturur (mango → nar → turkuaz → L; ilerleme = çekme mesafesi / eşik); eşik 80 dp, geçince logo tamamlanır, hafif titreşim (HapticFeedback.lightImpact) ve metin 'Bırak, yenilensin'. Bırakınca boşluk 72 dp'ye oturur ve Dalga döngüsü oynar; yenileme bitince içerik yukarı kayarak yerine döner (TayfamMotion). Eşiği geçmeden bırakılırsa iptal. Çekme direnci artan (rubber band). Hareketi azalt açıksa bloklar animasyonsuz, yenilenirken statik logo + 'Yükleniyor'. Ekran okuyucu: 'Yenile' eylemi (semantik onRefresh) ve yenilenirken 'Yükleniyor' bir kez okunur. Ortak tek bileşen TayfamYenile, RefreshIndicator'ın yerine 27 kullanımda; yeni paket yok.
