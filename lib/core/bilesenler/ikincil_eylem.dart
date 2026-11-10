import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// İkincil eylem: 12 px yuvarlak köşeli, nar zemin + ink metin
/// (tanıtım sayfasındaki "Buradayım" düğmesi; ADR-0004 §2a). Nar zemin
/// üzerinde beyaz kullanılmaz. [onPressed] `null` ise devre dışıdır.
class IkincilEylem extends StatelessWidget {
  const IkincilEylem({
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
      koseler: TayfamRadii.dugmeKoseleri,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: r.nar,
          foregroundColor: r.vurguUstu,
          disabledBackgroundColor: r.pasif,
          disabledForegroundColor: r.pasifUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s20,
            vertical: TayfamSpacing.s12,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: TayfamRadii.dugmeKoseleri,
          ),
          side: BorderSide.none,
          textStyle: context.yazi.labelLarge,
        ),
        child: EylemIcerigi(etiket: etiket, ikon: ikon),
      ),
    );
  }
}
