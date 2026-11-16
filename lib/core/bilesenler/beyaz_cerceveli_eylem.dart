import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tema.dart';

/// Mor yüzeyde beyaz çerçeveli hap düğme ("Tayfa kuruldu" ekranında
/// "Tayfaya git", "Kopyala"; "Etkinlik açıldı" ekranında "Etkinliğe git").
class BeyazCerceveliEylem extends StatelessWidget {
  const BeyazCerceveliEylem({
    super.key,
    required this.etiket,
    required this.onPressed,
    this.ikon,
  });

  final String etiket;
  final VoidCallback? onPressed;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: r.markaYuzeyUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s16,
            vertical: TayfamSpacing.s12,
          ),
          shape: const StadiumBorder(),
          side: BorderSide(
            color: r.markaYuzeyUstu,
            width: TayfamSizes.vurguKenari,
          ),
          textStyle: context.yazi.labelLarge,
        ),
        child: EylemIcerigi(etiket: etiket, ikon: ikon),
      ),
    );
  }
}
