import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Birincil eylem: hap biçimli, en az 48 px yüksek düğme (ADR-0004).
///
/// Açık zeminde brand + beyaz, koyu zeminde mango + ink. Mor marka
/// yüzeyinde (tayfa ana sayfasının üst bölümü, ADR-0004 §2a) temadan
/// bağımsız olarak mango + ink için [markaYuzeyinde] verilir.
/// [onPressed] `null` ise düğme devre dışıdır.
class BirincilEylem extends StatelessWidget {
  const BirincilEylem({
    super.key,
    required this.etiket,
    required this.onPressed,
    this.ikon,
    this.markaYuzeyinde = false,
  });

  final String etiket;
  final VoidCallback? onPressed;
  final IconData? ikon;
  final bool markaYuzeyinde;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: markaYuzeyinde ? r.mango : r.birincilEylem,
          foregroundColor: markaYuzeyinde ? r.vurguUstu : r.birincilEylemUstu,
          disabledBackgroundColor: r.pasif,
          disabledForegroundColor: r.pasifUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s24,
            vertical: TayfamSpacing.s12,
          ),
          shape: const StadiumBorder(),
          // Odak çerçevesini OdakCercevesi çizer.
          side: BorderSide.none,
          textStyle: context.yazi.labelLarge,
        ),
        child: EylemIcerigi(etiket: etiket, ikon: ikon),
      ),
    );
  }
}
