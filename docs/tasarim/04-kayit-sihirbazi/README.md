# Kayıt sihirbazı: Tayfam'la tanışma

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Kayit-Ad.dc.html`](Kayit-Ad.dc.html) | Kayıt 1 · Ad |
| [`Kayit-Dogum.dc.html`](Kayit-Dogum.dc.html) | Kayıt 2 · Doğum günü |
| [`Kayit-Teyit.dc.html`](Kayit-Teyit.dc.html) | Kayıt 2b · Tarih teyidi |
| [`Kayit-Referans.dc.html`](Kayit-Referans.dc.html) | Kayıt 3 · Referans kodu |
| [`Kayit-Onay.dc.html`](Kayit-Onay.dc.html) | Kayıt 4 · Onaylar |
| [`Kayit-Hosgeldin.dc.html`](Kayit-Hosgeldin.dc.html) | Kayıt · Hoş geldin |
| [`Kayit-Dogum-Koyu.dc.html`](Kayit-Dogum-Koyu.dc.html) | Kayıt 2 · koyu tema |
| [`Kayit-Hosgeldin-Davet.dc.html`](Kayit-Hosgeldin-Davet.dc.html) | Kayıt · Hoş geldin (davetle) |
| [`Kayit-Yas-Engeli.dc.html`](Kayit-Yas-Engeli.dc.html) | Kayıt · Hesap oluşturulamadı |
| [`Tayfa-Kodu.dc.html`](Tayfa-Kodu.dc.html) | Tayfa kodu · giriş |
| [`Tayfa-Kodu-Hata.dc.html`](Tayfa-Kodu-Hata.dc.html) | Tayfa kodu · bulunamadı |
| [`Tayfa-Kodu-Gonderildi.dc.html`](Tayfa-Kodu-Gonderildi.dc.html) | Tayfa kodu · istek gönderildi |

## Kararlar ve notlar

Her adım tek soru; Tayfam rozet avatarıyla sohbet balonunda soruyor, kullanıcının önceki cevabı giden balon olarak üstte kalıyor. Üstteki ilerleme göstergesi logonun dört bloğu: her adımda bir blok renklenir (mango → nar → turkuaz → mor L), kayıt bitince logo tamamlanır; yanında ekran okuyucu için 'Adım 2 / 4'. Gönderim son adımda tek istekle yapılır (POST /v1/registration); tarih teyidi gönderimden önce, ADR-0012'deki gibi yaş sınırından söz etmeden.
