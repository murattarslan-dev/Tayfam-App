# ADR-0009: Test stratejisi, CI ve iOS derlemesi

- **Durum:** Kabul edildi (platform sahibi, 2026-11-10: "GitHub Actions ile devam et")
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0002](0002-modul-yapisi.md), [ADR-0004](0004-tema-ve-bilesen-dili.md), [ADR-0005](0005-api-istemcisi.md), [ADR-0008](0008-ceviri-ve-yerel-ayar.md); Tayfam-Api ADR-0010, ADR-0011

## Bağlam

Kodu birbirinden habersiz alt oturumlar yazacak; inceleme ve birleştirme
CI'ın yeşil olmasına dayanır (CLAUDE.md, İş akışı). Önceki ADR'ler birkaç
kuralın CI'da denetleneceğini söyledi: import sınırları (ADR-0002), sabit
renk/sayı (ADR-0004), üretilen API kodunun güncelliği (ADR-0005), sabit
kullanıcı metni (ADR-0008). İlk hedef platform Android; Mac ve Apple
Developer hesabı yok.

## Karar

### Test katmanları

| Katman | Kapsam | Zorunluluk |
| --- | --- | --- |
| Birim | `ApiClient`, `SessionStore` (eşzamanlı yenileme, `refresh-conflict`, `invalid-refresh`), çevrimdışı kuyruk, WebSocket kapanma kodu tablosu, derin link ayrıştırma, `turkceKucukHarf`, renk kontrastı, OpenAPI üreticisi | Her PR |
| Widget | Her ekran en az bir test; açık ve koyu temada; yazı ölçeği 2× iken taşma yok; her etkileşimli öğenin erişilebilirlik etiketi var | Her ekran PR'ı |
| Altın görüntü (golden) | Yalnızca `core/bilesenler/` altındaki ortak bileşenler, açık ve koyu | Bileşen değişince |
| Uçtan uca | MVP'de otomatik yok; pilot öncesi dev ortamına karşı elle kontrol listesi | Pilot öncesi |

- Testler `test/` altında `lib/` ile aynı yapıyı izler (ADR-0002).
- Altın görüntüler yalnızca Linux CI'da üretilir ve karşılaştırılır (yazı
  tipi işleme platforma göre değişir); font gömülü olduğu için (ADR-0004)
  sonuç kararlıdır.
- Testlerde gerçek ağ yoktur; `ApiClient` sahte HTTP istemcisiyle,
  provider'lar `overrides` ile kurulur (ADR-0001).
- Hata düzeltmesi, hatayı yeniden üreten bir testle gelir.

### CI (GitHub Actions)

- Yalnızca `pull_request` ve `main`'e `push` olaylarında çalışır;
  `pull_request_target` ve self-hosted runner kullanılmaz; fork PR'ları
  secret görmez (Tayfam-Api ADR-0010 ile aynı).
- Action'lar commit SHA'sıyla, Flutter sürümü dosyada sabit bir sürümle
  (`.flutter-version` veya iş akışında tek yerde) belirtilir; iş başına en
  az yetki (`permissions: contents: read`).
- Zorunlu kontroller (her biri ayrı iş, kural setinde zorunlu kontrol):
  1. `dart format --set-exit-if-changed`, `flutter analyze` (uyarılar hata)
  2. `flutter test` (birim, widget, golden)
  3. Üretilen API kodu güncel: üretici çalıştırıldıktan sonra fark yok
  4. Kural betiği: import sınırları, sabit renk/boşluk/yarıçap, sabit
     kullanıcı metni (`tool/kurallar/`, Dart ile)
  5. Bağımlılık raporu: `pubspec.lock` değişen PR'larda eklenen ve sürümü
     değişen paketler PR'a yorum olarak değil iş çıktısı olarak listelenir
  6. Gizli bilgi taraması: gitleaks
  7. Android debug derlemesi (`flutter build apk --debug`) ve geliştirme
     için web derlemesinin bozulmadığını görmek üzere `flutter build web`
     (yayınlanmaz, ADR-0011)
- Dependabot: `pub` ve `github-actions` için haftalık. Dependabot'un
  açtığı dallar `dependabot/…` adını taşır; CLAUDE.md'deki
  `<tür>/<kısa-açıklama>` dal adı kuralının tek istisnasıdır (platform
  sahibi, 2026-11-10).
- İmzalı sürüm derlemeleri (Play Store, App Store) bu ADR'nin
  kapsamı dışında; dağıtım kararıyla gelir.

### iOS derlemesi

- Şimdilik CI'da iOS derlemesi yoktur.
- Gerektiğinde GitHub Actions macOS runner'ı kullanılır (public repoda
  ücretsiz, diğer işlerle aynı yerde, aynı sabitleme kuralları). App Store
  ve TestFlight için Apple Developer üyeliği ayrıca gerekir.
- Codemagic değerlendirilmez: ayrı hesap ve ayrı bir tedarik zinciri
  halkası getirir.

### Kural seti

CI eklendikten sonra `main` kural setine yukarıdaki zorunlu kontroller
eklenir (platform sahibinin GitHub ayarı). O zamana kadar PR'lar platform
sahibi tarafından birleştirilir.

## Gerekçe

- Riskin yüksek olduğu yerler (oturum, kuyruk, WebSocket, üretici) birim
  testleriyle; görsel tutarlılık yalnızca ortak bileşenlerde golden
  testlerle korunuyor. Ekran golden'ları her küçük değişiklikte kırılıp
  bakım yükü oluştururdu.
- CI kuralları Tayfam-Api ile aynı: sabitlenmiş Action'lar, en az yetki,
  fork'a secret yok.
- macOS runner, iOS gerektiğinde ek hesap açmadan çalışır.

## Sonuçlar

- CI iş akışı `.github/workflows/` altındadır; hassas alan, platform sahibi
  birleştirir.
- Kural betiği ve OpenAPI üreticisi ilk iş paketlerindendir; CI onlarla
  birlikte açılır.

## Değerlendirilen alternatifler

- **Codemagic (iOS):** ayda 500 dakika ücretsiz M2; ayrı hesap ve tedarik
  zinciri.
- **Ekran düzeyinde golden testler:** daha çok görsel güvence, yüksek bakım.
- **Dev ortamına karşı otomatik uçtan uca test (integration_test):** gerçek
  akışı dener; ama dev ortamındaki veriye bağımlı ve kırılgan. Pilot sonrası
  yeniden değerlendirilir.
