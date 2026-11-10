import 'package:flutter/animation.dart';

/// Hareket süreleri ve eğrileri (ADR-0004: geçişler 150–250 ms).
///
/// "Hareketi azalt" açıkken (`MediaQuery.disableAnimationsOf`) bileşenler
/// süs animasyonlarını kapatır ve geçişleri anında yapar.
abstract final class TayfamMotion {
  /// Küçük durum değişimleri (renk, saydamlık).
  static const Duration kisa = Duration(milliseconds: 150);

  /// Varsayılan geçiş.
  static const Duration orta = Duration(milliseconds: 200);

  /// Daha büyük yer değişimleri (anket çubuğu dolumu).
  static const Duration uzun = Duration(milliseconds: 250);

  /// "Çok yakında" rozetindeki noktanın bir nabız turu. Geçiş değil, durum
  /// göstergesidir; "hareketi azalt" açıkken çalışmaz.
  static const Duration nabiz = Duration(milliseconds: 1600);

  /// Varsayılan eğri.
  static const Curve egri = Curves.easeOutCubic;
}
