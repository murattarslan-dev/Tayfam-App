import 'package:flutter/foundation.dart';

/// Onaylanan hukuki metinler (ADR-0012 §4).
enum HukukiMetin {
  /// KVKK aydınlatma metni.
  aydinlatma('aydinlatma-metni'),

  /// Kullanım koşulları.
  kosullar('kullanim-kosullari');

  const HukukiMetin(this._yol);

  final String _yol;
}

/// Sunucudan gelen metin sürümünün kabul edilen biçimi (ADR-0012 §4).
final RegExp hukukiSurumBicimi = RegExp(r'^[A-Za-z0-9._-]{1,32}$');

/// Sürüm geçerliyse metnin tayfam.app'teki sürümlü sayfası:
/// `https://tayfam.app/yasal/<metin>/<sürüm>`; değilse `null`.
///
/// Sürüm sunucudan gelir ve girdi kabul edilir (CLAUDE.md, Doğrula);
/// `.` ve `..` yolu değiştirebileceği için reddedilir.
Uri? hukukiMetinAdresi(HukukiMetin metin, String surum) {
  if (!hukukiSurumBicimi.hasMatch(surum) || surum == '.' || surum == '..') {
    return null;
  }
  return Uri(
    scheme: 'https',
    host: 'tayfam.app',
    pathSegments: ['yasal', metin._yol, surum],
  );
}

/// Onaylanacak metinlerin sunucudaki güncel sürümleri. Yalnızca
/// [olustur] ile, ikisi de doğrulanmış olarak kurulur.
@immutable
final class OnaySurumleri {
  const OnaySurumleri._(this.aydinlatma, this.kosullar);

  /// Aydınlatma metni sürümü.
  final String aydinlatma;

  /// Kullanım koşulları sürümü.
  final String kosullar;

  /// İki sürüm de [hukukiSurumBicimi]'ne uyuyorsa örnek; değilse
  /// [FormatException] (mesajda değer yoktur).
  static OnaySurumleri olustur({
    required String aydinlatma,
    required String kosullar,
  }) {
    if (hukukiMetinAdresi(HukukiMetin.aydinlatma, aydinlatma) == null ||
        hukukiMetinAdresi(HukukiMetin.kosullar, kosullar) == null) {
      throw const FormatException('Geçersiz metin sürümü');
    }
    return OnaySurumleri._(aydinlatma, kosullar);
  }

  /// [metin]'in sürümlü sayfası.
  Uri adres(HukukiMetin metin) => hukukiMetinAdresi(metin, surum(metin))!;

  /// [metin]'in sürümü.
  String surum(HukukiMetin metin) => switch (metin) {
    HukukiMetin.aydinlatma => aydinlatma,
    HukukiMetin.kosullar => kosullar,
  };

  @override
  bool operator ==(Object other) =>
      other is OnaySurumleri &&
      other.aydinlatma == aydinlatma &&
      other.kosullar == kosullar;

  @override
  int get hashCode => Object.hash(aydinlatma, kosullar);
}
