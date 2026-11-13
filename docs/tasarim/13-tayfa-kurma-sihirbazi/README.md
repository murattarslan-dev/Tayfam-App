# Tayfa kurma sihirbazı

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Tayfa-Kur-Ad.dc.html`](Tayfa-Kur-Ad.dc.html) | 1 · Ad |
| [`Tayfa-Kur-Ilgi.dc.html`](Tayfa-Kur-Ilgi.dc.html) | 2 · İlgi alanları |
| [`Tayfa-Kur-Katilim.dc.html`](Tayfa-Kur-Katilim.dc.html) | 3 · Katılım ve açıklama |
| [`Tayfa-Kur-Hazir.dc.html`](Tayfa-Kur-Hazir.dc.html) | Tayfa kuruldu |
| [`Tayfa-Kur-Limit.dc.html`](Tayfa-Kur-Limit.dc.html) | 3 · günlük sınır hatası |
| [`Tayfa-Kur-Vazgec.dc.html`](Tayfa-Kur-Vazgec.dc.html) | Kapat · vazgeç onayı |
| [`Tayfa-Kur-Koyu.dc.html`](Tayfa-Kur-Koyu.dc.html) | 2 · İlgi alanları · koyu |

## Kararlar ve notlar

Kullanıcı deneyimi kararları: (1) Etkinlik sihirbazıyla aynı iskelet: X, 'Tayfa kur', 'Adım n / 3', 3 parçalı ilerleme, sabit Geri + İleri; X girilen bir şey varsa vazgeç onayı sorar. (2) Ad adımında örnek ad çipleri (dokununca alana yazılır) ve altta tayfanın listede nasıl görüneceğinin önizlemesi (avatar harfi + ad). (3) İlgi alanları 2 sütunlu onay kutulu kartlar, türün renginde ikon; önizleme avatarın rengi ilk seçilen türden (TayfaAvatari kuralı). Adım geçilebilir. (4) Katılım: Onaylı (Önerilen etiketi, varsayılan) / Açık radyo kartları, açıklama sayaçlı; altta 7 günde 3 üye ve 24 saatte bir tayfa bilgisi. (5) Günlük sınır (tayfa-create-limit / rate-limited) son adımda tint-nar kutuda, girilenler kalır. (6) YENİ: başarıdan sonra mor 'Tayfa kuruldu' ekranı: logo, tayfa avatarı, başlık, 7 günde 3 üye hedefi, tayfa kodu + Kopyala, birincil 'Davet linkini paylaş' (mevcut davet linki oluşturma; varsayılan 7 gün / 10 kişi, link bir kez gösterilir), ikincil 'Tayfaya git' (ana sayfa, kurulum adımlarıyla). Geri tuşu ana sayfaya gider.
