# Etkinlik detayı

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Etkinlik-Detay.dc.html`](Etkinlik-Detay.dc.html) | Etkinlik detayı · tamamı (konvoy) |
| [`Etkinlik-Koyu.dc.html`](Etkinlik-Koyu.dc.html) | Etkinlik detayı · koyu |
| [`Etkinlik-Gunu.dc.html`](Etkinlik-Gunu.dc.html) | Etkinlik günü · Geldim |
| [`Etkinlik-Dolu.dc.html`](Etkinlik-Dolu.dc.html) | Kontenjan dolu · bekleme listesi |
| [`Etkinlik-Iptal.dc.html`](Etkinlik-Iptal.dc.html) | İptal edilmiş etkinlik |
| [`Etkinlik-Menu.dc.html`](Etkinlik-Menu.dc.html) | ⋯ · organizatör |
| [`Etkinlik-Katilimcilar.dc.html`](Etkinlik-Katilimcilar.dc.html) | Katılımcılar · bitişten sonra organizatör |
| [`Etkinlik-Turler.dc.html`](Etkinlik-Turler.dc.html) | Türe özel bölümler |
| [`Etkinlik-Sohbet.dc.html`](Etkinlik-Sohbet.dc.html) | Etkinlik sohbeti girişi · sözleşme bekliyor |

## Kararlar ve notlar

Kullanıcı deneyimi kararları: (1) Üst bölüm etkinlik türünün renginde (konvoy mango, kamp turkuaz…; tür kaydındaki renk), tür çipi, geri sayım çipi, başlık ve tayfa adı. Kapak görseli varsa zemin onun yerine geçer. (2) Üste taşan özet kartı 'ne zaman, nerede, kim, gidiyor muyum?' sorularını tek yerde cevaplar: tarih ve saat + takvime ekle simgesi, buluşma noktası adı ve ilçe/il, organizatör, katılım düğmeleri ve gelen/kontenjan çubuğu. (3) Etkinlik günü pencere açılınca (başlangıçtan 30 dk önce) 'Geldim' kartı özet kartının hemen altına çıkar; çevrimiçide 'Katıldım', yürüyüşte yerine yoklama. (4) Sonra: buluşma noktası haritası + 'Harita uygulamasında aç', açıklama, türe özel bölümler, katılımcı özeti (avatarlar + sayılar; dokununca Katılımcılar ekranı). (5) ⋯: organizatörde Düzenle ve İptal et; üyede Şikâyet et. (6) Kontenjan doluysa 'Geliyorum' seçilir, 'Sırada' etiketi ve bekleme metni çıkar. (7) İptalde üst bölüm soluk, 'İptal edildi' çipi, katılım düğmeleri yerine 'artık cevap verilemez' ve gerekçe kutusu.

Veri: Event (tür, başlık, açıklama, başlangıç/bitiş, buluşma noktası adı ve koordinatı, il/ilçe, çevrimiçi bağlantı, kontenjan, going/maybe/waitlist sayıları, senin cevabın, caller_can_manage, iptal ve gerekçe, seri) ve türe özel ayrıntılar; buluşma noktası gizlilik ayarı katılımcılara sınırlıysa üyeye 'Yer bilgisi yok'. Katılımcı adları profil önbelleğinden (bellekte). Araç plakaları yalnızca gelenlere ve organizatöre döner; tasarımda gösterilmedi. Katılımcılar ekranında organizatör, bitişten sonraki 7 gün içinde ⋯ ile 'Katılımı ekle' / 'Katılımı kaldır'. Etkinlik sohbeti girişi Tayfam-Api #183'e bağlı (sözleşme bekliyor).
