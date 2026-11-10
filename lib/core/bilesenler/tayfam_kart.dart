import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Kart: card zemin, 1 px line kenar, 22 px yarıçap, 20 px iç boşluk
/// (ADR-0004). Tek gölge yalnızca [oneCikan] kartta kullanılır.
///
/// [onTap] verilirse kartın tamamı tek bir düğmedir; ekran okuyucu kartın
/// metnini düğme etiketi olarak okur. Dokunulabilir kartın içine ayrıca
/// düğme konmaz (iç içe dokunma alanı olmasın).
class TayfamKart extends StatelessWidget {
  const TayfamKart({
    super.key,
    required this.child,
    this.onTap,
    this.oneCikan = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool oneCikan;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final onTap = this.onTap;
    final icerik = Padding(
      padding: const EdgeInsets.all(TayfamSpacing.kartIci),
      child: child,
    );
    Widget kart = Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
        side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? icerik
          : Semantics(
              container: true,
              button: true,
              child: InkWell(onTap: onTap, child: icerik),
            ),
    );
    if (oneCikan) {
      kart = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: TayfamRadii.kartKoseleri,
          boxShadow: r.oneCikanGolge,
        ),
        child: kart,
      );
    }
    if (onTap == null) {
      return kart;
    }
    return OdakCercevesi(koseler: TayfamRadii.kartKoseleri, child: kart);
  }
}
