# ADR-0008: Çeviri dosyaları, yerel ayar ve Türkçe metin işleme

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0004](0004-tema-ve-bilesen-dili.md), [ADR-0005](0005-api-istemcisi.md); Notion: Özellik Haritası (Dil), Tasarım Standartları

## Bağlam

Arayüz Türkçedir; tüm metinler çeviri dosyalarında olacak, ikinci dil
sonradan eklenebilecektir (Özellik Haritası). API Türkçe metin döndürmez;
hata kodları makine tarafından okunur (ADR-0005). Dart'ın `toUpperCase()` /
`toLowerCase()` fonksiyonları dilden bağımsızdır: "i" → "I" ve "I" → "i"
yapar, Türkçede yanlıştır.

## Karar

### Çeviri altyapısı

- Flutter'ın resmi `gen_l10n` altyapısı: `lib/l10n/app_tr.arb` kaynak
  dosyadır; erişim üretilen `AppLocalizations` sınıfıyla. Bağımlılıklar
  `flutter_localizations` ve `intl` (Flutter ekibinin).
- Sayıya ve cinsiyete göre değişen metinler ICU biçimiyle yazılır
  (`{count, plural, =0{…} other{…}}`); metin parçaları birleştirilerek
  cümle kurulmaz.
- Anahtar adları özellik önekiyle, `snake_case`:
  `etkinlik_katilim_sayisi`, `sohbet_gonderilemedi`. Hata kodu anahtarları
  `hata_<kod>` biçimindedir ve ADR-0005'teki eşlemeyle birlikte üretilir.
- Her anahtarın ARB'de `@açıklama`sı vardır (ne zaman ve nerede
  görüldüğü); ikinci dile çeviren için bağlam budur.
- Metin yazımı Tasarım Standartları'na uyar: cümle düzeni, tamamı büyük
  harf etiket yok.

### Yerel ayar, tarih ve sayı

- Varsayılan ve şimdilik tek yerel ayar `tr_TR`. Cihaz başka bir dilde
  olsa da Türkçe gösterilir; ikinci dil eklenince cihaz diline göre seçilir.
- Tarih, saat ve sayılar `intl` ile `tr_TR` biçiminde gösterilir
  ("Cumartesi, 09:00", "1.250").
- Sunucudan gelen zamanlar UTC'dir; cihazın saat diliminde gösterilir.
  Etkinlik zamanı gösterilirken saat dilimi farkı varsa (cihaz Türkiye
  dışında) bu belirtilir.
- Göreli zaman ("5 dk önce") çeviri dosyasındaki ICU kalıplarıyla yazılır.

### Türkçe metin işleme

- Arayüzde harf dönüştürme yapılmaz; `toUpperCase()` / `toLowerCase()`
  kullanıcıya gösterilen metinde kullanılmaz.
- Arama, karşılaştırma ve tekillik için `core/metin/` altında tek bir
  `turkceKucukHarf()` yardımcısı vardır: İ → i, I → ı, ardından genel
  küçük harf. Tayfam-Api'deki `name_normalized` ile aynı sonucu verir ve bu
  testle sabitlenir.
- Sıralama Türkçe alfabeye göre yapılır (ç, ğ, ı, ö, ş, ü doğru yerinde).

### Denetim

- Widget'larda sabit kullanıcı metni (`Text('…')`, `tooltip: '…'`,
  `semanticLabel: '…'`) olmadığı CI'daki kontrol betiğiyle denetlenir
  (ADR-0004'teki token betiğiyle aynı betik).
- Kullanılmayan ve eksik anahtarlar CI'da raporlanır; ARB'de olup kodda
  kullanılmayan anahtar uyarı, kodda kullanılıp ARB'de olmayan anahtar
  derleme hatasıdır (`gen_l10n` bunu zaten yapar).

## Gerekçe

- `gen_l10n` Flutter'ın kendi çözümü; ek üretici veya üçüncü taraf paket
  gerektirmiyor, derleme zamanında tür güvenli erişim veriyor.
- Türkçe harf dönüşümü hatası arama ve tekillikte sessiz yanlışlara yol
  açar; tek yardımcı ve API ile ortak test bunu önler.

## Sonuçlar

- Bağımlılıklar: `flutter_localizations`, `intl`.
- Testler: `turkceKucukHarf` için Tayfam-Api ile aynı örnek tablo; ICU
  çoğul kalıplarının 0/1/çok durumları; her `ProblemType` için anahtar
  varlığı (ADR-0005).

## Değerlendirilen alternatifler

- **`easy_localization` vb. üçüncü taraf paketler:** çalışma anında JSON
  okur, tür güvenliği zayıf, ek bağımlılık.
- **Metinleri sabit olarak kodda tutup sonra taşımak:** ikinci dil ve
  tutarlılık için sonradan pahalı.
