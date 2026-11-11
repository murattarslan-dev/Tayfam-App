/// Birebir mesaj metninin sözleşmedeki kuralları (`POST
/// /v1/direct-messages`): 1–4000 karakter, yalnız boşluk olamaz; sekme ve
/// satır sonu dışında kontrol karakteri içeremez.
library;

/// Mesaj metninin en çok uzunluğu (karakter).
const int birebirMetniEnCok = 4000;

/// [metin]'i gönderilecek biçime getirir: satır sonları `\n` olur,
/// baştaki ve sondaki boşluklar atılır.
String birebirMetniniHazirla(String metin) =>
    metin.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

/// Hazırlanmış [metin] ([birebirMetniniHazirla]) gönderilebilir mi.
bool birebirMetniGecerli(String metin) {
  if (metin.trim().isEmpty) return false;
  if (metin.runes.length > birebirMetniEnCok) return false;
  for (final r in metin.runes) {
    final sekmeYaDaSatir = r == 0x09 || r == 0x0A;
    final kontrol = r < 0x20 || (r >= 0x7F && r <= 0x9F);
    if (kontrol && !sekmeYaDaSatir) return false;
  }
  return true;
}
