## Issue

Closes #

## Ne değişti

<!-- Kısa açıklama. Neden gerekli? Ekran değişikliğinde ekran görüntüsü ekle. -->

## İlgili ADR'ler

<!-- Örn. ADR-0002, Tayfam-Api ADR-0014. Bu PR bir kararla çelişiyor veya yeni karar gerektiriyorsa burada açıkça yaz. -->

## Hassas alan

- [ ] Bu PR `.github/CODEOWNERS`'taki bir yola dokunuyor → yalnızca platform sahibi birleştirir.
      Dokunulan alan:

## Test

<!-- Hangi testler eklendi? Hangi platformda (Android / iOS / web) nasıl doğrulandı? -->

## Ele geçirilirse

<!-- Tayfam-Api ADR-0011: Bu cihaz veya tarayıcı oturumu ele geçirilirse bu değişiklik yüzünden saldırgan neye ulaşır? Hasar nasıl sınırlanıyor? -->

## Güvenlik kontrol listesi

- [ ] Yalnızca OpenAPI sözleşmesindeki uçlar ve alanlar kullanılıyor
- [ ] Token, anahtar veya kişisel veri düz depoya, log'a, analitiğe veya hata raporuna yazılmıyor
- [ ] Cihaz konumu saklanmıyor ve loglanmıyor
- [ ] Yetki kararı istemcide verilmiyor; sunucu hatası doğru ele alınıyor
- [ ] Derin linkten, bildirimden veya sunucudan gelen veri doğrulanıyor
- [ ] Gizlilik vaatleri korunuyor (gizli anket, içeriksiz bildirim, kapalı tayfa)
- [ ] Yeni platform izni yok ya da gerektiği anda isteniyor ve gerekçesi yazılı
- [ ] Gizli bilgi koda veya repoya girmiyor
- [ ] Yeni paket veya Action sabit sürümle ekleniyor ve gerekçesi yazılı
- [ ] Kullanıcı metinleri çeviri dosyalarında
