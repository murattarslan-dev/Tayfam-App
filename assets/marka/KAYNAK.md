# Marka varlıkları

## Tayfam logosu "Dörtlü" (`logo/`)

- Kaynak: platform sahibinin onayladığı logo dosyaları (Notion: Marka →
  Logo, Tasarım Standartları → Logo kullanımı; 2026-11-12). Dosyalar
  değiştirilmeden kopyalandı.
  - `tayfam-logo.svg` (açık zemin, L brand #5B2BE0),
    `tayfam-logo-dark.svg` (koyu zemin, L #A98BFF), `tayfam-rozet.svg`,
    `tayfam-tek-renk.svg` (`currentColor`), `tayfam-app-icon.svg` (mor
    zemin, L #FAF8FF, işaret %60), `tayfam-android-foreground.svg` (108
    birimlik uyarlanabilir ikon ön katmanı), `tayfam-feature-graphic.svg`.
  - `png/`: Play ikonu 512 px, Google OAuth onay ekranı logosu 120 px, logo
    ve rozet 1024 px, Play öne çıkan görseli 1024×500.
- Bu dosyalar uygulamaya **paketlenmez** (`pubspec.yaml`'da yok). Uygulama
  logoyu aynı yollarla `CustomPainter` ile çizer
  (`lib/core/bilesenler/tayfam_logo.dart`); SVG paketi yoktur. Yolların
  dosyalarla aynı olduğunu `test/core/bilesenler/tayfam_logo_test.dart`
  denetler.
- Android ve iOS uygulama ikonları bu yollardan `tool/ikon/ikon_uret.py`
  ile üretilir. Mağaza ve OAuth görselleri (`png/`) platform sahibinin
  konsollara yükleyeceği dosyalardır.
- Eski "t" monogramı ("Hareket") bırakıldı; tanıtım sitesindeki (`site/`)
  monogram ve çizim animasyonu ayrı bir işte değişecek.

## Google "G" işareti (`google_g.png`, `2.0x/`, `3.0x/`)

- Kaynak: Google'ın resmi `google/GoogleSignIn-iOS` deposu,
  `GoogleSignIn/Sources/Resources/google.png`, `google@2x.png`,
  `google@3x.png` (commit `1ed9addeb9e3adfaac7a62e2f51bb7cf1971fa2c`).
  Dosyalar değiştirilmeden kopyalandı (18, 36, 54 px).
- Kullanım: yalnızca "Google ile devam et" düğmesinde, Google'ın oturum
  açma marka kurallarına göre (Sign in with Google branding guidelines).
  İşaret yeniden renklendirilmez, oranı değiştirilmez. Google logosu
  Google LLC'nin ticari markasıdır; deponun Apache-2.0 lisansı markayı
  kapsamaz, kullanım marka kurallarına dayanır.
- developers.google.com'daki marka kiti bu ortamdan indirilemedi; platform
  sahibi kitteki Android varlığıyla değiştirmek isterse aynı yollara
  koyması yeterlidir (ADR-0012 §2).
