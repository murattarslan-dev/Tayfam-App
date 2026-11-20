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

/// [ad]'a gelecek ilgi (tamlayan) eki, kesme işaretiyle: "Murat" → "'ın",
/// "Ayşe" → "'nin", "Oğuz" → "'un", "Gül" → "'ün" (Şimdi başlat'ın
/// varsayılan başlığı, App ADR-0032 §2). Ek son ünlüye göre seçilir; ad
/// ünlüyle bitiyorsa araya "n" girer. Adda Türkçe ünlü yoksa "'in".
///
/// Yalnızca ek döner; metnin kendisi çeviri dosyasındadır.
String ilgiEki(String ad) {
  final harfler = turkceKucukHarf(ad.trim());
  String? sonUnlu;
  for (final harf in harfler.split('').reversed) {
    if (_unluler.contains(harf)) {
      sonUnlu = harf;
      break;
    }
  }
  final unluyleBiter =
      harfler.isNotEmpty && _unluler.contains(harfler[harfler.length - 1]);
  final ek = switch (sonUnlu) {
    'a' || 'ı' => 'ın',
    'o' || 'u' => 'un',
    'ö' || 'ü' => 'ün',
    _ => 'in',
  };
  return unluyleBiter ? "'n$ek" : "'$ek";
}

const Set<String> _unluler = {'a', 'e', 'ı', 'i', 'o', 'ö', 'u', 'ü'};
