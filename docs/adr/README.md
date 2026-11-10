# Mimari Karar Kayıtları (ADR)

Bu klasör, Tayfam istemcisinin mimari kararlarını ve gerekçelerini tutar. Her
karar ayrı bir dosyadır (`NNNN-kisa-baslik.md`) ve numarası değişmez. Kararlar
silinmez; değişen bir kararın yerine yenisi yazılır ve eskisinin durumu
"Yerine geçildi: ADR-XXXX" olur.

Sunucunun kararları Tayfam-Api reposundaki `docs/adr/`'dedir; buradaki bir
ADR onlardan birine dayanıyorsa "İlgili" satırında `Tayfam-Api ADR-XXXX`
olarak anar.

**Durumlar:** Önerildi · Kabul edildi · Yerine geçildi · Reddedildi

| No | Başlık | Durum |
|----|--------|-------|
| [0001](0001-durum-yonetimi-riverpod.md) | Durum yönetimi ve bağımlılık enjeksiyonu: Riverpod | Kabul edildi |
| [0002](0002-modul-yapisi.md) | Modül yapısı, klasör düzeni ve modül kayıtları | Kabul edildi |
| [0003](0003-gezinme-iskeleti.md) | Gezinme iskeleti ve yönlendirme | Kabul edildi |
| [0004](0004-tema-ve-bilesen-dili.md) | Tema, token'lar ve bileşen dili | Kabul edildi |
| [0005](0005-api-istemcisi.md) | API istemcisi, kod üretimi, token yenileme ve hata eşlemesi | Kabul edildi |
| [0006](0006-onbellek-ve-cevrimdisi-kuyruk.md) | Önbellek ve çevrimdışı kuyruk: yalnızca bellekte | Kabul edildi |
| [0007](0007-websocket.md) | WebSocket bağlantısı, abonelikler ve mesaj gönderimi | Kabul edildi |
| [0008](0008-ceviri-ve-yerel-ayar.md) | Çeviri dosyaları, yerel ayar ve Türkçe metin işleme | Kabul edildi |
| [0009](0009-test-ci-ve-ios.md) | Test stratejisi, CI ve iOS derlemesi | Kabul edildi |
| [0010](0010-signal-kutuphanesi.md) | Uçtan uca şifreleme için Signal kütüphanesi | Kabul edildi |
| [0011](0011-yalnizca-mobil.md) | Yalnızca mobil istemci; web yalnızca geliştirme derlemesi | Kabul edildi |

## Şablon

```markdown
# ADR-NNNN: Başlık

- **Durum:** Önerildi
- **Tarih:** YYYY-AA-GG
- **Karar veren:** Murat Tarslan
- **İlgili:** …

## Bağlam
## Karar
## Gerekçe
## Sonuçlar
## Değerlendirilen alternatifler
```

Ürün kararları (kavram modeli, özellikler, veri modeli, tasarım standartları,
marka) Notion'daki "Tayfam — Proje Planı" sayfasındadır.
