# Profil · ad, doğum günü ve tanıtım bilgileri

> Sözleşme: Tayfam-Api PR #188 (issue #184, #185, #186, #187). PR birleşip `lib/core/api/gen/` yeniden üretilmeden kodlanmaz.

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Profil-Ad-Duzenle.dc.html`](Profil-Ad-Duzenle.dc.html) | Adı düzenle |
| [`Profil-Dogum-Gunu.dc.html`](Profil-Dogum-Gunu.dc.html) | Doğum günü görünürlüğü |
| [`Profil-Tamamla.dc.html`](Profil-Tamamla.dc.html) | Profil tamamlama · 1 ilgi alanları |
| [`Profil-Tamamla-Hakkimda.dc.html`](Profil-Tamamla-Hakkimda.dc.html) | Profil tamamlama · 2 hakkımda (meslek, takım aynı) |
| [`Profil-Tamamla-Diller.dc.html`](Profil-Tamamla-Diller.dc.html) | Profil tamamlama · 3 diller |
| [`Profil-Tamamla-Sosyal.dc.html`](Profil-Tamamla-Sosyal.dc.html) | Profil tamamlama · 4 sosyal medya |
| [`Profil-Tamamla-Gorunurluk.dc.html`](Profil-Tamamla-Gorunurluk.dc.html) | Profil tamamlama · 5 kim görsün |
| [`Profil-Tanitim.dc.html`](Profil-Tanitim.dc.html) | Tanıtım bilgilerin |
| [`Kisi-Profili-Tanitim.dc.html`](Kisi-Profili-Tanitim.dc.html) | Kişi profili · hakkında bölümü |

## Kararlar ve notlar

Ad düzenleme: kayıttaki kural (1–40 karakter); değişiklik yoksa Kaydet kapalı; profildeki adın yanında kalem. Doğum günü görünürlüğü: üç seçenek, yalnızca arkadaşlar görür, seçildiği anda kaydedilir; profilde Gizlilik altında satır (Profil-Tanitim üzerinden de açılır). Profil tamamlama: her alanın altında bilgi notu; isteğe bağlı alanlarda "Paylaşmak istemiyorum" (cevaplanmış sayılır); "Daha sonra doldur" 7 gün göstermez.

Sözleşme geldi (Tayfam-Api PR #188, 2026-11-13); 'sözleşme bekliyor' şeritleri kaldırıldı, PR birleşince kodlanır. Ad: PATCH /v1/me/account display_name; 24 saatte en fazla 3 değişiklik (rate-limited), alanın altında sınır notu. Doğum günü: birthday_visibility = birthday (yalnızca gün ve ay, varsayılan) / full (doğum tarihi ve yaş) / hidden (kimse); seçenek sırası tasarımdaki gibi; yalnızca arkadaşlar görür; kendi profilinde her zaman tam tarih. Profil tamamlama: Account.profile_completion_pending true ise girişte açılır; yalnızca cevaplanmamış alanların adımları gösterilir, ilerleme çubuğu o sayıda bölümlü; son adım her zaman 'Kim görsün' (about_visibility; varsayılan friends_and_mutual). Adımlar: ilgi alanları (etkinlik türlerinden çoklu, en fazla 7), hakkımda (160, çok satır), meslek (60), takım (60) — ikisi hakkımda ile aynı tek satırlık iskelet, diller (ISO 639-1, en fazla 5, arama + onay kutusu; dil adları istemcide Türkçe listeden), sosyal medya (instagram / x / tiktok / youtube, '@' sabit önek, yalnızca kullanıcı adı; kural dışı değer satırın altında hata). 'Paylaşmak istemiyorum' declined_profile_fields'a ekler ve sonraki adıma geçer. 'Daha sonra doldur' POST /v1/me/profile-prompt/snooze (7 gün, sunucuda). Kişi profili: 'Hakkında' kartı (hakkımda metni, ilgi çipleri, doğum günü, meslek, takım, diller, sosyal medya bağlantısı; boş alan satırı hiç çizilmez; sosyal medya dokununca platformun bilinen adresi dış tarayıcıda). Kendi profilinde (Başkaları nasıl görüyor) tam doğum tarihi ve yaş. Profil → Gizlilik altına 'Tanıtım bilgilerin' satırı (Profil-Tanitim): alanları tek tek düzenleme (formun aynı adımı tek başına açılır), 'Kim görür' ve 'Doğum günün' satırları. Profilden şikâyet: POST /v1/me/reports target_type user; bağlantı ortak tayfa koşulu olmadan, profilini görebildiğin herkes için. Kanal: etkinlik kanalının katılımcıları salt okunur (Kanal-Katilimcilar-Etkinlik); seçili kişi kanalında Kişi ekle / Çıkar yalnızca kanalı açana görünür. listChannelMembers yalnızca kimlik döndürür, adlar profil ucundan. Etkinlik seçicide bitişi/iptali 7 günden eski etkinlik yok (event-ended); kanalı olan etkinlik 'Kanalı var' ile pasif (event-channel-exists).

Sözleşme eşlemesi: doğum günü seçenekleri sırasıyla `birthday` ("Yalnızca doğum günüm", varsayılan), `full` ("Doğum tarihim ve yaşım"), `hidden` ("Kimse"). Tanıtım görünürlüğü `friends_and_mutual` / `friends` / `none`. Hatalar: `invalid-display-name`, `rate-limited` (ad), `invalid-request` (form alanları; ilgili satırın altında genel hata metni).
