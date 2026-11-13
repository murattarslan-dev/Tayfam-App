# Listeler ve küçük ekranlar

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Arkadas-Istekleri.dc.html`](Arkadas-Istekleri.dc.html) | Arkadaşlık istekleri · gelen |
| [`Arkadas-Istekleri-Giden.dc.html`](Arkadas-Istekleri-Giden.dc.html) | Arkadaşlık istekleri · gönderdiğin |
| [`Tayfa-Davetleri.dc.html`](Tayfa-Davetleri.dc.html) | Tayfa davetleri |
| [`Engellenenler.dc.html`](Engellenenler.dc.html) | Engellenenler |
| [`Reddedilenler.dc.html`](Reddedilenler.dc.html) | Reddedilen mesaj istekleri |
| [`Katilimlarim.dc.html`](Katilimlarim.dc.html) | Katılım geçmişin (tümü) |
| [`Yeni-Konusma.dc.html`](Yeni-Konusma.dc.html) | Yeni birebir konuşma |
| [`Etkinlikler.dc.html`](Etkinlikler.dc.html) | Etkinlikler listesi |

## Kararlar ve notlar

Listeler: Arkadaşlık istekleri Gelen · N / Gönderdiğin seçici; gelende Reddet / Kabul et, gönderdiğinde 'İsteği geri çek' (yıkıcı çerçeveli). Tayfa davetleri: tayfa avatarı, ad, davet eden ve tarih, Reddet / Katıl; reddetmek davet edene bildirilmez. Engellenenler ve Reddedilenler aynı iskelet: açıklama (mevcut metinler), kişi satırı + tarih + çerçeveli eylem ('Engeli kaldır' onaylı, 'Listeden çıkar'). Katılım geçmişin (profilden 'Tümünü gör'): üstte görünürlük satırı ('Kim görür: …' + Değiştir → görünürlük sayfası), aya göre gruplanmış katılım kayıtları. Yeni birebir konuşma: ortada avatar, ad, mevcut 'henüz konuşman yok' açıklaması, şifreli notu; altta yazma alanı. Etkinlikler listesi (ana sayfadaki 'Tümü'): yalnızca yaklaşanlar (sözleşme), Bu hafta / Gelecek hafta / ay adına göre gruplar; satırda tarih kutusu, başlık (iptalde üstü çizili + 'İptal edildi'), 'Tür · gün saat · yer', cevabın ('Geliyorsun', 'Belki', 'Sırada') ya da 'Cevap ver'; yetkiliye başlıkta 'Etkinlik aç'. Geçmiş etkinlikler listesi yok (sözleşmede uç yok).

Metin eşlemesi: başlıklar `arkadas_istekler`, `arkadas_davetler_baslik`, `arkadas_engellenenler`, `birebir_reddedilenler`, `arkadas_katilimlarim_baslik`; açıklamalar `arkadas_engellenenler_aciklama`, `birebir_reddedilenler_aciklama`, `birebir_yeni_konusma_aciklama`; boş durumlar mevcut `*_bos` anahtarları. Etkinlikler listesinin başlığı, grup başlıkları ve "Etkinlik aç" düğmesi için yeni ARB anahtarı gerekir.
