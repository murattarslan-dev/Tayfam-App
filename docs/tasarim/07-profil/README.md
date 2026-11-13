# Profil

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Profil-Ana.dc.html`](Profil-Ana.dc.html) | Profil · tamamı |
| [`Profil-Koyu.dc.html`](Profil-Koyu.dc.html) | Profil · koyu tema |
| [`Profil-Foto.dc.html`](Profil-Foto.dc.html) | Profil fotoğrafı sayfası |
| [`Profil-Gorunurluk.dc.html`](Profil-Gorunurluk.dc.html) | Katılım geçmişi görünürlüğü |
| [`Profil-Arkadaslar.dc.html`](Profil-Arkadaslar.dc.html) | Arkadaşlar |
| [`Profil-Arkadas-Ekle.dc.html`](Profil-Arkadas-Ekle.dc.html) | Arkadaş ekle · kod bulundu |
| [`Kisi-Profili.dc.html`](Kisi-Profili.dc.html) | Kişi profili · arkadaş, ⋯ açık |
| [`Kisi-Profili-Yabanci.dc.html`](Kisi-Profili-Yabanci.dc.html) | Kişi profili · arkadaş değil |
| [`Profil-Oturumlar.dc.html`](Profil-Oturumlar.dc.html) | Oturumlar |
| [`Profil-Verilerim.dc.html`](Profil-Verilerim.dc.html) | Verilerimi indir |
| [`Profil-Hesabi-Sil.dc.html`](Profil-Hesabi-Sil.dc.html) | Hesabı sil |

## Kararlar ve notlar

Kullanıcı deneyimi kararları: (1) Profil 'kim olduğun ve seni nasıl bulurlar' ile açılır: fotoğraf, ad ve referans kodu kartı en üstte; Paylaş birincil, Kopyala ikincil, 'Yeni kod al' onaylı simge düğme. (2) Fotoğrafa dokununca alttan sayfa: galeriden seç, fotoğraf çek, kaldır. (3) Arkadaşlık istekleri ve tayfa davetleri profil girişinde nokta ile işaretlenir; sayı yalnızca ilgili ekranda, listeden. (4) Katılım geçmişinin son 3 kaydı profilde, yanında görünürlük çipi; çipe dokununca üç seçenekli sayfa, seçince hemen kaydedilir. (5) 'Başkaları nasıl görüyor' kendi kişi profilini açar (self). (6) Tema satır içinde üç parçalı seçici. (7) Çıkış yap düz düğme, Hesabı sil en altta nar-metin bağlantı; silme ekranında 'Önce verilerini indir' kısayolu. (8) Kişi profilinde ⋯: arkadaşlıktan çıkar, şikâyet et (target user), engelle. (9) Kişi profilinin altında her zaman görünür 'Bu kişiyi şikâyet et' bağlantısı (nar-metin); ⋯ menüsündeki 'Şikâyet et' ile aynı akışı açar. Şikâyet doğrudan platform yönetimine gider (Tayfam-Api #187); o gelene kadar bugünkü tayfa üzerinden akış.

Veri kaynağı: ad, fotoğraf, referans kodu, görünürlük (GET /v1/me/account); kod yenileme POST /v1/me/referral-code; görünürlük PATCH /v1/me/account; son katılımlar GET /v1/users/{kendi id}/activity (page_size 3); arkadaş avatarları GET /v1/me/friends ilk sayfası; istek/davet noktası mevcut gelenIstekVar/gelenDavetVar; oturumlarda yalnızca platform ve son kullanım var (cihaz modeli yok); kişi profili GET /v1/users/{id}/profile (friend_state, ortak tayfalar, activity_visible). Ad sözleşmede düzenlenemez (yalnızca kayıtta); Proje Planı §4.7 profil tamamlama formu ve doğum tarihi görünürlüğü sözleşmede yok, bu tasarıma girmedi. Tarih ve göreli zaman tr_TR.
