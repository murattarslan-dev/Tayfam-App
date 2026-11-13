# Sohbet

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Sohbet-Kanallar.dc.html`](Sohbet-Kanallar.dc.html) | Sohbet · kanallar |
| [`Sohbet-Birebir.dc.html`](Sohbet-Birebir.dc.html) | Sohbet · birebir |
| [`Kanal-Akis.dc.html`](Kanal-Akis.dc.html) | Kanal · yavaş mod, gönderilemeyen mesaj |
| [`Kanal-Koyu.dc.html`](Kanal-Koyu.dc.html) | Kanal · koyu tema |
| [`Kanal-Islem.dc.html`](Kanal-Islem.dc.html) | Kanal · mesaja uzun basınca |
| [`Kanal-Formu.dc.html`](Kanal-Formu.dc.html) | Yeni kanal · yönetim |
| [`Birebir-Konusma.dc.html`](Birebir-Konusma.dc.html) | Birebir · güvenlik kodu notu, görüldü |
| [`Birebir-Menu.dc.html`](Birebir-Menu.dc.html) | Birebir · ⋯ seçenekleri |
| [`Mesaj-Istekleri.dc.html`](Mesaj-Istekleri.dc.html) | Mesaj istekleri |
| [`Birebir-Istek.dc.html`](Birebir-Istek.dc.html) | Gelen mesaj isteği |

## Kararlar ve notlar

Kullanıcı deneyimi kararları: (1) Sohbet sekmesi iki parçalı seçiciyle açılır (Kanallar | Birebir), her parçada okunmamış toplamı; açılışta okunmamışı olan parça seçili gelir, ikisinde de varsa Kanallar. (2) Kanallar aktif tayfanınkilerdir; üstteki tayfa satırı tayfa değiştirme panelini açar (ana sayfadakiyle aynı panel). (3) Kanal satırında son mesaj önizlemesi yok (sözleşmede yok); okunmamış sayı ve yavaş mod bilgisi var. Arşivdeki kanallar ayrı ekranda. 'Kanal aç' yalnızca yönetimde. (4) Birebir listesinde de önizleme yok: mesajlar uçtan uca şifreli ve diske yazılmıyor; satırda zaman, okunmamış sayı, sessizde simgesi, 'İstek gönderildi' durumu. Mesaj istekleri en üstte kart. (5) Mesaj akışında aynı yazarın ardışık mesajları gruplanır; kanalda ad ve avatar grubun başında, birebirde yok. Kendi mesajın sağda mor balon. Gün ayırıcı 'Dün', 'Bugün', sonra tarih. (6) Yavaş modda gönder düğmesi geri sayıma döner. (7) Gönderilemeyen mesaj nar kenarlı balon + 'Tekrar dene' / 'Sil' (aynı client_request_id). (8) 'Görüldü' yalnızca son kendi mesajının altında. (9) Güvenlik kodu değişimi akış içinde sarı sistem notu.

Veri ve kurallar: Channel (ad, görünürlük, yavaş mod, arşiv, unread_count), ChannelMessage (yazar, metin, silindi, restorable), Conversation (karşı taraf, durum, unread_count, karşı tarafın son okuduğu, last_message_at), DirectMessage (şifreli zarf). Adlar ve avatarlar mevcut kullanıcı adı önbelleğinden (bellekte). Kanal mesajında uzun basma: kendi mesajın ya da yönetimse 'Mesajı sil'; silinmiş ve geri alınabilir mesajda yönetime 'Geri al'. Kanal mesajı şikâyeti sözleşmede yok, eklenmez. Birebir mesajda uzun basma: 'Mesajı sil' (kendi), 'Şikâyet et' (gelen; açık metin cihazdan iletilir). Birebir ⋯: Profili gör, Sessize al (8 saat / 1 hafta / süresiz) — sesi açıkken 'Sesi aç'. Bildirimlerde içerik yok (kesin kural 7).
