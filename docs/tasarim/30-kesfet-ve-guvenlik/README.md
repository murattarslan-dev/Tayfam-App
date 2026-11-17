# Keşfet ve güvenlik ağı

> Sözleşme: Tayfam-Api PR #218 (issue #210, ADR-0033), commit `8ce2110`.
> İstemci issue'su: Tayfam-App #199; istemci kararı
> [ADR-0027](../../adr/0027-kesfet-ve-guvenlik-agi.md). Notion "Faz 2 (v2) —
> Medya ve Sosyal" §6, §7a, §9; "Kötüye Kullanım ve Genç Kullanıcı
> Güvenliği" → "Keşfet tasarımı"; "Marka" (ses tonu); "Tasarım
> Standartları".

İlke (platform sahibi): **Keşfet güven vermez, bilgi verir.** Hiçbir
ekranda "güvenilir", "onaylı", "doğrulanmış tayfa" gibi vaat yoktur;
yalnızca olgular (kuruluş tarihi, etkinlik sayısı, doğrulanmış katılım
sayısı) ve arkadaşların bu etkinliğe gittiği bilgisi gösterilir.
"Doğrulanmış katılım" bir kişinin varış bildiriminin sayısıdır; tayfaya
dair bir onay değildir.

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Kesfet-Akis.dc.html`](Kesfet-Akis.dc.html) | Keşfet akışı · kartlar (arkadaşlar, etkinlik, tayfanın olguları) |
| [`Kesfet-Akis-Koyu.dc.html`](Kesfet-Akis-Koyu.dc.html) | Aynısı · koyu · bir kartta "İsteğin gönderildi" |
| [`Kesfet-Bos.dc.html`](Kesfet-Bos.dc.html) | Boş akış |
| [`Guvenlik-Kisisi.dc.html`](Guvenlik-Kisisi.dc.html) | Etkinlik detayı · güvenlik kişisi kartının durumları |
| [`Guvenlik-Kisisi-Sec.dc.html`](Guvenlik-Kisisi-Sec.dc.html) | Güvenlik kişisi seçme (alttan sayfa) |
| [`Geri-Bildirim.dc.html`](Geri-Bildirim.dc.html) | Etkinlik detayı · "Her şey yolunda mıydı?" |
| [`Guvenlik-Paylasimlari.dc.html`](Guvenlik-Paylasimlari.dc.html) | Profil → "Güvenlik kişisi olduğun etkinlikler" |
| [`Tayfa-Ayar-Kesfet.dc.html`](Tayfa-Ayar-Kesfet.dc.html) | Tayfa ayarları · Keşfet bölümü ve durum metinleri |

## Kararlar ve notlar

Yeni bileşen yok: kartlar `TayfamKart`, satırlar `ListeKarti` +
`MenuSatiri`, durumlar `Etiket`, düğmeler `BirincilEylem` /
`CerceveliHapEylem` / `BaglantiEylemi`, alttan sayfa `altSayfaAc` +
`AltSayfaIcerigi`, anahtarlar tayfa ayarlarındaki modül anahtarlarının
iskeleti (`SwitchListTile`), yükleme `TayfamYukleniyor`, hata
`YuklemeHatasi` / `HataSatiri`. Güvenlik kartı varış bildiriminin tint
kart iskeletini kullanır (ADR-0015 §5).

### Bayraklar

1. **Keşfet bayrağı kapalıyken** (`404 feature-disabled`) Keşfet'in
   bütün girişleri görünmez: tayfa değiştirme panelindeki ve karşılama
   ekranındaki "Keşfet" satırı, etkinlik sonrası "Her şey yolunda
   mıydı?" kartı. İstemci bayrağı ayrıca sormaz; akışın kendisi okunur
   (bellekte, oturum boyunca), cevap `feature-disabled` ise girişler
   gizlenir. Akış başka bir hatayla okunamazsa da giriş gizli kalır
   (yanlışlıkla açık bir özellik vaat edilmez); sonraki açılışta yeniden
   denenir.
2. **Güvenlik kişisi ayrı bayraktır** ve Keşfet kapalıyken de çalışır.
   Etkinlik kartını `GET …/safety-contact` belirler: `feature-disabled`
   ise kart görünmez. "Döndüm" ve kaldırma bayraksızdır; kart görünürken
   her zaman kullanılabilir.
3. **Bayraktan bağımsız olanlar** her zaman görünür: tayfa ayarlarındaki
   "Keşfet'te göster", sihirbazdaki "Halka açık yerde buluşur", üye
   listesindeki "Keşfet'ten" etiketi ve profildeki "Keşfet'te arkadaşlarım
   görebilsin" (gizlilik ayarı; kişi özellik açılmadan önce kapatabilsin
   diye — açık soru 1).

### Keşfet akışı (`/kesfet`)

4. Tam ekran (tayfa sihirbazı gibi kabuğun üstünde); başlık "Keşfet".
   Üstte tek paragraf: ne gösterildiği ve **olgu notu**: "Kartlardaki
   sayılar tayfanın geçmişinden gelir. Tayfam tayfalara kefil olmaz;
   katılmadan önce arkadaşına sorabilirsin." (Marka: gizlilik ve güven
   vaatleri abartılmaz.)
5. **Kart** (`TayfamKart`, dokunulamaz; içinde tek düğme):
   - Üstte arkadaşlar: en çok 3 avatar ve "Ayşe bu etkinlikte" /
     "Ayşe ve 2 arkadaşın bu etkinlikte" (`friend_count - 1`; sayı
     yalnızca görünen arkadaşlardır, sunucu sayar).
   - Etkinlik: tür çipi (`EtkinlikTuruCipi`), başlık, gün ve saat
     aralığı, il/ilçe (varsa). Açıklama, buluşma yeri ve harita **yok**
     (sözleşmede yok; tayfaya katılınca görünür).
   - Tayfa: avatar (baş harf) + ad, il; açıklama en çok 3 satır; olgular
     tek satırda nokta ile: "Mart 2024'ten beri · 12 etkinlik · 87
     doğrulanmış katılım". 0 da yazılır ("0 etkinlik"): yeni tayfa
     olduğu bilgidir.
   - Düğme: "Katılım isteği gönder" (`CerceveliHapEylem`).
6. **Katılım** her zaman onay bekler (sözleşme). Düğme onay sorar:
   "Katılım isteği gönderilsin mi? … tayfasının yöneticileri isteğini
   görür ve onaylarsa katılırsın. Buluşma yeri ve ayrıntılar katılınca
   görünür." Başarıda düğmenin yerinde teal tik + "İsteğin gönderildi.
   Yöneticiler onaylayınca katılırsın." (öneri satırının sonuç
   iskeleti); tayfa listesi yenilenir (bekleyen istek panelde "Onay
   bekliyor" olarak görünür). `already-pending` de "İsteğin gönderildi"
   sayılır; `already-member` "Bu tayfanın zaten üyesisin."; tayfa artık
   akışta değilse (`tayfa-not-found`) kısa bildirim ve akış yenilenir.
7. **Durumlar:** yükleniyor (`TayfamYukleniyor`, gecikmeli), boş ("Şimdilik
   burada bir şey yok" + ne zaman dolacağı), yükleme hatası
   (`YuklemeHatasi` + "Tekrar dene"), Keşfet bu sırada kapandıysa
   (`feature-disabled`) "Keşfet şu an kullanılamıyor" orta durumu.
   Aşağı çekip yenileme vardır. İzin gerektiren adım yok. Sayfalama yok
   (sözleşme: en çok 50).

### Güvenlik kişisi (etkinlik detayı)

8. Kart, varış bildiriminin altında, yalnızca **yüz yüze ve iptal
   edilmemiş** etkinlikte görünür. Kişi seçilmemişse: "Geliyorum"
   denmiş ve etkinlik bitmemiş olmalı. Seçilmişse: bitiş + tolerans +
   24 saate kadar (alarm ya da "Döndüm" bilgisinin kaybolmaması için;
   sunucunun paylaşım listesiyle aynı pencere). Kart nötr kart
   zeminindedir (`TayfamKart`); durum etiketi ve ikonu tonu taşır.
9. **Seçilmemiş** (etkinlik bitmemiş): başlık "Güvenlik kişisi",
   açıklama "Bir arkadaşını seç: etkinlik bitince belirlediğin süre
   içinde 'Döndüm' demezsen ona haber verilir. Yalnızca adını, gün ve
   saat aralığını ve döndüğünü görür; tayfayı, etkinliği ve buluşma
   yerini görmez." + "Güvenlik kişisi seç". Etkinlik bittiyse ve kişi
   seçilmemişse kart görünmez.
10. **Seçili, dönülmemiş:** "Güvenlik kişin: Ayşe" + "Bitişten 1 saat
    sonra 'Döndüm' demezsen Ayşe'ye haber verilir." Düğmeler: "Döndüm"
    (birincil; etkinlik başladıktan sonra), "Değiştir" ve "Kaldır"
    (bağlantı; kaldırma onay ister). Seçilen kişiye seçildiği anda
    bildirim gitmez (sözleşme); metin bunu söyler: "Ayşe'ye şimdi bir
    şey gönderilmez."
11. **Döndü:** teal tik "Döndüğünü işaretledin · 22:14". İşlem yok.
12. **Alarm gitti, dönmedi:** nar uyarı "Ayşe'ye haber verildi." +
    "Döndüm" (kişiye durumun "döndü" olarak görünmesi için); kaldırma
    yok (sözleşme: alarmdan sonra kaldırılamaz).
13. **Seçme sayfası** (alttan): arkadaş listesi (avatar + ad, tek seçim,
    `RadioListTile` değil `MenuSatiri` + seçili işareti — tayfa
    değiştirme panelinin seçili satır iskeleti), altında tolerans
    çipleri: 30 dk · 1 saat · 2 saat · 4 saat (varsayılan 1 saat;
    sözleşme 15–1440 dk), "Kaydet". Arkadaş yoksa "Güvenlik kişisi
    seçmek için önce bir arkadaş eklemelisin." Liste ilk sayfadır (en
    çok 100); arama yok (açık soru 3).
14. Hata kodları çeviriden: `event-not-going`, `not-friends`,
    `safety-contact-closed`, `safety-contact-not-found`.

### "Her şey yolunda mıydı?" (etkinlik detayı)

15. Yalnızca "halka açık yerde buluşur" (`discoverable`) işaretli, yüz
    yüze, iptal edilmemiş ve katılımı doğrulanmış (`attended`)
    etkinlikte, bitişten bitiş + 7 güne kadar; Keşfet bayrağı kapalıysa
    görünmez.
16. Kart: soru + "Cevabını yalnızca sen görürsün; tayfaya söylenmez."
    Üç seçim (hap, tek seçim, seçili olan tikli): "Evet, yolundaydı" ·
    "Pek değildi" · "Ciddi bir sorun vardı". Serbest metin yok
    (sözleşme). Cevap 7 gün içinde değiştirilebilir.
17. "Ciddi bir sorun vardı" seçilince kaydedildikten sonra pencere:
    "Anlatmak istersen tayfayı şikâyet edebilirsin; şikâyet yalnızca
    Tayfam'a gider. Acil bir tehlike varsa 112'yi ara." → "Tayfayı
    şikâyet et" (mevcut şikâyet sayfası, hedef `tayfa`; tayfa
    yöneticileri görmez) / "Vazgeç" (ortak onay penceresi). Etkinlik şikâyeti seçilmedi:
    o tayfanın moderasyon kuyruğuna düşer ve şikâyet edeni yöneticiye
    gösterirdi.

### Güvenlik kişisi olduğun etkinlikler (`/profil/guvenlik`)

18. Giriş: Profil'in "Arkadaşlar" bölümünde satır ("Güvenlik kişisi
    olduğun etkinlikler", "2 kişi"), yalnızca liste boş değilse; ayrıca
    `safety_alert` bildirimi buraya açılır.
19. Satır: avatar + ad, "15 Kasım Cumartesi · 19:00 – 22:00", durum
    etiketi: "Dönmedi" (nötr, alarm zamanı gelmemiş), "Döndü · 22:40"
    (teal), "Haber verildi · 23:00" (nar). Tayfa, etkinlik başlığı ve
    yer **yoktur** (sözleşme ve platform sahibi kararı). Satıra dokununca
    kişinin profili açılır (mesaj göndermek için).
20. Alarmlı satırın altında: "Ona ulaşmayı dene. Acil bir tehlike
    düşünüyorsan 112'yi ara."
21. Durumlar: yükleniyor, boş ("Seni güvenlik kişisi seçen olunca
    burada görürsün."), hata + tekrar dene, bayrak kapalı ("Bu özellik
    şu an kullanılamıyor").

### Bildirim ve push

22. `safety_alert`: satır metni "{ad} henüz 'Döndüm' demedi" (ad
    `target_id`'nin profilinden; okunamazsa "Biri"), uyarı ikonu;
    okunmamışken listenin üstünde sabit durur (`hike_overdue` gibi).
    Dokununca `/profil/guvenlik`.
23. Push metinleri ARB'den (`push_safety_alert_title` / `_body`); ad,
    etkinlik ve yer yazılmaz. Uyarılar kanalına gider (sunucu).

### Yönetim

24. **Tayfa ayarları → "Keşfet" bölümü** (yalnızca yönetici; Modüller'in
    altında): anahtar "Keşfet'te göster" ve altında durum:
    - `off`: "Kapalı. Açarsan arkadaşları etkinliğine gidenler tayfanı
      Keşfet'te görebilir. En az 5 üye gerekir; tayfanın adı, açıklaması
      ve ili incelenir."
    - `pending`: "İnceleniyor" (mango etiket) + "Sonuç bildirilmez; durum
      burada görünür." (sözleşme: yöneticiye onay/ret bildirimi yok)
    - `listed`: "Keşfet'te" (teal etiket) + "Yalnızca 'halka açık yerde
      buluşur' işaretli etkinlikler gösterilir."
    - `under_review`: "Yeniden inceleniyor" (mango etiket) + "Tayfa
      şimdilik Keşfet'te görünmüyor." Neden söylenmez (sözleşme).
    - `rejected`: "Kabul edilmedi" (nötr etiket) + "Yeniden açarsan
      tekrar incelenir."
    "Onaylı" kelimesi kullanılmaz. Açmak onay sorar ("Keşfet'ten gelen
    katılım istekleri her zaman onayını bekler."); kapatmak sormaz. 5
    üyeden azsa `discover-too-few-members` metni. Okunamazsa (403, anlık
    tayfa `tayfa-not-found`) bölüm görünmez.
25. **Etkinlik sihirbazı / düzenleme:** yüz yüze etkinlikte yer adımında
    anahtar "Halka açık yerde buluşur" + "Kafe, park, meydan gibi herkese
    açık bir yerse işaretle. Tayfa Keşfet'teyse etkinlik, arkadaşları
    gidenlere gösterilebilir. Ev adresi gibi özel yerlerde işaretleme."
    Varsayılan kapalı. Çevrim içi etkinlikte görünmez.
26. **Üye listesi:** `joined_via_discover` ise "Keşfet'ten" etiketi
    (nötr ton + pusula ikonu). Alan yalnızca moderatör ve yöneticiye
    döner. Katılım isteklerinde "Keşfetten geldi" zaten vardır.

### Profil

27. **Profil → Gizlilik:** profilleme anahtarlarının altında "Keşfet'te
    arkadaşlarım görebilsin" (varsayılan açık) + "Açıkken gideceğin ya da
    katıldığın etkinlikler arkadaşlarına Keşfet'te gösterilebilir.
    Katılım geçmişin gizliyse gösterilmez." Profillemeden bağımsızdır,
    onaysızdır; hata olursa eski değere döner.

### Erişilebilirlik ve tema

28. Bütün dokunma alanları en az 48 dp; anahtar satırının tamamı tek
    dokunma alanı. Kartta düğme tek; kart kendisi dokunulamaz (iç içe
    dokunma yok). Avatarlar süstür (adı metin taşır). Durum etiketi
    rengin yanında metin ve ikon taşır. Geri bildirim seçimleri ekran
    okuyucuda seçili durumunu okur. Sonuç metinleri canlı bölgedir.
29. 2× yazı ölçeğinde kart satırları sarılır; olgular satırı `Wrap`'tir;
    düğmeler satır altına iner. Açık ve koyu tema token'larla aynı
    iskelet; ayrı renk yok.

## Açık sorular (mimari oturumu cevaplayacak)

1. "Keşfet'te arkadaşlarım görebilsin" Keşfet bayrağı kapalıyken de
   profilde görünüyor (kişi önceden kapatabilsin diye). Bayrakla gizlensin
   mi?
2. Güvenlik kişisi bayrağı sonradan kapatılırsa `GET …/safety-contact`
   `feature-disabled` döner ve kart gizlenir; oysa alarm yine gider ve
   "Döndüm" bayraksız çalışır. Bu durumda "Döndüm"ü göstermek için
   istemci neye bakmalı (sözleşmede bayraksız bir okuma ucu yok)?
3. Güvenlik kişisi seçerken arkadaş listesinin yalnızca ilk sayfası
   (100) gösteriliyor; daha çok arkadaşı olan için arama gerekir mi?
4. Keşfet girişi tayfa değiştirme paneli ve karşılama ekranında; Tayfa
   sekmesinin başka bir yerinde (ör. ana sayfa) de olmalı mı?
5. Etkinlik detayında "halka açık yerde buluşur" işareti üyelere de
   gösterilsin mi (şu an yalnızca düzenlemede)?

## 2026-11-17 değişikliği (platform sahibi; istemci ADR-0030)

Keşfet herkese açık (Tayfam-Api ADR-0035) ve alt çubukta üçüncü sekme
(Tayfa, Sohbet, Keşfet, Profil). Arkadaş şartı yok: "Ayşe ve 2 arkadaşın
bu etkinlikte" satırı ve altındaki çizgi yalnızca görünür arkadaş varsa
gösterilir; arkadaşsız kart etkinlik türüyle başlar. Arkadaşı olmayan da
katılım isteği gönderir. Üst çubukta başlık ve bildirim zili. Panel ve
karşılamadaki giriş satırları Keşfet sekmesine geçer.
