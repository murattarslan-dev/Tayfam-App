# Etkinlik oluşturma sihirbazı

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Sihirbaz-Tur.dc.html`](Sihirbaz-Tur.dc.html) | 1 · Tür |
| [`Sihirbaz-Bilgi.dc.html`](Sihirbaz-Bilgi.dc.html) | 2 · Başlık ve zaman |
| [`Sihirbaz-Yer.dc.html`](Sihirbaz-Yer.dc.html) | 3 · Yer (yüz yüze) |
| [`Sihirbaz-Harita.dc.html`](Sihirbaz-Harita.dc.html) | 3a · Buluşma noktası seçici |
| [`Sihirbaz-Ayrinti.dc.html`](Sihirbaz-Ayrinti.dc.html) | 4 · Ayrıntılar (konvoy) |
| [`Sihirbaz-Onizleme.dc.html`](Sihirbaz-Onizleme.dc.html) | 5 · Önizleme ve aç |
| [`Sihirbaz-Turler.dc.html`](Sihirbaz-Turler.dc.html) | 4 · türe göre alanlar |
| [`Sihirbaz-Koyu.dc.html`](Sihirbaz-Koyu.dc.html) | 1 · Tür · koyu |
| [`Sihirbaz-Rota.dc.html`](Sihirbaz-Rota.dc.html) | 4a · Konvoy rotası çiz |
| [`Sihirbaz-Tekrar.dc.html`](Sihirbaz-Tekrar.dc.html) | 4b · Tekrar: haftalık, belirli sayıda |
| [`Sihirbaz-Tekrar-Tarih.dc.html`](Sihirbaz-Tekrar-Tarih.dc.html) | 4c · Tekrar: aylık, son güne kadar |

## Kararlar ve notlar

Kullanıcı deneyimi kararları: (1) Her adım tek soru başlığı ('Ne tür bir etkinlik?', 'Ne zaman, ne yapıyoruz?', 'Nerede?', 'Son ayrıntılar', 'Her şey doğru mu?'); üstte 5 parçalı ilerleme ve 'Adım n / 5'; altta sabit Geri + İleri. Kapat (X) girilen bir şey varsa 'Vazgeçilsin mi?' sorar. (2) Tür adımında tayfanın ilgi alanlarındaki türler 'Tayfanın ilgi alanları' altında önde, diğerleri altta; her türün kısa açıklaması var. (3) Zaman iki büyük kutu: gün üstte küçük, saat büyük; bitiş aynı günse 'Aynı gün'. (4) Yer adımında Yüz yüze / Çevrimiçi seçici; yüz yüzede harita önizlemesi (nokta seçilince), yer adı, il, ilçe; çevrimiçide yalnızca bağlantı alanı. Harita seçici tam ekran, arama 'Ara'ya basınca (Nominatim kuralı), cihaz konumu yok. (5) Ayrıntılar adımı: kontenjan sayaç + 'Sınırsız' anahtarı, türe özel alanlar (yandaki pano), tekrar çipleri; tekrar seçilince aralık ve bitiş açılır. (6) YENİ 5. adım 'Her şey doğru mu?': etkinliğin özet kartı, her satırda 'Değiştir' o adıma döner; 'Etkinliği aç' burada. Düzenlemede de aynı sihirbaz, başlık 'Etkinliği düzenle', seri notu üstte.

Rota: 'Rota çiz' tam ekran harita açar; her dokunuş numaralı bir nokta ekler, noktalar mor çizgiyle sırayla bağlanır, başlangıç ve bitiş daha büyük. Alt panelde nokta sayısı, 'Son noktayı sil', 'Temizle' (onaylı) ve 'Rotayı kaydet' (en az 2 nokta). Cihaz konumu kullanılmaz. Kayıttan sonra 4. adımda rota küçük harita önizlemesi + 'Rotayı düzenle' olarak görünür. Tekrar: 4. adımdaki 'Tekrar' satırına dokununca bu ekran açılır; sıklık (Tek seferlik / Her hafta / Her ay), aralık sayacı (1–12), bitiş (Bitiş yok / Belirli sayıda: sayaç 2–52 / Belirli bir günde: tarih seçici, en çok 5 yıl). Altta seçimi düz Türkçe özetleyen kutu ('Her cumartesi 08:30, 6 kez: son etkinlik 20 Aralık'); özet istemcide RRULE'dan hesaplanır, tr_TR. 'Tamam' 4. adıma döner ve satırda özet yazar. Sayaç sınırları öneri; sözleşmedeki sınırlarla eşitlenir.
