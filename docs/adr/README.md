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
