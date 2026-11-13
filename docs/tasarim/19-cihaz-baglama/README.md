# QR ile cihaz bağlama

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Cihaz-QR.dc.html`](Cihaz-QR.dc.html) | Bu cihazı bağla · QR |
| [`Cihaz-Tara.dc.html`](Cihaz-Tara.dc.html) | Cihaz bağla · tarayıcı |
| [`Cihaz-Basarili.dc.html`](Cihaz-Basarili.dc.html) | Bağlandı |
| [`Cihaz-Hata.dc.html`](Cihaz-Hata.dc.html) | Bağlanamadı (örnek hata) |
| [`Cihaz-Kamera-Izni.dc.html`](Cihaz-Kamera-Izni.dc.html) | Kamera izni |
| [`Cihaz-Tek-Bilgi.dc.html`](Cihaz-Tek-Bilgi.dc.html) | Mesaj geçmişin bu telefonda |
| [`Cihaz-Cikis.dc.html`](Cihaz-Cikis.dc.html) | Tek cihazda çıkış uyarısı |

## Kararlar ve notlar

QR ile cihaz bağlama (ADR-0020; metinler mevcut). Yeni telefon 'Bu cihazı bağla': beyaz kartta QR, altında süre hapı ('Kodun süresi: 4:32'), üç adımlı talimat; süre dolunca QR soluklaşır ve 'Yeni kod al'. Eski telefon 'Cihaz bağla': tam ekran koyu kamera, mango köşeli çerçeve ve tarama çizgisi (hareket azaltmada durağan), talimat, kamera gizlilik notu. Sonuç: başarılı (teal tik, 'Bu cihaz bağlandı' / eski telefonda 'Mesaj geçmişi yeni telefona gönderildi') ve hata (nar uyarı + mevcut hata metni + 'Tekrar tara'). Kamera izni yoksa izin ekranı + 'Ayarları aç'. Tek cihaz bilgisi: birebir sekmesinde ilk kez alttan sayfa, 'Cihaz bağla' / 'Anladım'. Tek cihazken çıkış: uyarı kutulu onay penceresi; 'Önce cihaz bağla' (Cihaz bağla ekranına), Vazgeç, dolu yıkıcı 'Çıkış yap'. Yalnızca sunum katmanı; E2E kodu (lib/core/e2e, hassas alan) değişmez.

Metin eşlemesi: QR ekranındaki üç adımlı talimat, tek satırlık `cihaz_qr_talimat` yerine üç yeni ARB anahtarıyla yazılır. `Cihaz-Hata` örnek olarak `cihaz_hata_anahtar_uyusmuyor` metnini gösterir; diğer `cihaz_hata_*` metinleri aynı ekranda gösterilir. Süre hapı `cihaz_qr_kalan`, işlem sürerken `cihaz_tara_isleniyor` / `cihaz_qr_hazirlaniyor` kullanılır.
