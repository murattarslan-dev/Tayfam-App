import 'package:flutter/foundation.dart';

/// Yer adının en çok uzunluğu (karakter; sözleşme `Place.name`
/// `maxLength: 120`).
const int yerAdiEnCok = 120;

/// Kullanıcının haritadan seçip paylaştığı yer (Tayfam-Api ADR-0031 §4,
/// ADR-0008: içerik, cihaz konumu değil; istemci ADR-0028 §5).
///
/// Kanal mesajında sözleşmedeki `Place`'ten, birebirde zarfın içinden
/// gelir; ikisi de girdidir ve [gecerliMi] ile denetlenir. Koordinat ve ad
/// hiçbir yere yazılmaz, loglanmaz; `toString` içerik yazmaz.
@immutable
final class PaylasilanYer {
  const PaylasilanYer({required this.enlem, required this.boylam, this.ad});

  /// −90..90.
  final double enlem;

  /// −180..180.
  final double boylam;

  /// İsteğe bağlı ad (1–120 karakter); yoksa `null`.
  final String? ad;

  /// Değerler sözleşmenin sınırlarında mı: sonlu enlem ve boylam aralıkta,
  /// ad varsa [yerAdiGecerli].
  bool get gecerliMi =>
      enlem.isFinite &&
      boylam.isFinite &&
      enlem >= -90 &&
      enlem <= 90 &&
      boylam >= -180 &&
      boylam <= 180 &&
      (ad == null || yerAdiGecerli(ad!));

  @override
  bool operator ==(Object other) =>
      other is PaylasilanYer &&
      other.enlem == enlem &&
      other.boylam == boylam &&
      other.ad == ad;

  @override
  int get hashCode => Object.hash(enlem, boylam, ad);

  @override
  String toString() => 'PaylasilanYer(…)';
}

/// Yer adı gönderilebilir mi: kırpılmış hâli 1–[yerAdiEnCok] karakter
/// (Unicode kod noktası) ve kontrol karakteri yok.
bool yerAdiGecerli(String ad) {
  final kirpik = ad.trim();
  if (kirpik.isEmpty || kirpik != ad) return false;
  if (kirpik.runes.length > yerAdiEnCok) return false;
  for (final r in kirpik.runes) {
    if (r < 0x20 || (r >= 0x7F && r <= 0x9F)) return false;
  }
  return true;
}

/// Kullanıcının yazdığı adı gönderilecek biçime getirir: satır sonları
/// boşluk olur, kırpılır, [yerAdiEnCok] karakterde kesilir; boşsa `null`.
String? yerAdiniHazirla(String ham) {
  final tek = ham.replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), ' ');
  final kirpik = tek.trim();
  if (kirpik.isEmpty) return null;
  final kodlar = kirpik.runes;
  if (kodlar.length <= yerAdiEnCok) return kirpik;
  return String.fromCharCodes(kodlar.take(yerAdiEnCok)).trim();
}
