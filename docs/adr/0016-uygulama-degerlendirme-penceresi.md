# ADR-0016: İlk etkinlikten sonra uygulama değerlendirme penceresi

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0015](0015-etkinlik-ve-duyuru-modulleri.md); issue #43; Notion: Mağaza Sayfası

## Bağlam

Platform sahibi, kullanıcının ilk etkinliğinden sonra mağaza değerlendirmesi
istenmesini istiyor. Play ve App Store kendi uygulama içi değerlendirme
pencerelerini sunar:

- Pencerenin gösterilip gösterilmeyeceğine mağaza karar verir, kota
  uygular ve sonucu bildirmez.
- "Bizi beğendiniz mi?" gibi, memnun kullanıcıyı ayıklayan bir ön soru
  iki mağazanın kurallarına aykırıdır.

## Karar

1. **Tetikleyici** (platform sahibi, 2026-11-11): kullanıcının cevabı
   "Geliyorum" olan bir etkinliğin bitmiş olması. Katılımın doğrulanması
   (varış bildirimi) şart **değildir**. Organizatörler de aynı kurala
   tabidir.
2. **Bir kez:** pencere cihazda en çok **bir kez** istenir. Mağaza
   göstermese ya da kullanıcı kapatsa da ikinci deneme yoktur (platform
   sahibi, 2026-11-11).
   - "Değerlendirme istendi" bayrağı kullanıcı ayarı olarak güvenli depoda
     tutulur (ADR-0006).
   - Bayrak cihaza aittir; oturum kapanınca silinmez.
3. **An:**
   - Koşul, bitmiş etkinliğin detayı ya da tayfa ana sayfası
     açıldığında denetlenir.
   - İstek, kullanıcı bir işin ortasında değilken yapılır: sayfa
     açıldıktan kısa bir süre sonra, form ya da sihirbaz açık değilken.
   - Kendi ön sorumuz yoktur; doğrudan mağaza API'si çağrılır ve sonucu
     beklenmez.
4. **Paket:** `in_app_review`. Android'de Play In-App Review, iOS'ta
   `SKStoreReviewController` kullanır; izin gerektirmez. Servis bir
   arayüzün arkasındadır.
5. **Gizlilik:** sunucuya hiçbir şey gönderilmez; analitik yoktur.

## Sonuçlar

- Pencere yalnızca mağazadan kurulan sürümde görünür. CI'dan çıkan
  debug APK'da görünmez; deneme Play'in dahili test kanalında yapılır.
- Yeni paket: `in_app_review` (kesin kural 8).

## Değerlendirilen alternatifler

- **Doğrulanmış katılım şartı:** varış bildirimini kullanmayan
  kullanıcılar hiç değerlendirme penceresi görmezdi.
- **İkinci deneme:** platform sahibi gerek görmedi.
- **Kendi ön sorumuz:** mağaza kurallarına aykırı.
