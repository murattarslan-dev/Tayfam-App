import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Tam yüzey mor (ADR-0004 §2a): `markaYuzey` (brand) zemin, beyaz metin ve
/// ikon; iki temada da aynı. Yalnızca tayfa ana sayfasının üst bölümünde,
/// giriş ekranında (ADR-0012 §2) ve davet linki ekranının üst bölümünde
/// (ADR-0018 §6 Notlar 2026-11-13) kullanılır.
///
/// Altındaki öğelerde odak çerçevesi iki temada da mango olur
/// (`TayfamColors.markaYuzeyOdak`, ADR-0004 Notlar 2026-11-10); brand
/// çerçeve brand zeminde görünmezdi. Birincil eylem bu yüzeyde
/// `BirincilEylem(markaYuzeyinde: true)` ile mango zemin + ink metindir.
/// Durum çubuğu ikonları açık renge çevrilir.
class MarkaYuzeyi extends StatelessWidget {
  const MarkaYuzeyi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // markaYuzey iki temada da koyu bir mor; üstünde açık ikonlar.
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: r.markaYuzey,
        child: Theme(
          data: TayfamTheme.markaYuzeyi(Theme.of(context)),
          child: IconTheme.merge(
            data: IconThemeData(color: r.markaYuzeyUstu),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: r.markaYuzeyUstu),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
