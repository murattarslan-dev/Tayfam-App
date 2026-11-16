# Sohbette fotoğraf ve yer

> Sözleşme: Tayfam-Api PR #214 (issue #205, ADR-0031), main'de. İstemci
> işi: Tayfam-App #194, istemci ADR-0026. Ürün kararları: Notion "Faz 2
> (v2) — Medya ve Sosyal" §1, §7a ve §9 (2026-11-15/16).

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Kanal-Ek-Menu.dc.html`](Kanal-Ek-Menu.dc.html) | Yazma çubuğundaki ⊕ → "Ekle" alttan sayfası |
| [`Fotograf-Onay.dc.html`](Fotograf-Onay.dc.html) | Seçilen fotoğrafı gönderme onayı (tam ekran, koyu) |
| [`Kanal-Fotograf.dc.html`](Kanal-Fotograf.dc.html) | Kanal · gelen fotoğraf, gelen yer, giden ve gönderilen fotoğraf |
| [`Kanal-Fotograf-Koyu.dc.html`](Kanal-Fotograf-Koyu.dc.html) | Aynısı koyu temada; gönderilemeyen fotoğraf |
| [`Yer-Secici-Konum.dc.html`](Yer-Secici-Konum.dc.html) | Yer seçici · "Bulunduğum yer" düğmesi |
| [`Yer-Secici-Izin-Yok.dc.html`](Yer-Secici-Izin-Yok.dc.html) | Yer seçici · konum izni verilmedi |
| [`Yer-Onay.dc.html`](Yer-Onay.dc.html) | "Yeri gönder" onay sayfası (harita önizlemesi + isteğe bağlı ad) |
| [`Birebir-Fotograf.dc.html`](Birebir-Fotograf.dc.html) | Birebir · şifreli fotoğraf: açılıyor, açılamadı, doğrulanamadı |
| [`Fotograf-Goruntuleyici.dc.html`](Fotograf-Goruntuleyici.dc.html) | Fotoğraf · tam ekran (yakınlaştırma) |
| [`Kanal-Mesaj-Sikayet.dc.html`](Kanal-Mesaj-Sikayet.dc.html) | Kanal · başkasının mesajına uzun basınca "Şikâyet et" |
| [`Sikayet-Fotograf.dc.html`](Sikayet-Fotograf.dc.html) | Şikâyet et · birebir fotoğraf (kanıt cihazdan) |

## Mevcut tasarımla ilişki

Yeni ekran iskeleti yoktur; her şey mevcut parçalardan kurulur:

- **Akış ve balon:** 09-sohbet'in `Kanal-Akis` / `Birebir-Konusma`
  akışı ve `SohbetBalonu`. Fotoğraf ve yer balonun içinde durur: iç
  boşluk 4 px, görselin köşeleri önizleme karosu (14 px), balonun
  köşeleri ve kuyruğu aynı. Gelen kanal mesajında ad balonun başında
  kalır. Gruplama, gün ayırıcı, saat ve "Görüldü" değişmez.
- **Yazma çubuğu:** `MesajYazmaCubugu`'nun soluna 48 dp ⊕ ("Fotoğraf ya
  da yer ekle"). Alan, gönder düğmesi ve yavaş mod geri sayımı aynı.
  Geri sayım sürerken ve arşivde ⊕ yoktur ya da pasiftir.
- **Alttan sayfalar:** `altSayfaAc` + `AltSayfaIcerigi` + `MenuSatiri`
  (09 `Kanal-Islem` ile aynı).
- **Bekleyen / gönderilemeyen:** 09 karar 7 ve 23 `Durum-Baglaniyor`:
  bekleyen fotoğraf soluk + "Gönderiliyor", gönderilemeyen nar kenarlı
  balon + "Tekrar dene" / "Sil" (aynı `client_request_id`).
- **Yer seçici:** 12 `Sihirbaz-Harita`'daki OSM seçicisinin aynısı;
  yalnızca "Bulunduğum yer" hap düğmesi ve seçim düğmesinin metni farklı.
- **Tam ekran fotoğraf ve gönderme onayı:** 19 `Cihaz-Tara`'daki gibi
  tema ne olursa olsun koyu temanın token'ları (ink zemin, beyaz metin).
- **Şikâyet:** 17 `Sikayet-Mesaj`'ın aynısı; önizlemede metin yerine
  fotoğraf.

Yeni bileşenler ve gerekçeleri:

| Bileşen | Neden mevcutlar yetmiyor |
| --- | --- |
| `SohbetFotografi` | Balon içinde oranı korunan görsel + yükleniyor/hata yüzeyi; `MedyaGorseli` sabit kutuya çizer, oran ve dokunma (tam ekran) yok. |
| `SohbetYerKarti` | Etkileşimsiz küçük OSM haritası + iğne + ad; `OsmHarita` tam ekran içindir. |
| `FotografGoruntuleyici` | Tam ekran yakınlaştırma; uygulamada yok (albüm PR'ındaki görüntüleyici henüz birleşmedi, birleşince ortaklaştırılır). |
| `EkMenusu` (⊕) | `MesajYazmaCubugu`'na isteğe bağlı sol düğme; yeni çubuk değil. |

## Akışlar

1. **Fotoğraf (kanal ve birebir):** ⊕ → "Galeriden fotoğraf" ya da
   "Kamerayla çek" → seçici (izin istemez; ADR-0021 §1) → cihazda
   hazırlama (EXIF/GPS silinir, yeniden kodlanır) → `Fotograf-Onay`:
   tam ekran önizleme, gizlilik notu ve "Gönder"; ✕ vazgeçer → mesaj
   kuyruğa girer, akışta soluk "Gönderiliyor" balonu (yerel önizleme).
   **Alt yazı yoktur;** metin ayrı mesajdır (platform sahibi, 2026-11-16).
   - Kanalda gizlilik notu: "Konum ve cihaz bilgileri fotoğraftan
     silindi. Fotoğrafı yalnızca bu kanalı görenler görür."
   - Birebirde: "… Fotoğraf uçtan uca şifrelenir; yalnızca sen ve
     konuştuğun kişi görebilir."
2. **Yer:** ⊕ → "Yer paylaş" → yer seçici (`Yer-Secici-Konum`):
   haritaya dokun ya da ara (12 ile aynı). "Bulunduğum yer" haritayı
   cihazın konumuna taşır ve iğneyi oraya bırakır; **konum izni yalnızca
   bu düğmeye basınca istenir** (açılışta ya da ⊕'da değil). "Bu yeri
   seç" → `Yer-Onay` alttan sayfası: etkileşimsiz harita önizlemesi,
   isteğe bağlı ad (arama sonucundan seçildiyse o ad dolu gelir; 1–120),
   "Haritada gördüğün nokta gönderilir; canlı konumun paylaşılmaz." ve
   "Gönder" / "Vazgeç". **Kullanıcı noktayı görüp "Gönder"e basmadan
   hiçbir şey gitmez.** Canlı konum yoktur.
3. **Gösterme:** fotoğraf balonu dokununca tam ekran
   (`Fotograf-Goruntuleyici`; iki parmakla yakınlaştırma, ✕ ve geri
   kapatır; kaydet/paylaş yok: içerik diske yazılmaz, ADR-0006). Yer
   kartı dokununca tam ekran harita (iğne + ad, OSM atfı, geri).
4. **Birebir şifreli fotoğraf:** alıcıda balon önce kilit ikonlu
   "Fotoğraf açılıyor…" yüzeyi; indirme → özet doğrulama → çözme →
   yalnızca bellekte gösterim. Ağ hatasında "Fotoğraf açılamadı." +
   "Tekrar dene"; özet ya da şifre doğrulanamazsa nar yüzeyde
   "Fotoğraf doğrulanamadı; gösterilmiyor." (tekrar dene yok: içerik
   bozuk ya da değiştirilmiş). Çözülemeyen zarfın mevcut "Bir mesaj
   çözülemedi" satırı aynen kalır.
5. **Şikâyet:**
   - Kanal: başkasının (silinmemiş) metin, fotoğraf ya da yer mesajına
     uzun basınca "Şikâyet et" → 17'deki şikâyet sayfası (önizlemede
     "Kanal mesajı"). **Yönetici ve moderatör başkasının mesajını şikâyet
     etmez; aynı menüde "Mesajı sil" (gizle) görür** (Notion 2026-11-14:
     tüm modüllerde tek kural). Kendi mesajın şikâyet edilmez.
   - Birebir fotoğraf: şikâyet sayfasının önizlemesinde fotoğraf ve
     "Şikâyetle birlikte iletilecek fotoğraf"; gönderince fotoğraf
     şikâyet edenin cihazından kanıt olarak yüklenir (yalnızca Tayfam
     ekibi görür). Birebir yer: iletilecek metin yerin adı ve
     koordinatıdır (ekranda gösterilir).
   - Moderasyon kuyruğu: "Kanal mesajı" etiketi; "İçeriği aç" kanalı
     açar, "İçeriği kaldır" mesajı gizler (30 gün geri alınabilir),
     sonuçlananda "Geri al".

## Durumlar

| Durum | Görünüm |
| --- | --- |
| Boş | Değişmez (`sohbet_kanal_bos`). |
| Yükleniyor | Fotoğraf: oranı korunan tint-brand yüzey + Dalga (1 sn'den kısa beklemede yok). Şifreli: kilit + "Fotoğraf açılıyor…". Harita: çizgi rengi zemin, karolar gelince dolar. |
| Hazırlanıyor / yükleniyor (giden) | Soluk balonda yerel önizleme + "Gönderiliyor". |
| Hata | Gönderilemedi: nar kenarlı balon + hata metni + "Tekrar dene" / "Sil". Görüntülenemeyen kanal fotoğrafı: `GorselYuzeyi` "görsel yok" ikonu. Şifreli: yukarıdaki iki durum. |
| İzin reddi (konum) | Seçicide kutu: "Konum izni verilmedi. Haritaya dokunarak ya da arayarak yer seçebilirsin."; kalıcı retteyse "Ayarları aç". Konum servisi kapalıysa "Konum kapalı." + "Konum ayarları". Konum okunamazsa "Konumun alınamadı." Seçici her durumda elle kullanılabilir. |
| Silinmiş | "Bu mesaj silindi" (fotoğraf ve yer de kalkar). |

## Erişilebilirlik ve tema

- Fotoğraf balonu ekran okuyucuda "Deniz Aksoy yazdı: Fotoğraf" ve
  "Açmak için iki kez dokun"; yer kartı "… Paylaşılan yer: <ad>".
  Görselin kendisi tek öğe; süs ikonları gizli.
- ⊕, ✕, "Bulunduğum yer" ve tam ekrandaki düğmeler 48 dp, etiketli.
- Açık ve koyu temada token'lar (`TayfamColors` / `Spacing` / `Radii` /
  `Sizes`); tam ekran fotoğraf ve onay koyu temanın token'larıyla.
- 2× yazıda: balon genişliği değişmez, yer adı sarılır; alttan sayfa
  kayar; seçicinin düğmesi her zaman görünür (12 ile aynı).
- Hareket: yalnızca Material'ın kendi geçişleri; "hareketi azalt"ta
  yükleniyor statik.

## Kararlar ve notlar

Platform sahibi kararları (2026-11-15/16, Notion "Faz 2" §1, §7a, §9;
issue #194): kanal ve birebirde fotoğraf; alt yazı yok (metin ayrı
mesaj); birebir fotoğraf uçtan uca şifreli (istemci temizlenmiş görüntüyü
CSPRNG anahtarıyla AES-256-GCM ile şifreler, opak blob ≤ 10 MiB yükler,
anahtar ve özet Signal zarfının içinde; alıcı özeti doğrular, çözer,
yalnızca bellekte gösterir); yer mevcut OSM seçicisiyle, "Bulunduğum yer"
düğmesi haritayı cihaz konumuna taşır, izin yalnızca bu düğmeye basınca
istenir, kullanıcı noktayı görüp onaylamadan gönderilmez, canlı konum
yok, koordinat log'a girmez; kanal mesajı şikâyet edilebilir, yönetici
ve moderatör başkasının içeriğini şikâyet etmez, gizler; birebir
şikâyetinde kanıt fotoğrafı şikâyet edenin cihazından.

Bu bölümün kararlar dışında seçtiği ayrıntılar (PR'da onaya sunuldu):

1. Fotoğraf için de gönderme onayı (`Fotograf-Onay`): yanlış fotoğrafın
   geri alınamaz biçimde gitmesini önler; kişisel fotoğraf (birebir)
   için önemli.
2. Yer adı onay sayfasında, isteğe bağlı; arama sonucunun adı öneri.
3. "Bulunduğum yer" yaklaşık konumla da çalışır (yalnızca haritayı
   taşır; kullanıcı noktayı görüp düzeltir). Varış bildirimindeki
   "hassas konum" şartı burada yok.
4. Tam ekran fotoğrafta kaydet/paylaş yok (ADR-0006).
5. Birebir zarfta önizleme (küçük resim) yok; alıcı tam görüntüyü
   indirene kadar kilitli yüzey görür (zarf ve arşiv kaydı küçük kalır).

`ui-ux-pro-max` danışması (`--stack flutter`, `--domain ux`, `--domain
icons`): async yükleniyor/hata durumları, anlamlı görsele metin
alternatifi, Semantics, 48 dp dokunma alanı, geri alınamaz işlemde onay,
tutarlı ikon ailesi (Material Icons; ⊕ `add_circle_outline`, harita
`place`, konum `my_location`). Skill'in "cached_network_image" önerisi
uygulanmadı (ADR-0006: diske önbellek yok; mevcut bellek önbelleği
kullanılır). Palet ve font önerisi kullanılmadı.
