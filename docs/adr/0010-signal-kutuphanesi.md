# ADR-0010: Uçtan uca şifreleme için Signal kütüphanesi

- **Durum:** Önerildi (anahtar saklama kararlaştırıldı; AGPL kabulü bekleniyor)
- **Tarih:** 2026-11-09, güncelleme 2026-11-10
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0011](0011-yalnizca-mobil.md); Tayfam-Api ADR-0005 (E2E tasarımı), ADR-0011; CLAUDE.md kesin kural 4; Notion: Proje Planı §6, Açık Kararlar ("Signal için Dart/Flutter kütüphanesi seçimi")

## Bağlam

Birebir mesajlar Signal protokolüyle uçtan uca şifrelenecek (Notion §6,
Tayfam-Api ADR-0005): cihaz başına anahtar çifti, alıcının ve gönderenin
tüm cihazlarına ayrı zarflar, kullanıcının geçmiş anahtarıyla şifreli
arşiv, QR ile geçmiş anahtarı aktarımı, "güvenlik kodu değişti" uyarısı.
Kendi kriptografimizi yazmayız (kesin kural 4). Uygulama yalnızca mobildir
(ADR-0011). Uygulama sırası: önce düz birebir mesaj, E2E modülün son adımı.

## Araştırma (2026-11-09)

| Seçenek | Ne | Platformlar | Lisans | Olgunluk |
| --- | --- | --- | --- | --- |
| **`libsignal`** (pub.dev) | Signal'in resmi Rust çekirdeğine Flutter Rust Bridge bağlaması; Signal'den değil, üçüncü kişi | Android, iOS (ayrıca masaüstü, web) | AGPL-3.0 (bağlamada uygulama mağazası istisnası var, gömülü libsignal'de yok) | Birkaç aylık, tek geliştirici, sık büyük sürüm; çekirdek Signal'in kendi kodu |
| **`libsignal_protocol_dart`** (Mixin) | Java sürümünün saf Dart'a çevirisi | Dart'ın çalıştığı her yer | GPL-3.0 | ~4 yıllık; son güncelleme Haziran 2025; bağımsız denetim yok; kripto Dart'ta yeniden yazılmış |
| **Kendi bağlamamız** | Signal'in resmi Rust `libsignal`'ine kendi Flutter Rust Bridge bağlamamız | Android, iOS | AGPL-3.0 | Çekirdek resmi; bağlamanın bakımı bizde |
| **vodozemac** (Matrix Olm) | Signal değil, Double Ratchet'in Matrix sürümü | Android, iOS | Bağlama AGPL-3.0 | Denetlenmiş çekirdek; ama protokol kararından sapma |

Uygun her seçenek GPL ya da AGPL'dir. Repo MIT kalabilir, ama dağıtılan
uygulama (APK/IPA) bu lisansa tabi olur; kaynak zaten açık olduğu için uyum
mümkün. Google Play'de bilinen engel yok; App Store ile GPL/AGPL'nin uyumu
tartışmalı.

## Karar

1. **Signal'in resmi Rust çekirdeği kullanılır** (öneri; AGPL kabulüne
   bağlı). Başlangıçta `libsignal` bağlaması sürümü sabitlenerek kullanılır;
   bağlama kodu (Rust ve Dart tarafı) eklenmeden önce satır satır incelenir,
   sürüm yükseltmeleri de aynı incelemeden geçer (hassas alan). Bağlamanın
   bakımı bırakılırsa ya da inceleme güven vermezse aynı arayüzle kendi
   bağlamamıza geçilir. Saf Dart çeviri (Mixin), kriptoyu yeniden yazdığı ve
   denetlenmediği için önerilmez.
2. **Anahtarlar ve Signal durumu token gibi güvenli depoda tutulur**
   (platform sahibi, 2026-11-10):
   - `flutter_secure_storage` ile (Android'de Keystore anahtarıyla
     AES-GCM şifreli kayıtlar, iOS'ta Keychain,
     `first_unlock_this_device`, yedeğe gitmez). Yeni bağımlılık değildir
     (ADR-0005). Kendi dosya şifrelememiz yoktur.
   - Kayıt kayıt saklanır: kimlik anahtarı ve kayıt kimliği, imzalı ön
     anahtar, ön anahtarlar, her karşı cihazla oturum durumu, kullanıcının
     geçmiş anahtarı.
   - Oturum durumu her mesajda güncellenir; durum güvenli depoya yazılmadan
     mesaj gönderilmiş veya alınmış sayılmaz.
   - Mesaj içeriği diske yazılmaz (ADR-0006 aynen geçerli); geçmiş arşivi
     sunucudan indirilip bellekte çözülür.
   - Oturum kapanınca ve hesap silinince bu kayıtların hepsi silinir.
   - Web geliştirme derlemesinde E2E yüklenmez (ADR-0011).

## Açık soru (platform sahibi)

- Uygulamada AGPL-3.0 bağımlılık kabul ediliyor mu? Kabul edilmezse Signal
  ile E2E'nin lisans açısından temiz bir yolu yoktur; protokol kararı
  yeniden açılır.

## Sonuçlar (kabul edilirse)

- Bağımlılık: `libsignal` (sabit sürüm, hassas alan). `flutter_secure_storage`
  zaten var.
- ADR-0006'daki "token dışında diske bir şey yazılmaz" kuralı "token ve
  Signal anahtarları/durumu yalnızca güvenli depoda" olarak genişler.
- Notion'da "Signal için Dart/Flutter kütüphanesi seçimi" açık kararı
  kapanır; hukukçu listesine App Store ve AGPL maddesi eklenir; README ve
  uygulamanın lisans ekranında E2E modülünün AGPL olduğu belirtilir.
- E2E iş paketinden önce: bağlamanın incelenmesi, cihaz ekleme/çıkarma ve
  QR akışının istemci tasarımı.

## Değerlendirilen alternatifler

Yukarıdaki tablo. Ayrıca anahtar saklama için kendi şifreli dosyamız
(AES-GCM, anahtar Keystore'da) düşünüldü; aynı güvenlik düzeyini kendi
şifreleme kodumuzla verdiği için `flutter_secure_storage` tercih edildi.
