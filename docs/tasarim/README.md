# Tayfam mobil arayüz tasarımları

Bu klasör, platform sahibiyle birlikte hazırlanan ekran tasarımlarının kaynağıdır (2026-11-12/13). Her ekran tek bir HTML dosyasıdır: 390×844 (ya da daha uzun) bir telefon çerçevesinde, satır içi stillerle yazılmıştır. Dosyayı tarayıcıda açarak ya da metin olarak okuyarak ölçüleri, renkleri, metinleri ve durumları alın. `support.js` bağlantısı tasarım aracına aittir; dosyayı açmak için gerekmez.

- Ekranlardaki kişi, tayfa ve içerik adları örnektir; gerçek veri değildir.
- Renk, boşluk ve yarıçap değerlerini kodda `TayfamColors` / `TayfamSpacing` / `TayfamRadii` / `TayfamSizes` token'larıyla karşılayın (ADR-0004); HTML'deki hex değerleri yalnızca referanstır.
- Metinler `app_tr.arb`'deki mevcut anahtarlarla eşleştirilir; HTML'deki metin örnek ise mevcut çeviri geçerlidir.
- Her bölümün README'sindeki "Kararlar" platform sahibinin onayladığı kullanıcı deneyimi kararlarıdır; kod yazarken bağlayıcıdır. ADR ve Notion'la çelişki görürseniz durun ve sorun.
- "Sözleşme bekliyor" yazan ekranlar Tayfam-Api'de karşılığı gelene kadar kodlanmaz.

| Bölüm | Klasör | Ekran sayısı |
| --- | --- | --- |
| Açılış ve giriş | [`01-acilis-ve-giris/`](01-acilis-ve-giris/README.md) | 5 |
| Splash animasyonu ve iOS girişi | [`02-splash-ve-ios/`](02-splash-ve-ios/README.md) | 3 |
| Yükleniyor animasyonu | [`03-yukleniyor/`](03-yukleniyor/README.md) | 1 |
| Kayıt sihirbazı: Tayfam'la tanışma | [`04-kayit-sihirbazi/`](04-kayit-sihirbazi/README.md) | 12 |
| Tayfa ana sayfası | [`05-tayfa-ana-sayfa/`](05-tayfa-ana-sayfa/README.md) | 6 |
| Tayfa menüsü ve ayarları | [`06-tayfa-menu-ve-ayarlar/`](06-tayfa-menu-ve-ayarlar/README.md) | 9 |
| Profil | [`07-profil/`](07-profil/README.md) | 11 |
| Profil · sözleşme bekleyenler | [`08-profil-sozlesme-bekleyen/`](08-profil-sozlesme-bekleyen/README.md) | 3 |
| Sohbet | [`09-sohbet/`](09-sohbet/README.md) | 10 |
| Kanal katılımcıları · sözleşme bekliyor | [`10-kanal-katilimcilari-sozlesme-bekleyen/`](10-kanal-katilimcilari-sozlesme-bekleyen/README.md) | 7 |
| Etkinlik detayı | [`11-etkinlik-detayi/`](11-etkinlik-detayi/README.md) | 9 |
| Etkinlik oluşturma sihirbazı | [`12-etkinlik-sihirbazi/`](12-etkinlik-sihirbazi/README.md) | 11 |
| Tayfa kurma sihirbazı | [`13-tayfa-kurma-sihirbazi/`](13-tayfa-kurma-sihirbazi/README.md) | 7 |
| Bildirimler | [`14-bildirimler/`](14-bildirimler/README.md) | 4 |
| Duyuru, anket, soru-cevap | [`15-duyuru-anket-soru-cevap/`](15-duyuru-anket-soru-cevap/README.md) | 14 |
| Karşılama ve davet linki | [`16-karsilama-ve-davet/`](16-karsilama-ve-davet/README.md) | 7 |
| Şikâyet ve moderasyon | [`17-sikayet-ve-moderasyon/`](17-sikayet-ve-moderasyon/README.md) | 5 |
