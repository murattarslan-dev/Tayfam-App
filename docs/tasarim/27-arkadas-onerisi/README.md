# Arkadaş önerisi ve profilleme

> Sözleşme: Tayfam-Api PR #212 (issue #208, ADR-0030), commit `35bc26f`.
> İstemci issue'su: Tayfam-App #197. Notion "Faz 2 (v2) — Medya ve Sosyal"
> §4, §7a, §9.

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Oneri-Bildirim.dc.html`](Oneri-Bildirim.dc.html) | Bildirimler · öneri satırı (bekleyen, isteğin gönderildi, kapatıldı) |
| [`Oneri-Bildirim-Koyu.dc.html`](Oneri-Bildirim-Koyu.dc.html) | Aynısı · koyu |
| [`Arkadaslar-Oneriler.dc.html`](Arkadaslar-Oneriler.dc.html) | Arkadaşlar · "Önerilen kişiler" bölümü |
| [`Profilleme-Ayarlari.dc.html`](Profilleme-Ayarlari.dc.html) | Profil → Gizlilik · Profilleme ve Beni önerme anahtarları |
| [`Profilleme-Kapat-Onayi.dc.html`](Profilleme-Kapat-Onayi.dc.html) | Profillemeyi kapatma onayı |
| [`Profilleme-Kapali-Koyu.dc.html`](Profilleme-Kapali-Koyu.dc.html) | Profilleme kapalı · Beni önerme pasif · koyu |

## Kararlar ve notlar

Yeni bileşen yok: bütün parçalar mevcut ekranların bileşenleridir.

1. **Bildirim satırı** (`friend_suggestion`): 14-bildirimler'deki satırın
   aynısı. Tür ikonu arkadaşlık kategorisinde (mavi), metin
   "Arkadaş önerisi: {ad}" (ad `target_id`'nin profilinden; okunamazsa
   "Biri"), tayfa etiketi yok (tayfasız bildirim). Satır içinde, arkadaşlık
   isteğindeki Reddet / Kabul et düzeniyle **Kapat** (nötr hap) /
   **Arkadaş ekle** (dolu hap). İşlemden sonra düğmelerin yerinde teal tik:
   "İsteğin gönderildi" (karşı tarafın isteği bekliyorsa doğrudan
   "Artık arkadaşsınız") ya da "Bir daha önerilmeyecek". İşlem bildirimi
   okundu yapar. Satıra dokununca kişinin profili açılır.
2. **Yalnızca bekleyen öneri görünür.** Sözleşme: "İstemci `pending`
   olmayan öneri bildirimini göstermez." `resolution` yoksa (sunucu o an
   hesaplayamadı) da gösterilmez: geri çekilmiş bir öneri ("Beni önerme",
   engel, şikâyet) yanlışlıkla görünmesin diye güvenli taraf seçildi.
   Gösterilmeyen okunmamış öneri bildirimi liste okunurken sessizce okundu
   işaretlenir (mevcut okundu ucu; hata gösterilmez, sonraki okumada
   yeniden denenir), böylece rozet görünmeyen bildirimi saymaz (platform
   sahibi, 2026-11-16; sunucu değişikliği yok).
3. **Arkadaşlar ekranı**: istek kartının altında, liste boş değilse
   "Önerilen kişiler" bölümü (`GET /v1/me/friend-suggestions`, en çok 10).
   Satır, gelen istek satırının iskeleti: avatar + ad, altında Kapat /
   Arkadaş ekle. Sonuç kısa bildirimle ("Arkadaşlık isteği gönderildi." /
   "Öneri kapatıldı. Bir daha önerilmeyecek."); satır listeden düşer.
   Bölüm boşken, yüklenirken ya da okunamazsa hiç görünmez (istek kartıyla
   aynı kural; öneri ikincil bilgidir, ekranı hata ile doldurmaz).
4. **Gerekçe yok.** Kişi başına puan, ortak etkinlik sayısı ya da gerekçe
   gösterilmez; sözleşmede yoktur. Bölüm başlığının altındaki tek cümle
   özelliğin genel olarak ne yaptığını anlatır ("Birlikte katıldığınız
   etkinliklere göre önerilir; öneriyi yalnızca sen görürsün.").
5. **Profil → Gizlilik**: kartın en üstünde iki anahtar satırı
   (tayfa ayarlarındaki modül anahtarlarının iskeleti: başlık + kısa
   açıklama + sağda anahtar). "Profilleme" (varsayılan açık) ve "Beni
   önerme" (varsayılan kapalı). Değişiklik hemen kaydedilir
   (`PATCH /v1/me/social-settings`); işlem sürerken iki anahtar pasif,
   hata kısa bildirimle ve anahtar eski değerine döner.
6. **Profillemeyi kapatmak onay ister**: puanlar hemen silinir ve açık
   öneriler geri çekilir (geri alınamaz; yeniden açınca ertesi gün
   hesaplanır). Açmak ve "Beni önerme" onaysızdır.
7. **Profilleme kapalıyken "Beni önerme" pasif** ve açıklaması
   "Profilleme kapalıyken zaten kimseye önerilmezsin." olur (sunucu bu
   durumda zaten kimseye önermez; bu bir arayüz sadeleştirmesidir, yetki
   kararı değil).
8. **Durumlar**: ayarlar okunurken iki satır görünmez (kartın geri kalanı
   hemen kullanılabilir); okunamazsa iki satırın yerinde hata satırı ve
   "Tekrar dene". Öneri listesi için boş / yükleniyor / hata durumunda
   bölüm görünmez. İzin gerektiren bir adım yok.
9. **Push yok** (ADR-0030 §8): öneri yalnızca uygulama içi bildirimdir;
   push eşlemesine dokunulmaz.
10. **Erişilebilirlik**: anahtar satırının tamamı tek dokunma alanıdır
    (en az 64 dp), ekran okuyucu başlık + açıklama + açık/kapalı okur;
    hap düğmeler en az 48 dp; sonuç metni canlı bölgedir; renk tek başına
    bilgi taşımaz (tik + metin). 2× yazı ölçeğinde düğmeler satıra sarılır.

Metin eşlemesi: `bildirim_arkadas_onerisi`, `bildirim_sonuc_oneri_kapatildi`,
`arkadas_oneri_kapat`, `arkadas_ekle` (mevcut), `arkadas_oneriler_baslik`,
`arkadas_oneriler_aciklama`, `arkadas_oneri_kapatildi`,
`arkadas_istek_gonderildi` (mevcut), `profil_profilleme`,
`profil_profilleme_aciklama`, `profil_beni_onerme`,
`profil_beni_onerme_aciklama`, `profil_beni_onerme_pasif`,
`profil_profilleme_kapat_baslik`, `profil_profilleme_kapat_aciklama`,
`profil_profilleme_kapat_onay`, `profil_sosyal_ayar_yuklenemedi`.
