# ADR-0013: Tanıtım sitesi (tayfam.app) bu repoda, CI ile Cloudflare Pages'e

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-10
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0009](0009-test-ci-ve-ios.md), [ADR-0011](0011-yalnizca-mobil.md), [ADR-0012](0012-giris-ve-kayit-akisi.md); Notion: Tasarım Standartları "Web güvenliği (tanıtım sayfası)", Mağaza Sayfası, Proje Planı §8 "Web"

## Bağlam

tayfam.app, Cloudflare Pages'te yayında olan statik bir tanıtım sayfasıdır.
Kaynağı iki repoda da yoktur; yayın elle yapılmıştır. Siteye yakında şunlar
eklenecek:

- sürümlü hukuki metin sayfaları (ADR-0012),
- Play'in istediği gizlilik politikası ve hesap silme sayfaları,
- davet ve referans linklerinin karşılama sayfaları,
- uygulama linklerini doğrulayan `/.well-known/assetlinks.json` ve
  `apple-app-site-association`.

Platform sahibi site için ayrı bir repo istemiyor.

## Karar

1. **Kaynak:** Tayfam-App'in `main` dalında `site/` klasörü. Ayrı dal ya
   da ayrı repo yok. main'in kural seti (PR, CI) site için de geçerlidir.
2. **Hassas alan:** `site/` CODEOWNERS'a eklenir. Bunun iki nedeni var:
   - `site/.well-known/` uygulamanın imza parmak izini ve kimliğini
     (`com.murattarslan.tayfam`) taşır.
   - Davet linkinin açıldığı alan adı oltalama için değerlidir.
3. **Kurallar (Tasarım Standartları):**
   - Sayfa JavaScript içermez.
   - Güvenlik başlıkları `site/_headers` ile verilir: sıkı CSP,
     X-Content-Type-Options, Referrer-Policy, Permissions-Policy, HSTS,
     çerçeveye gömülme yasağı.
   - Dış kaynak olarak yalnızca Google Fonts kullanılır, o da gömülü
     fonta geçilince kalkar.
4. **Hukuki metinler:**
   - Onaylanan sürümler değişmez sayfalardır:
     `site/yasal/aydinlatma-metni/<sürüm>/` ve
     `site/yasal/kullanim-kosullari/<sürüm>/`.
   - `/gizlilik` en son aydınlatma metni sürümüne yönlendirir (`_redirects`).
   - Yayımlanmış bir sürümün içeriği değiştirilmez; değişiklik yeni sürümdür
     ve sunucudaki `CONSENT_*_VERSION` ile birlikte ilerler.
5. **CI:**
   - `site/**` değişen PR'larda bir `site` işi çalışır. Denetledikleri:
     HTML geçerliliği, iç bağlantılar, `<script>` olmaması, `_headers`'ta
     zorunlu başlıklar, `.well-known` dosyalarının JSON geçerliliği.
   - Yayın ayrı bir iş akışıdır: yalnızca `main`'e push'ta ve `site/**`
     değiştiğinde çalışır, yalnızca main'e açık `cloudflare-pages` GitHub
     ortamını kullanır, `cloudflare/wrangler-action` (SHA ile sabit) ile
     `wrangler pages deploy site` çalıştırır.
   - PR'lardan yayın ya da önizleme yoktur.
6. **Token:**
   - Yalnızca "Account → Cloudflare Pages → Edit" yetkili bir Cloudflare
     API token'ı kullanılır. Token o ortamın secret'ıdır
     (`CLOUDFLARE_API_TOKEN`); hesap kimliği ve proje adı değişkendir.
   - Bu yetki tek projeyle sınırlanamaz; hesaptaki bütün Pages projelerini
     kapsar. Bu bilerek kabul edildi.
   - Token'a süre sınırı ve IP kısıtı konmaz (GitHub runner IP'leri
     değişir). Yılda bir yenilenir.

## Gerekçe

- Ayrı bir dal kendi kural setini ister. Kurulmazsa koruması zayıf kalır.
- Uygulama linki doğrulama dosyaları ve hukuki metinler uygulamayla birlikte
  değişir; aynı PR'da ve aynı incelemede gitmeleri tutarlılığı korur.
- Yayının GitHub Actions'tan yapılması, yayından önce CI'ı şart koşar.

## Sonuçlar

- `site/` klasörü Flutter derlemesine girmez. Kural betiği ve Flutter
  analizi `site/`'a bakmaz.
- Platform sahibinin işleri (bir kez):
  - Cloudflare token'ı,
  - GitHub'da `cloudflare-pages` ortamı ve secret/değişkenleri,
  - mevcut site dosyalarının repoya alınması için iletilmesi.
- `CLAUDE.md`'deki "web istemcisi yok" ilkesi değişmez; site uygulama
  değildir.

## Değerlendirilen alternatifler

- **Ayrı bir `site` dalı:** platform sahibinin ilk önerisi. Ayrı kural seti
  gerektirdiği ve uygulamayla birlikte değişen dosyaları ayırdığı için
  klasör tercih edildi.
- **Ayrı repo:** platform sahibi istemedi.
- **Cloudflare'in Git bağlantısı:** GitHub'da token gerektirmez, ama yayın
  CI'a bağlı olmaz ve Cloudflare'in GitHub uygulamasına repo erişimi verir.
