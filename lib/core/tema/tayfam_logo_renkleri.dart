import 'package:flutter/painting.dart';

import 'package:tayfam/core/tema/kontrast.dart';

/// Logonun ("Dörtlü") blok renkleri (Notion: Marka → Logo, Tasarım
/// Standartları → Logo kullanımı; 2026-11-12).
///
/// Blok renkleri sabittir ve temadan bağımsızdır: sol üst mango, sağ üst
/// nar, sağ alt turkuaz. Yalnızca büyük L parçası zemine göre değişir:
/// açık zeminde brand, koyu zeminde brand-dark, mor (brand) zeminde
/// #FAF8FF. Ham hex yalnızca bu dosyadadır; değerler `TayfamColors`
/// token'larıyla aynıdır (test denetler).
abstract final class TayfamLogoRenkleri {
  /// Sol üst blok.
  static const Color mango = Color(0xFFFFB000);

  /// Sağ üst blok.
  static const Color nar = Color(0xFFFF3D68);

  /// Sağ alt blok.
  static const Color turkuaz = Color(0xFF00C2A8);

  /// L parçası, açık zeminde (brand).
  static const Color lAcikZemin = Color(0xFF5B2BE0);

  /// L parçası, koyu zeminde (brand-dark).
  static const Color lKoyuZemin = Color(0xFFA98BFF);

  /// L parçası, mor (brand) zeminde; uygulama ikonu ve splash.
  static const Color lMorZemin = Color(0xFFFAF8FF);

  /// Uygulama ikonu ve açık tema splash zemini (brand).
  static const Color ikonZemini = lAcikZemin;

  /// Koyu tema splash zemini (ink).
  static const Color koyuSplashZemini = Color(0xFF1B1036);

  /// [zemin] üzerinde L parçasının rengi.
  ///
  /// Mor zeminde (#5B2BE0) #FAF8FF; diğer zeminlerde brand ile brand-dark
  /// arasından zeminden daha iyi ayrışanı: açık zeminde brand, koyu
  /// zeminde (ink, koyu kart) brand-dark.
  static Color lParcasi(Color zemin) {
    if (zemin.toARGB32() == lAcikZemin.toARGB32()) {
      return lMorZemin;
    }
    return kontrastOrani(lAcikZemin, zemin) >= kontrastOrani(lKoyuZemin, zemin)
        ? lAcikZemin
        : lKoyuZemin;
  }
}
