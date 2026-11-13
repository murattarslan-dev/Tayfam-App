# Karşılama ve davet linki

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Karsilama.dc.html`](Karsilama.dc.html) | Karşılama · tayfası yok |
| [`Karsilama-Davetli.dc.html`](Karsilama-Davetli.dc.html) | Karşılama · bekleyen tayfa daveti |
| [`Karsilama-Bekleyen.dc.html`](Karsilama-Bekleyen.dc.html) | Karşılama · katılma isteği onay bekliyor |
| [`Davet-Onizleme.dc.html`](Davet-Onizleme.dc.html) | Davet linki · önizleme |
| [`Davet-Gonderildi.dc.html`](Davet-Gonderildi.dc.html) | Davet linki · onay bekliyor |
| [`Davet-Uye.dc.html`](Davet-Uye.dc.html) | Davet linki · zaten üye |
| [`Davet-Gecersiz.dc.html`](Davet-Gecersiz.dc.html) | Davet linki · açılamadı |

## Kararlar ve notlar

Karşılama (etkin tayfası olmayan kullanıcı): logo, 'Tayfanı bul, birlikte yola çık.', iki büyük seçim kartı: 'Tayfa kodum var' (birincil mor; mevcut kod sayfası, tasarım Tayfa-Kodu) ve 'Tayfa kur' (sihirbaz). Altında davet linki ipucu ve etkinlik türleri şeridi. Arkadaştan gelen tayfa daveti varsa (GET /v1/me/invitations) en üstte mango 'Seni bekleyen davet' kartı: tayfa adı, davet eden, Reddet / Katıl (mevcut uçlar; onaylı tayfada sonuç 'İsteğin gönderildi'). Birden çok davet varsa ilk kart + 'N davet daha' bağlantısı (tayfa davetleri ekranı). Bekleyen katılma isteği varsa üstte tint durum kartı + 'İsteği geri çek' (onaylı). Davet linki (giriş yapmışken): mor üst + beyaz kart, tayfa avatarı (harf; önizlemede kapak yok), ad, üye sayısı; mevcut açıklama; 'Tayfaya katıl' / 'Vazgeç'. Sonuçlar: onay bekliyor (teal kutu + Tamam), zaten üye (Tayfaya git), açılamadı (link ikonu, 'Tayfa kodum var' alternatifi). Önizlemede yalnızca sözleşmedeki alanlar (ad, üye sayısı, zaten üye); token hiçbir yere yazılmaz. Girişten önce gelen davet Giris-Davet tasarımındaki gibi.
