# Bildirimler

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Bildirimler.dc.html`](Bildirimler.dc.html) | Bildirimler · tamamı |
| [`Bildirimler-Koyu.dc.html`](Bildirimler-Koyu.dc.html) | Bildirimler · koyu |
| [`Bildirimler-Bos.dc.html`](Bildirimler-Bos.dc.html) | Boş · izin kartı |
| [`Bildirim-Ayarlari.dc.html`](Bildirim-Ayarlari.dc.html) | Bildirim ayarları (Profil) |

## Kararlar ve notlar

Platform sahibi kararları (2026-11-13): (1) Zamana göre gruplama: Bugün / Dün / Bu hafta / Daha eski (cihaz saat diliminde takvim günü; 'Bu hafta' son 7 gün). Satırda tür ikonu kategori renginde (etkinlik mango, duyuru ve soru marka, mesaj turkuaz, arkadaşlık ve davet mavi, iptal/uyarı nar, hesap marka), metin (mevcut çeviriler), tayfa adı etiketi ve zaman (bugün saat, dün saat, hafta içi gün adı, sonra '3 Kas'). Okunmamış: tint zemin, kalın metin, sağda nokta (ekran okuyucu 'Okunmadı'). Dokununca okundu + hedef ekran (mevcut bildirimAdresi). (2) Satır içi işlem: arkadaşlık isteğinde Reddet / Kabul et, tayfa davetinde Reddet / Katıl (mevcut uçlar); sonuçta düğmeler yerine teal tik + 'Artık arkadaşsınız' / 'Katıldın' ya da onaylı tayfada 'İsteğin gönderildi' ya da 'Reddedildi'; katılım isteğinde 'İncele' (katılım istekleri ekranı). İşlem bildirimi de okundu yapar. (3) Güvenlik uyarısı (hike_overdue) okunana kadar listenin en üstünde sabit nar kart: kişi adı, etkinlik adı ve tayfa (etkinlik ilgili uçtan çekilir), zaman, 'Yoklamayı aç' → etkinliğin yoklama bölümü. Birden çok uyarı varsa alt alta. (4) 'Hepsini okundu say' yalnızca okunmamış varken başlıkta. (5) İzin verilmemişse listenin üstünde mor izin kartı (mevcut metinler); 'Şimdi değil' mevcut erteleme kuralı. (6) DM bildiriminde gönderen yok (kesin kural 7). (7) Boş durum: logo + 'Henüz bildirimin yok.' + açıklama. (8) Bildirim ayarları: cihaz izni durumu + sistem ayarları, sessize alınan tayfalar listesi (GET /v1/notification-preferences; adlar tayfalarım listesinden) ve 'Sesi aç' (DELETE …/tayfas/{id}), birebir konuşmalar için yalnızca sayı ve yönlendirme, gizlilik notu. Filtre (okunmamış/tümü) yok: sözleşmede süzme parametresi yok.
