# Profil · sözleşme bekleyenler

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Profil-Ad-Duzenle.dc.html`](Profil-Ad-Duzenle.dc.html) | Adı düzenle · sözleşme bekliyor |
| [`Profil-Dogum-Gunu.dc.html`](Profil-Dogum-Gunu.dc.html) | Doğum günü görünürlüğü · sözleşme bekliyor |
| [`Profil-Tamamla.dc.html`](Profil-Tamamla.dc.html) | Profil tamamlama formu · sözleşme bekliyor |

## Kararlar ve notlar

Bu üç ekran sözleşmede karşılığı olmadığı için kodlanmaz (ADR-0018 §2). Ad düzenleme: kayıttaki kural (1–40 karakter), değişiklik yoksa Kaydet kapalı; profildeki adın yanına kalem gelir. Doğum günü görünürlüğü: Proje Planı §4.7'deki üç seçenek, varsayılan 'yalnızca doğum günü', yalnızca arkadaşlar görür; profilde Gizlilik altında satır olur. Profil tamamlama: girişte cevapsız alan varsa açılır, her alanda bilgi notu, isteğe bağlı alanlarda 'Paylaşmak istemiyorum' (cevaplanmış sayılır), 'Daha sonra doldur' 7 gün göstermez. Hangi alanların sorulacağı Notion'da tanımlı değil; alan listesi kararlaşınca kart çoğaltılır. Sunucu işleri: Tayfam-Api #184 (ad), #185 (doğum günü görünürlüğü), #186 (profil tamamlama; alan listesi kararı bekliyor).
