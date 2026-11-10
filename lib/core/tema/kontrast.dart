import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.x kontrast eşikleri.
abstract final class KontrastEsigi {
  /// Normal metin (AA).
  static const double metin = 4.5;

  /// Büyük metin (≥ 24 px veya ≥ 18.66 px kalın) ve arayüz öğesi (AA).
  static const double buyukMetinVeArayuz = 3;
}

/// sRGB göreli parlaklık (WCAG 2.x tanımı). Saydamlık yok sayılır.
double goreliParlaklik(Color renk) {
  double kanal(double c) {
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * kanal(renk.r) +
      0.7152 * kanal(renk.g) +
      0.0722 * kanal(renk.b);
}

/// İki rengin WCAG kontrast oranı (1–21).
double kontrastOrani(Color a, Color b) {
  final la = goreliParlaklik(a);
  final lb = goreliParlaklik(b);
  final acik = math.max(la, lb);
  final koyu = math.min(la, lb);
  return (acik + 0.05) / (koyu + 0.05);
}
