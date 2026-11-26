# ADR-0029: Dal modeli (`dev` / `main`), sürüm numarası ve otomatik etiket

- **Durum:** Kabul edildi (uygulandı ve birleşti; durum satırı 2026-11-26'da düzeltildi)
- **Tarih:** 2026-11-16
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0009](0009-test-ci-ve-ios.md), [ADR-0013](0013-tanitim-sitesi.md),
  [ADR-0018](0018-faz1-kalan-moduller.md) §10; Tayfam-Api ADR-0006, ADR-0010,
  ADR-0011

## Bağlam

Bugüne kadar bütün iş PR'ları `main`'e squash ile birleşti ve `main`'e her
birleşme hem Play kapalı test kanalına (`play-dahili.yml`) hem de site
değiştiyse tayfam.app'e (`site-yayin.yml`) gitti. Günde birkaç PR birleştiği
için her biri ayrı bir Play sürümü ve Google incelemesi oldu; bir PR'ı
yayına çıkarmadan birleştirmenin yolu yoktu.

`surum.yml` ise `vX.Y.Z` etiketiyle tetiklenen ayrı bir imzalı derlemeydi
(`play-yayin` ortamı, `ANDROID_UPLOAD_*` secret'ları); hiç etiket atılmadı.
`versionCode`, `play-dahili.yml`'de `github.run_number + 100` idi (son
yükleme: 163).

Platform sahibi 2026-11-16'da sohbette şunlara karar verdi:

1. Bütün iş PR'ları `dev`'e squash ile birleşir; `dev`'e birleşmede hiçbir
   dağıtım yoktur, yalnızca CI.
2. `main` prod'dur. `dev` → `main` sürüm PR'ıyla birleşir; `main`'e her
   birleşme yayına gider ve sürüm etiketi otomatik atılır.
3. Sürüm PR'ını mimari oturumu, platform sahibinin sohbetteki onayıyla
   birleştirir.
4. `main`'e gelen PR yalnızca `dev`'den olabilir; değilse düşen zorunlu bir
   CI kontrolü vardır.
5. Dependabot `dev`'e PR açar.

## Karar

### 1. Dallar

| Dal | Ne birleşir | Yöntem | Ne çalışır |
|-----|-------------|--------|------------|
| `dev` | İş PR'ları (`<tür>/<kısa-açıklama>`), Dependabot | Squash | CI (`ci.yml`), push'ta da |
| `main` | Yalnızca `dev` → `main` sürüm PR'ı | Merge commit | CI + yayın (`play-dahili.yml`, `site-yayin.yml`) + etiket |

- Varsayılan dal `dev`'dir: PR'lar varsayılan olarak oraya açılır,
  `Closes #N` issue'yu `dev`'e birleşince kapatır, Dependabot güvenlik
  güncellemeleri (yapılandırmadaki `target-branch`'e uymaz, varsayılan dala
  açılır) `dev`'e gelir, CodeQL varsayılan kurulumu `dev`'i tarar.
- `main`'e doğrudan push, `dev`'den başka daldan PR ve sıcak düzeltme
  (hotfix) dalı yoktur. Acil bir düzeltme de `dev`'e birleşir ve hemen bir
  sürüm PR'ıyla çıkar.

### 2. Sürüm PR'ı neden merge commit

- Squash, `dev`'deki commit'leri `main`'de tek yeni bir commit'e çevirir;
  `dev` o commit'i hiç görmez. Sonraki sürüm PR'ında GitHub, önceki
  sürümdeki bütün commit'leri yeniden "fark" olarak gösterir, `dev` ile
  `main` her sürümde biraz daha ayrışır ve er geç çakışma çıkar.
- Merge commit'te `main`'in ikinci ebeveyni `dev`'in ucudur; `dev` `main`'in
  atasıdır, sonraki PR yalnızca yeni commit'leri gösterir. `main`'e başka bir
  yoldan commit girmediği için (§3) `main`'in ağacı her sürümde `dev`'in o
  anki ağacıyla aynıdır; `dev`'i `main`'e geri birleştirmek gerekmez.
- `main`'de doğrusal geçmiş zorunluluğu kapalıdır; birinci ebeveyn zinciri
  (`git log --first-parent main`) sürümlerin listesidir.

### 3. Yalnızca `dev`'den: `kaynak-dal` kontrolü

`ci.yml`'deki `kaynak-dal` işi her olayda çalışır ve sonuç üretir:

- Taban `main` olan PR'da baş dal bu repodaki `dev` değilse kırılır (fork'taki
  `dev` adlı dal da kırılır).
- Diğer PR'larda ve push'ta geçer.
- Kod indirmez, secret ve token kullanmaz (`permissions: {}`).
- `main` kural setinde zorunlu kontroldür. `dev` kural setinde de zorunlu
  tutulabilir; orada hep geçer.

### 4. Sürüm numarası

- **versionName = `pubspec.yaml`'daki `X.Y.Z`.** Her sürüm PR'ından önce
  `dev`'de bir PR ile artırılır (`chore(surum): X.Y.Z`); sürüm notu
  (`play/surum-notu.tr-TR.txt`) aynı PR'da güncellenir.
  - Hangi hanenin artacağı: kullanıcıya görünen yeni özellik → `Y`;
    yalnızca düzeltme → `Z`; `X` 1.0'a (genel yayın) kadar `0`.
  - `ci.yml`'deki `surum-numarasi` işi, `main`'e açılan PR'da `vX.Y.Z`
    etiketinin olmadığını ve `X.Y.Z`'nin var olan en büyük `v*`
    etiketinden büyük olduğunu denetler; değilse kırılır. Böylece her
    `main` birleşmesinin etiketi önceden bellidir ve tektir.
- **versionCode = `main`'in birinci ebeveyn commit sayısı + 1000.**
  - `git rev-list --count --first-parent HEAD`. Her sürüm birleşmesi
    `main`'e tam bir birinci ebeveyn commit'i ekler; sayı her sürümde artar.
  - `main` yalnızca ileri gider (kural seti: force push ve silme yok); sayı
    geri gitmez.
  - Aynı commit her zaman aynı kodu verir: yeniden çalıştırma, iş akışı
    dosyasının adı ya da çalışma sayacı kodu değiştirmez. Bir etiketten
    hangi kodun çıktığı geçmişten hesaplanabilir.
  - Taban 1000, önceki modelin son kodunun (163) üstündedir; Play yalnızca
    artan kod kabul eder. Bugün `main`'de 118 birinci ebeveyn commit var;
    ilk sürüm kodu 1119 civarı olur. Taban bir daha değiştirilmez.
  - `pubspec.yaml`'daki `+N` yalnızca yerel derlemeler içindir; yayın
    derlemesi `--build-number` ile ezer. `+N`'i artırmak gerekmez.

### 5. Yayın ve otomatik etiket

`main`'e push'ta `play-dahili.yml` (adı: "Yayın (Play + sürüm etiketi)")
dört işle çalışır:

1. `surum` (`contents: read`, secret yok): yalnızca `main`; versionName,
   versionCode ve etiket hesaplanır. `vX.Y.Z` başka bir commit'teyse iş
   durur; aynı commit'teyse (yeniden çalıştırma) etiket yeniden atılmaz.
2. `aab` (`contents: read`, `play-dahili` ortamı): imzalı `.aab` ve `.apk`.
   Değişmedi; yalnızca sürüm adı ve kodu `surum`'dan gelir.
3. `yukle` (`contents: read`, `id-token: write`): Workload Identity
   Federation ile Play kapalı test kanalına. Değişmedi.
4. `etiket` (`contents: write`): `yukle` gerçekten yüklediyse (GCP
   değişkenleri tanımlı ve yükleme başarılı) GitHub REST API'siyle
   (`POST /repos/{repo}/git/refs`, hafif etiket) `vX.Y.Z`'yi `main`
   commit'ine atar. Kod indirmez ve çalıştırmaz; yazma yetkisi yalnızca
   bu iştedir.

- **`GITHUB_TOKEN` ile atılan etiket başka iş akışını tetiklemez**
  (GitHub'ın sonsuz döngü koruması). Bu yüzden etiketle tetiklenen bir iş
  akışı kalmadı: etiket yalnızca "bu commit bu sürüm olarak yayına çıktı"
  kaydıdır. PAT ya da GitHub App eklenmez; en az yetki korunur.
- **`surum.yml` kaldırıldı.** İşi (prod API'ye bağlı imzalı `.aab`,
  etiketle pubspec'in eşleşmesi, debug imzasına düşmeme) `play-dahili.yml`
  zaten yapıyordu; etiket artık derlemenin sonucudur, tetikleyicisi
  değildir. Elle atılan bir `v*` etiketi hiçbir şeyi derlemez ya da
  yayınlamaz. `play-yayin` ortamı ve `ANDROID_UPLOAD_*` secret'ları
  kullanılmıyor; platform sahibi silebilir (ADR-0018 §10 Notlar
  2026-11-11: yükleme anahtarı geliştirme anahtarıdır).
- **Eşzamanlılık:** her `main` birleşmesi etiketli bir sürümdür; çalışmalar
  sırayla gider, iptal edilmez (`cancel-in-progress: false`; önceki model
  yalnızca en son `main`'i yüklemek için iptal ediyordu).
- **Elle çalıştırma** (`workflow_dispatch`, yalnızca `main`): yarıda kalan
  bir yayını tamamlamak içindir. `main`'in ucu zaten Play'e yüklenmişse
  Play aynı versionCode'u reddeder; bu beklenen davranıştır.
- **Site:** `site-yayin.yml` değişmedi; zaten yalnızca `main`'e push'ta ve
  `site/**` değişince yayınlar. Site değişiklikleri artık sürüm PR'ıyla
  çıkar. Site yayını etikete bağlı değildir.
- **Etiket kural seti (`v*`):** güncelleme ve silme yasak; yanlış atılmış
  bir etiket yerinde bırakılır, yeni sürüm yeni etiket alır.

### 6. Sürüm PR'ını kim birleştirir

- Sürüm PR'ını mimari oturumu, platform sahibinin sohbetteki onayıyla
  birleştirir (merge commit). PR açıklamasında "Sohbette onaylandı" notu ve
  sürüm numarası yazılır.
- Sürüm PR'ı yalnızca `dev`'de zaten incelenip birleşmiş değişiklikleri
  taşır; hassas alan kuralı (CLAUDE.md) iş PR'ları `dev`'e birleşirken
  uygulanır. `.github/`, imzalama yapılandırması ve `CLAUDE.md`'ye dokunan
  iş PR'larını `dev`'e de yalnızca platform sahibi birleştirir.
- Adımlar: [`docs/runbooks/surum-cikarma.md`](../runbooks/surum-cikarma.md).

### 7. Güvenlik eşitlemesi (Tayfam-Api ile)

Tayfam-Api ADR-0010 ve ADR-0011'deki önlemlerden bu repoda karşılığı olanlar:

| Önlem (Tayfam-Api) | Bu repoda |
|--------------------|-----------|
| Actions commit SHA'sıyla sabit | Var (bütün iş akışları). GitHub ayarı "SHA ile sabitlemeyi zorunlu kıl" ile ayrıca zorlanır (platform sahibi). |
| Varsayılan yetki salt okunur, iş başına en az yetki | Var. `play-dahili.yml` artık `permissions: {}` ile başlar; yazma yetkisi yalnızca `etiket` işinde. |
| `pull_request_target` ve self-hosted runner yok, fork'a secret yok | Var. |
| gitleaks | Var (`gizli-bilgi`). |
| Secret scanning ve push protection | GitHub ayarı (platform sahibi). |
| Kural seti: PR zorunlu, force push/silme yok, bypass yok, zorunlu CI | `dev` ve `main` için ayrı kural setleri (platform sahibi). |
| Bağımlılık açıkları (`govulncheck`) | Dart için resmi bir karşılığı yok; Dependabot alerts (pub ekosistemi GitHub Advisory Database'de) ve güvenlik güncellemeleri açılır. |
| Dependabot haftalık | Var; `target-branch: dev`. |
| `SECURITY.md`, özel açık bildirimi | Var; "Desteklenen sürümler" eklendi. Özel açık bildirimi (private vulnerability reporting) ayarının açık olduğu doğrulanır. |
| Prod etiketinin `main`'deki bir commit'i göstermesi | Etiketi yalnızca `main`'e push'ta çalışan iş akışı, o push'un commit'ine atar. |

Tayfam-Api'de olmayan, burada eklenen:

- **CodeQL varsayılan kurulumu** (GitHub ayarı, iş akışı dosyası yok):
  - Dart desteklenmez.
  - **GitHub Actions** (iş akışlarında enjeksiyon, güvensiz checkout,
    fazla yetki) taranır. Güven zincirinin kökü iş akışları olduğu için en
    değerli tarama budur.
  - **Java/Kotlin** (`android/`: Signal köprüsü, MainActivity; derlemesiz
    `build-mode: none`) taranır.
  - **Python** (`tool/play/dahili_yukle.py`: Play API'sine token'la konuşan
    betik; `.github/site-denetimi/denetle.py`) taranır.
  - **JavaScript:** site JavaScript içermez (`site-denetimi` `<script>`'i
    yasaklar); taranacak bir şey yok.
  - **Swift (`ios/`):** macOS runner gerektirir, kod şablon düzeyinde;
    şimdilik dışarıda.
  - Varsayılan kurulum seçildi: GitHub bakımını yapar, repoda sabitlenecek ya
    da Dependabot'un güncelleyeceği yeni bir Action eklemez. Sonuçlar
    kural setinde "Code scanning results" kuralıyla zorunlu tutulur.

### 8. Geçiş

Bu ADR'yi getiren PR, `dev` daha yokken `main`'e açılır. `kaynak-dal` işi
bu tek durum için `dev` dalı yoksa uyarıyla geçer; `dev` oluşturulduktan
sonra (ve `dev` kural setiyle silinemediği için) bu dal bir daha işlemez.

Sıra (platform sahibi):

1. Bu PR `main`'e birleşir (squash). Yayın iş akışı ilk kez yeni kurallarla
   çalışır: `pubspec.yaml` `0.1.0` olduğu ve etiket olmadığı için `v0.1.0`
   etiketi atılır.
2. `main`'den `dev` oluşturulur, varsayılan dal `dev` yapılır.
3. Kural setleri ve güvenlik ayarları uygulanır (PR açıklamasındaki liste).
4. Açık iş PR'larının tabanı `dev`'e çevrilir.

## Gerekçe

- Yayın birleştirmeden ayrılır: iş PR'ları hızla `dev`'de birikir, yayın
  ritmini platform sahibi belirler; her PR ayrı bir Play incelemesine
  girmez.
- `main`'e tek giriş noktası (yalnızca `dev`, yalnızca PR, zorunlu
  kontroller) prod'a ulaşabilecek yolları daraltır (Tayfam-Api ADR-0011:
  hasarı sınırla).
- versionCode'un git geçmişinden hesaplanması elle artırma hatasını ve iş
  akışı sayacına bağımlılığı ortadan kaldırır; versionName'in elle
  artırılması anlamlı bir sürüm numarası bırakır ve CI ile denetlenir.
- Etiketin derlemeden sonra atılması "etiket = gerçekten yayına çıkan" demektir;
  derleme ya da yükleme düşerse etiket yoktur.

## Sonuçlar

- `ci.yml`: `kaynak-dal` ve `surum-numarasi` işleri; `dev`'e push'ta da
  çalışır.
- `play-dahili.yml`: `surum` ve `etiket` işleri, yeni versionCode kuralı,
  iptalsiz eşzamanlılık, varsayılan yetki yok.
- `surum.yml` silindi.
- `dependabot.yml`: `target-branch: dev`.
- `CLAUDE.md` "İş akışı", ADR-0009 (revizyon notu), ADR-0018 §10 (not)
  güncellendi; `docs/runbooks/surum-cikarma.md` eklendi.
- Her sürümden önce `dev`'de bir sürüm numarası PR'ı gerekir (küçük, rutin).

## Değerlendirilen alternatifler

- **Sürüm PR'ı squash:** `main` doğrusal kalır ama `dev` ile `main` her
  sürümde ayrışır; her sürümden sonra `main`'i `dev`'e geri birleştirmek
  gerekir (o da `dev`'e squash dışı bir commit sokar).
- **versionCode = `run_number + 100` (eski kural):** basit, ama iş akışı
  dosyası yeniden adlandırılınca ya da yeniden oluşturulunca sıfırlanır;
  etiketten kod hesaplanamaz.
- **versionCode = `pubspec.yaml`'daki `+N` (elle):** git'te görünür ama
  her sürümde iki sayının elle artırılması gerekir; unutulursa Play
  reddeder.
- **versionCode = `X*10000 + Y*100 + Z`:** sürüm adından türetilir, ama
  aynı sürümün yeniden yüklenmesi ya da haneler taşınca kod çakışır.
- **Etiketle tetiklenen ayrı yayın iş akışı (`surum.yml`'yi tutmak):**
  `GITHUB_TOKEN`'la atılan etiket onu tetiklemez; tetiklemek için PAT ya da
  GitHub App gerekir (uzun ömürlü yazma kimliği, en az yetkiye aykırı).
- **Sürümü `main`'den otomatik, `pubspec.yaml`'ı CI'ın yazması:** CI'a
  `main`'e ya da `dev`'e push yetkisi vermek gerekir; kural setinde bypass
  ister.
- **CodeQL gelişmiş kurulum (iş akışı dosyası):** sabitlenmiş Action ve
  repoda görünen yapılandırma; ama bakım ve yeni bir tedarik zinciri
  halkası getirir. Varsayılan kurulum yetmezse geçilir.
