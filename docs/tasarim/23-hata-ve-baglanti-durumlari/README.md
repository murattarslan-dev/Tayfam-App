# Hata ve bağlantı durumları

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Durum-Cevrimdisi.dc.html`](Durum-Cevrimdisi.dc.html) | Bağlantı yok bandı |
| [`Durum-Yukleme-Hatasi.dc.html`](Durum-Yukleme-Hatasi.dc.html) | İlk yükleme hatası |
| [`Durum-Yenileme-Hatasi.dc.html`](Durum-Yenileme-Hatasi.dc.html) | Dolu listede yenileme hatası |
| [`Durum-Baglaniyor.dc.html`](Durum-Baglaniyor.dc.html) | Sohbet · Bağlanıyor… |
| [`Durum-Profil-Yok.dc.html`](Durum-Profil-Yok.dc.html) | Profil görüntülenemiyor |

## Kararlar ve notlar

Platform sahibi kararları (2026-11-15): Bağlantı yok → durum çubuğunun altında koyu ince bant ('Bağlantı yok · Bağlanınca güncellenir'), tüm sekmelerde aynı yer, içerik aşağı kayar; bağlantı hatasıyla düşen istek ya da kurulamayan canlı bağlantıyla açılır, ilk başarılı istekte kapanır (yeni paket yok). İlk yükleme hatası → başlık ve geri yerinde, ortada ikon + tek cümle (bağlantı yok ya da hata_genel) + 'Tekrar dene'; ekran zaten doluysa yalnızca alttan kısa bildirim + 'Tekrar dene'. Sohbet canlı bağlantısı koparsa birkaç saniye sonra başlığın alt satırı 'Bağlanıyor…' olur; gönderilen mesaj soluk ve 'Gönderiliyor' (aynı client_request_id ile REST'ten tekrar). Kişi profili açılamazsa tek ortak metin 'Bu profil görüntülenemiyor' (engellenme, silinme, bulunamama ayrılmaz) + 'Geri dön'.
