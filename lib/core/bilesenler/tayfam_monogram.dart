import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/kontrast.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_typography.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfam monogramı ("Hareket"): akışkan küçük "t" (Notion: Marka,
/// Tasarım Standartları → Logo kullanımı).
///
/// Tanıtım sitesindeki `icon.svg` yollarıyla birebir çizilir; SVG paketi
/// yoktur ([MonogramBoyaci]). Gövde zemine göre seçilir: açık zeminde brand,
/// koyu zeminde (koyu tema zemini, mor marka yüzeyi) turkuaz
/// ([monogramGovdeRengi]). Yatay çizgi her zaman mango, nokta her zaman nar.
///
/// [TayfamMonogram.yazili] yanına küçük harfle "tayfam" yazar; monogram
/// [TayfamSizes.logoYaziEsigi]'nin (24 px) altındaysa yazı gösterilmez.
/// Boyut [TayfamSizes.logoEnKucuk]'ten (16 px) küçük olamaz.
///
/// Logo bir görseldir: ekran okuyucu tek bir "Tayfam" görseli olarak okur;
/// yazı sistemin yazı büyütme ayarıyla ölçeklenmez (oranı bozulmasın diye),
/// dar alanda bütün logo orantılı küçülür.
class TayfamMonogram extends StatelessWidget {
  /// Yalnız monogram.
  const TayfamMonogram({
    super.key,
    this.boyut = TayfamSizes.logoYaziEsigi,
    this.zemin,
    this.baslik = false,
  }) : yazili = false,
       assert(boyut >= TayfamSizes.logoEnKucuk);

  /// Monogram + "tayfam" yazısı.
  const TayfamMonogram.yazili({
    super.key,
    this.boyut = TayfamSizes.logoBuyuk,
    this.zemin,
    this.baslik = false,
  }) : yazili = true,
       assert(boyut >= TayfamSizes.logoEnKucuk);

  /// Monogramın kenar uzunluğu (kare).
  final double boyut;

  /// Logonun durduğu zeminin rengi; verilmezse temanın sayfa zemini
  /// (`TayfamColors.zemin`). Mor marka yüzeyinde `markaYuzey` verilir.
  final Color? zemin;

  /// Ekran başlığı olarak okunsun mu (açılış ve giriş ekranı).
  final bool baslik;

  /// "tayfam" yazısı gösterilsin mi.
  final bool yazili;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final zemin = this.zemin ?? r.zemin;
    final simge = CustomPaint(
      size: Size.square(boyut),
      painter: MonogramBoyaci(
        govde: monogramGovdeRengi(r, zemin),
        cizgi: r.mango,
        nokta: r.nar,
      ),
    );

    final Widget logo;
    if (yazili && boyut >= TayfamSizes.logoYaziEsigi) {
      final punto = boyut * TayfamSizes.logoYaziOrani;
      logo = FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            simge,
            SizedBox(width: boyut * TayfamSizes.logoYaziBoslukOrani),
            Text(
              metinler.bilesen_logo_yazisi,
              maxLines: 1,
              softWrap: false,
              textScaler: TextScaler.noScaling,
              style: context.yazi.displayLarge?.copyWith(
                color: logoYaziRengi(r, zemin),
                fontSize: punto,
                fontWeight: TayfamTypography.buyukBaslikAgirligi,
                letterSpacing: punto * TayfamSizes.logoHarfAraligiOrani,
                height: 1,
              ),
            ),
          ],
        ),
      );
    } else {
      logo = simge;
    }

    return Semantics(
      container: true,
      label: metinler.bilesen_logo_etiketi,
      image: true,
      header: baslik,
      excludeSemantics: true,
      child: logo,
    );
  }
}

/// Monogram gövdesinin [zemin] üzerindeki rengi (Standartlar: açık zeminde
/// brand, koyu zeminde turkuaz).
///
/// "Açık" ve "koyu" zemin, iki aday rengin zeminle kontrastıyla ayrılır:
/// hangisi zeminden daha iyi ayrışıyorsa o seçilir. Böylece açık temanın
/// zemin ve kartında brand; koyu temanın zemininde ve iki temada da mor
/// marka yüzeyinde (brand üzerinde brand görünmez) turkuaz olur. Brand iki
/// temada da `markaYuzey` token'ıdır (koyu temanın `marka`'sı brand-dark
/// olduğu için o kullanılmaz).
Color monogramGovdeRengi(TayfamColors r, Color zemin) {
  final brand = r.markaYuzey;
  final turkuaz = r.teal;
  return kontrastOrani(turkuaz, zemin) > kontrastOrani(brand, zemin)
      ? turkuaz
      : brand;
}

/// "tayfam" yazısının [zemin] üzerindeki rengi: ana metin (açık temada ink)
/// ya da mor yüzeyin üstündeki beyaz; zeminle daha iyi ayrışanı.
Color logoYaziRengi(TayfamColors r, Color zemin) {
  final metin = r.metin;
  final beyaz = r.markaYuzeyUstu;
  return kontrastOrani(beyaz, zemin) > kontrastOrani(metin, zemin)
      ? beyaz
      : metin;
}

/// Monogramı tanıtım sitesindeki `icon.svg` yollarıyla (viewBox 64) çizer.
///
/// ```svg
/// <path d="M31 8c-1 14-3 26-1 36 2 9 10 13 18 7" stroke-width="10"
///   stroke-linecap="round"/>                       <!-- gövde -->
/// <path d="M14 27c10 0 22-2 34-6" .../>             <!-- çizgi (mango) -->
/// <circle cx="52" cy="13" r="4.5"/>                  <!-- nokta (nar) -->
/// ```
///
/// Aynı yollar Android başlatıcı ikonunda da kullanılır
/// (`tool/ikon/ikon_uret.py`).
class MonogramBoyaci extends CustomPainter {
  const MonogramBoyaci({
    required this.govde,
    required this.cizgi,
    required this.nokta,
  });

  /// Gövde ve kuyruk rengi.
  final Color govde;

  /// Yatay çizgi rengi (mango).
  final Color cizgi;

  /// Nokta rengi (nar).
  final Color nokta;

  /// SVG'nin viewBox kenarı.
  static const double kutu = 64;

  static const double _kalinlik = 10;

  static const Offset _noktaMerkezi = Offset(52, 13);

  static const double _noktaYaricapi = 4.5;

  static final Path _govdeYolu = Path()
    ..moveTo(31, 8)
    ..relativeCubicTo(-1, 14, -3, 26, -1, 36)
    ..relativeCubicTo(2, 9, 10, 13, 18, 7);

  static final Path _cizgiYolu = Path()
    ..moveTo(14, 27)
    ..relativeCubicTo(10, 0, 22, -2, 34, -6);

  @override
  void paint(Canvas canvas, Size size) {
    final olcek = size.shortestSide / kutu;
    canvas
      ..save()
      ..translate(
        (size.width - kutu * olcek) / 2,
        (size.height - kutu * olcek) / 2,
      )
      ..scale(olcek);
    canvas
      ..drawPath(_govdeYolu, _kalem(govde))
      ..drawPath(_cizgiYolu, _kalem(cizgi))
      ..drawCircle(_noktaMerkezi, _noktaYaricapi, Paint()..color = nokta)
      ..restore();
  }

  static Paint _kalem(Color renk) {
    return Paint()
      ..color = renk
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kalinlik
      ..strokeCap = StrokeCap.round;
  }

  @override
  bool shouldRepaint(MonogramBoyaci eski) {
    return eski.govde != govde || eski.cizgi != cizgi || eski.nokta != nokta;
  }
}
