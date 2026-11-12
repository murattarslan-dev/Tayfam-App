import 'package:flutter/material.dart';

/// "Google ile devam et" düğmesinin Google'ın oturum açma marka
/// kurallarındaki değerleri (Sign in with Google branding guidelines,
/// Android; ADR-0012 §2).
///
/// Açık temada kuralların "açık" (light) biçimi: beyaz zemin, #747775 1 px
/// kenar, #1F1F1F metin; koyu temada "koyu" (dark) biçimi: #131314 zemin,
/// #8E918F 1 px kenar, #E3E3E3 metin (Design: Giriş / Giriş koyu). Bu
/// renkler Tayfam paletinin parçası değildir; yalnızca bu düğmede
/// kullanılır.
abstract final class GoogleMarka {
  /// Düğme zemini.
  static const Color zemin = Color(0xFFFFFFFF);

  /// Düğme kenarı (1 px).
  static const Color kenar = Color(0xFF747775);

  /// Düğme metni.
  static const Color metin = Color(0xFF1F1F1F);

  /// Koyu biçimde düğme zemini.
  static const Color koyuZemin = Color(0xFF131314);

  /// Koyu biçimde düğme kenarı (1 px).
  static const Color koyuKenar = Color(0xFF8E918F);

  /// Koyu biçimde düğme metni.
  static const Color koyuMetin = Color(0xFFE3E3E3);

  /// Kenar kalınlığı.
  static const double kenarKalinligi = 1;

  /// "G" işaretinin boyutu (Android: 20 dp).
  static const double logo = 20;

  /// Düğmenin sol ve sağ iç boşluğu (Android: 12 dp).
  static const double yanBosluk = 12;

  /// "G" işareti ile metin arasındaki boşluk (Android: 10 dp).
  static const double logoMetinArasi = 10;

  /// Metin: Roboto Medium 14 / 20 (Android'de sistem fontu Roboto'dur;
  /// font gömülmez, indirilmez).
  static const TextStyle yazi = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: metin,
  );

  /// Google'ın resmi "G" işareti (google/GoogleSignIn-iOS deposundan;
  /// `assets/marka/KAYNAK.md`). 1×, 2× ve 3× çözünürlükleri vardır.
  static const String logoVarligi = 'assets/marka/google_g.png';
}
