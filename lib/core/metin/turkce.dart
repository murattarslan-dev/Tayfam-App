/// Türkçe metin yardımcıları (ADR-0008).
///
/// Arayüzde harf dönüşümü yapılmaz; bu dosyadaki yardımcılar yalnızca
/// arama ve tekillik (ör. aynı etiketin iki kez girilmesi) içindir.
library;

/// [metin]'in Türkçe kurallarla küçük harfli biçimi: `I` → `ı`, `İ` → `i`.
///
/// Dart'ın `toLowerCase`'i dilden bağımsızdır; `I`'yı `i`'ye, `İ`'yi `i̇`'ye
/// (i + birleşik nokta) çevirir. Bu yüzden önce bu iki harf elle çevrilir.
String turkceKucukHarf(String metin) =>
    metin.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
