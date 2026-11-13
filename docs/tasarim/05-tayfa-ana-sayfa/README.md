# Tayfa ana sayfası

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Ana-Ilk-Ekran.dc.html`](Ana-Ilk-Ekran.dc.html) | Ana sayfa · ilk ekran |
| [`Ana-Tam-Sayfa.dc.html`](Ana-Tam-Sayfa.dc.html) | Ana sayfa · kaydırınca tamamı |
| [`Ana-Koyu.dc.html`](Ana-Koyu.dc.html) | Ana sayfa · koyu tema |
| [`Ana-Yonetici.dc.html`](Ana-Yonetici.dc.html) | Ana sayfa · yönetici, Oluştur açık |
| [`Ana-Yeni-Tayfa.dc.html`](Ana-Yeni-Tayfa.dc.html) | Ana sayfa · yeni kurulan tayfa |
| [`Ana-Tayfa-Degistir.dc.html`](Ana-Tayfa-Degistir.dc.html) | Tayfa değiştirme paneli |

## Kararlar ve notlar

Kullanıcı deneyimi kararları: (1) En sık iş 'gidiyor muyum?': sıradaki etkinlik büyük kartta, katılım cevabı ana sayfadan tek dokunuşla verilir; kart dolunca düğme 'Sıraya gir' olur. (2) Bölümler kısa: Yaklaşan 2 satır (sıradaki kartta), Duyurular sabitlenen + son 2, Açık anket 1, Son sorular 2; her bölümde 'Tümü'. Modülü kapalı bölüm görünmez. (3) Oluşturma tek yerde: 'Oluştur' düğmesi alttan bir sayfa açar; içindeki seçenekleri sunucunun izinleri belirler (üyeye yalnızca izin verilenler görünür). (4) Yönetici işi görünür: bekleyen katılma isteği varsa üstte tek satırlık bir uyarı. (5) Yeni tayfa boş görünmez: 'Tayfanı birlikte kuralım' adımları ve 7 günde 3 üye kuralı açıkça yazılır. (6) Duyurularda yazar adı yok (sözleşmede yalnızca kimlik var).

Veri kaynağı: tayfa adı, üye sayısı, kod, bekleyen istek sayısı, durum (Tayfa); etkinlikte tür, başlık, başlangıç, yer adı/ilçe ya da çevrimiçi, kontenjan, gelen sayısı, senin cevabın, iptal (Event); duyuruda başlık, gövde, sabitlenme, tarih (Announcement). Geri sayım ('3 gün sonra') ve göreli zaman istemcide hesaplanır, tr_TR. Tayfa avatarı kapak görseli varsa onu, yoksa adın ilk harfini gösterir (tek harf, ADR-0008).
