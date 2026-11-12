import 'package:flutter/material.dart';

/// Uygulama içi yazı ölçeği (ADR-0004 §4) ve gömülü font.
///
/// Font: Bricolage Grotesque (SIL OFL), `assets/fonts/` altında statik
/// örnekler olarak gömülü; `google_fonts` yok, çalışma anında ağ isteği yok.
/// Yedek font platformun sistem fontudur.
abstract final class TayfamTypography {
  /// pubspec.yaml'daki font ailesi adı.
  static const String aile = 'BricolageGrotesque';

  /// Büyük başlık ağırlığı. Tasarım 750'dir (ADR-0004 §4); Flutter'da
  /// ağırlıklar 100'ün katı olduğu için wght 750 örneği pubspec'te 800
  /// yuvasına kaydedilir. `FontWeight.w800` bu dosyayı seçer.
  static const FontWeight buyukBaslikAgirligi = FontWeight.w800;

  /// Gövde metninin alt sınırı (ADR-0004 §4).
  static const double enKucukBoyut = 13;

  /// ADR-0004 §4 ölçeğiyle `TextTheme`. Renk verilen [metin] rengidir;
  /// ikincil metin stili ([TextTheme.bodySmall]) [ikincil] rengini alır.
  static TextTheme metinTemasi({required Color metin, required Color ikincil}) {
    // Büyük başlık (karşılama, boş durum): 28 / 750 / 1.1
    final buyukBaslik = _stil(28, buyukBaslikAgirligi, 1.1, metin);
    // Ekran başlığı (H3): 22 / 700 / 1.1
    final ekranBasligi = _stil(22, FontWeight.w700, 1.1, metin);
    // Gövde: 17 / 400 / 1.5
    final govde = _stil(17, FontWeight.w400, 1.5, metin);
    return TextTheme(
      displayLarge: buyukBaslik,
      displayMedium: buyukBaslik,
      displaySmall: buyukBaslik,
      headlineLarge: buyukBaslik,
      headlineMedium: buyukBaslik,
      headlineSmall: ekranBasligi,
      titleLarge: ekranBasligi,
      titleMedium: _stil(17, FontWeight.w700, 1.4, metin),
      titleSmall: _stil(15, FontWeight.w700, 1.4, metin),
      bodyLarge: govde,
      bodyMedium: govde,
      // İkincil metin: 15 / 400 / 1.4
      bodySmall: _stil(15, FontWeight.w400, 1.4, ikincil),
      // Etiket: 13–15 / 600–700 / 1.4
      labelLarge: _stil(15, FontWeight.w700, 1.4, metin),
      labelMedium: _stil(13, FontWeight.w700, 1.4, metin),
      labelSmall: _stil(13, FontWeight.w600, 1.4, metin),
    );
  }

  /// Giriş ekranının mor üst alanındaki büyük başlık (slogan ya da davet
  /// başlığı; Design: Giriş): 48 / 800 (wght 750) / 0.95, harf aralığı
  /// −%4.5 (Standartlar: Display). ADR-0004 §4'teki uygulama içi ölçeğin
  /// dışındadır; yalnızca giriş ekranında kullanılır.
  static TextStyle markaBasligi(Color renk) {
    const boyut = 48.0;
    return _stil(
      boyut,
      buyukBaslikAgirligi,
      .95,
      renk,
    ).copyWith(letterSpacing: boyut * -.045);
  }

  /// Giriş ekranının alt bölümündeki başlık (Design: Giriş): 24 / 700 /
  /// 1.08, harf aralığı −%1.
  static TextStyle girisBasligi(Color renk) {
    const boyut = 24.0;
    return _stil(
      boyut,
      FontWeight.w700,
      1.08,
      renk,
    ).copyWith(letterSpacing: boyut * -.01);
  }

  static TextStyle _stil(
    double boyut,
    FontWeight agirlik,
    double satir,
    Color renk,
  ) {
    return TextStyle(
      fontFamily: aile,
      fontSize: boyut,
      fontWeight: agirlik,
      height: satir,
      letterSpacing: 0,
      color: renk,
    );
  }
}
