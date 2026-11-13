# Duyuru, anket, soru-cevap

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Duyurular.dc.html`](Duyurular.dc.html) | Duyurular · liste |
| [`Duyuru-Detay.dc.html`](Duyuru-Detay.dc.html) | Duyuru · detay |
| [`Duyuru-Menu.dc.html`](Duyuru-Menu.dc.html) | Duyuru · ⋯ (yönetim) |
| [`Duyuru-Form.dc.html`](Duyuru-Form.dc.html) | Duyuru yaz |
| [`Anketler.dc.html`](Anketler.dc.html) | Anketler · liste |
| [`Anket-Oy.dc.html`](Anket-Oy.dc.html) | Anket · oy verme (çoklu) |
| [`Anket-Sonuc.dc.html`](Anket-Sonuc.dc.html) | Anket · sonuçlar |
| [`Anket-Oy-Verenler.dc.html`](Anket-Oy-Verenler.dc.html) | Anket · oy verenler (açık anket) |
| [`Anket-Gizli.dc.html`](Anket-Gizli.dc.html) | Gizli anket · 5 oyun altı |
| [`Anket-Form.dc.html`](Anket-Form.dc.html) | Anket aç |
| [`Sorular.dc.html`](Sorular.dc.html) | Sorular · liste ve arama |
| [`Soru-Detay.dc.html`](Soru-Detay.dc.html) | Soru · detay ve cevaplar |
| [`Soru-Form.dc.html`](Soru-Form.dc.html) | Soru sor |
| [`Cevap-Form.dc.html`](Cevap-Form.dc.html) | Cevap yaz |

## Kararlar ve notlar

Duyuru (2026-11-13): liste sabitlenenler üstte (mango kenar + 'Sabitlendi' çipi), sonra 'Son duyurular' kartları: tarih, başlık, metnin ilk 2 satırı. Yönetimde başlıkta 'Duyuru yaz'. Detay: sabit çipi, büyük başlık, yazar (avatar + ad, profil önbelleğinden — platform sahibi kararı) + tarih ('düzenlendi' updated_at > created_at ise), düz metin gövde (bağlantı dokunulabilir değil, ADR-0015 §2). ⋯: yönetimde Düzenle, Sabitle / Sabitlemeyi kaldır, Sil (yıkıcı, onaylı); üyede Şikâyet et. Form tam ekran: X, başlık, sağ üstte 'Yayınla'/'Kaydet'; başlık ve metin sayaçlı; yönetimde 'Yayınlayınca sabitle' anahtarı (oluşturma + sabitleme iki çağrı).

Anket (2026-11-13): liste 'Açık' / 'Kapanan' bölümleri; kartta soru, durum çipi, oy sayısı, kapanış ya da 'Gizli anket', oy verdiysen 'Oy verdin'. Oy: her zaman 'Oyu gönder' düğmesi (platform sahibi kararı); tek seçimde radyo, çoklu seçimde onay kutusu, düğmede seçilen sayısı; 'Sonuçları gör' oy vermeden sonuçlara geçer (mevcut). Sonuç: çubuklar, yüzde ve oy sayısı, senin seçeneğin marka çubuk + 'Senin oyun', en çok oy alan kalın; 'Oyunu değiştir' / 'Oyunu geri çek'. Açık ankette seçeneğe dokununca oy verenler alttan sayfa. Gizli ankette kimin oy verdiği hiçbir yerde yok; toplam 5'ten azsa yüzde ve sayı yok, yalnızca toplam + 'Sonuçlar 5 oydan sonra görünür' (kesin kural 7). Form: soru, 2–10 seçenek (ekle/kaldır), çoklu ve gizli anahtarları (gizli ilk oydan sonra değişmez), kapanış seçici; etkinlikten açılırsa bağlı etkinlik notu.

Soru-cevap (2026-11-13): liste üstte arama (sunucuda, Türkçe duyarsız), etiket çipleriyle süzme, satırda soru, etiketler, cevap sayısı ve zaman. Detay: etiketler, başlık, soran + tarih, ayrıntı; 'N cevap' ve 'En faydalı bulunanlar üstte'; ilk cevap en az 1 oy almışsa teal 'En faydalı' etiketi (platform sahibi kararı; yeni alan yok, sıralama sunucudan). Cevapta 'Faydalı · N' düğmesi (verdiysen tint); kendi cevabında düğme pasif (sunucu reddeder). Altta sabit 'Cevap yaz'. Soru ⋯: yazar ve yönetimde Düzenle, Sil (mevcut iki ayrı onay metni); diğerlerinde Şikâyet et. Form: sorun (10–150), ayrıntı, etiketler (en çok 5; yazıp ekle, tayfadaki etiket önerileri). Cevap formu: üstte soru alıntısı, sayaçlı metin.
