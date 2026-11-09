# Dışarıdan alınan skill: UI UX Pro Max

- **Kaynak:** https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- **Commit:** `4f2dbb67e64969a9a30ab00742f2d55d66ddec2b` (2026-11-08)
- **Lisans:** MIT (`LICENSE`, Next Level Builder)
- **Alınan:** yalnızca `.claude/skills/ui-ux-pro-max/` (SKILL.md, data, references,
  scripts). Testler ve diğer alt skill'ler (banner, slides, brand, design-system,
  ui-styling) alınmadı.
- **İnceleme (2026-11-09):** Betikler yalnızca Python standart kütüphanesini
  kullanır; ağ, kabuk veya dosya sistemi dışına erişim yok (`--persist`
  verilmedikçe diske yazmaz). SKILL.md ve referanslarda talimat enjeksiyonu yok.

## Yerel değişiklik

`SKILL.md`'deki betik yolu `${CLAUDE_PLUGIN_ROOT}/…` yerine
`${CLAUDE_PROJECT_DIR:-.}/…` yapıldı; skill eklenti olarak değil proje skill'i
olarak kurulu olduğu için. Başka değişiklik yok.

## Güncelleme

Kaynağın yeni bir commit'i alınacaksa: aynı klasörleri kopyala, yolu yeniden
düzelt, betikleri ağ/kabuk çağrısı için tara, bu dosyadaki commit'i güncelle.
Skill dosyaları ajanlara talimattır; bu klasör hassas alandır (CODEOWNERS).
