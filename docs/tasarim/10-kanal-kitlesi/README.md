# Kanal kitlesi: etkinlik ve seçili kişi kanalları

> Sözleşme: Tayfam-Api PR #188 (issue #183, ADR-0024). PR birleşip `lib/core/api/gen/` yeniden üretilmeden kodlanmaz.

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Kanal-Kitle.dc.html`](Kanal-Kitle.dc.html) | Yeni kanal · kimler görsün |
| [`Kanal-Kisi-Sec.dc.html`](Kanal-Kisi-Sec.dc.html) | Kanal · kişileri seç |
| [`Kanal-Etkinlik-Sec.dc.html`](Kanal-Etkinlik-Sec.dc.html) | Kanal · etkinliği seç |
| [`Kanal-Katilimcilar.dc.html`](Kanal-Katilimcilar.dc.html) | Kanal ayarları · katılımcılar |
| [`Kanal-Katilimcilar-Etkinlik.dc.html`](Kanal-Katilimcilar-Etkinlik.dc.html) | Etkinlik kanalı · katılımcılar |
| [`Sohbet-Kanallar-Ozel.dc.html`](Sohbet-Kanallar-Ozel.dc.html) | Kanal listesi · etkinlik ve seçili kişi kanalları |
| [`Kanal-Etkinlik-Bitti.dc.html`](Kanal-Etkinlik-Bitti.dc.html) | Etkinlik kanalı · bitti, kapanmak üzere |
| [`Kanal-Etkinlik-Arsiv.dc.html`](Kanal-Etkinlik-Arsiv.dc.html) | Etkinlik kanalı · arşivde |

## Kararlar ve notlar

Platform sahibi kararları (2026-11-13): Kanal kitlesi dört türlü: bütün tayfa, yalnızca yönetim, bir etkinliğe gelenler, seçili kişiler. Etkinlik kanalı canlıdır: 'Geliyorum' diyenler kendiliğinden girer, cevabı değişen çıkar; organizatör ve kanalı açan hep içeride; etkinlikten 7 gün sonra arşivlenir. Seçili kişi kanalını yönetim, etkinlik kanalını yönetim ya da o etkinliği yöneten (caller_can_manage) açar. Sonradan giren eski mesajları da görür; çıkarılan hiçbirini göremez, ona bildirim gitmez. Yönetim bu iki türe kendiliğinden girmez; kanalı açan (yönetici/moderatör ya da etkinlik organizatörü) hep içeridedir. Sunucu işi: Tayfam-Api #183.

Etkinlik bitince kanalın üstünde sarı bant (2026-11-13, platform sahibi): 'Kanal N gün sonra kapanacak' + arşiv tarihi; son gün 'Kanal yarın kapanacak', aynı gün 'Kanal bugün HH:MM'de kapanacak'. Kalan süre sunucunun verdiği arşiv zamanından (archive_at) istemcide hesaplanır, tr_TR. Bant kapatılamaz; sohbet kaydırılınca da üstte kalır. Arşivlenince yazma alanı yerine 'Bu kanal arşivlendi; yeni mesaj yazılamaz.' (mevcut metin). Sunucu: Tayfam-Api #183.

Sözleşme eşlemesi (PR #188): `visibility` `members` / `staff` / `event` / `selected`; `Channel.event_id`, `member_count` (listede "N kişi"), `archive_at` (bant). Katılımcılar `GET .../channels/{id}/members` (yalnızca kimlik; adlar `GET /v1/users/{id}/profile`). Seçili kişi kanalında "Kişi ekle" (`POST .../members`) ve "Çıkar" (`DELETE .../members/{user_id}`) yalnızca kanalı açana görünür; yönetim değiştiremez. Etkinlik kanalının katılımcıları salt okunurdur (`Kanal-Katilimcilar-Etkinlik`). Seçili kişi kanalını yönetici ve moderatör açar; etkinlik kanalını bunlar ve etkinliği yönetebilen (`caller_can_manage`) açar. Etkinlik seçicide bitişinin ya da iptalinin üzerinden 7 gün geçmiş etkinlik listelenmez (`event-ended`); zaten açık kanalı olan etkinlik pasif görünür (`event-channel-exists`). Yeni hata türleri: `event-channel-exists`, `not-tayfa-member`, `event-ended`.
