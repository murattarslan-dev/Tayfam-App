import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Satırları ince çizgiyle ayrılmış kart (tasarım: Ana-Tam-Sayfa,
/// Ayar-Ana): card zemin, 1 px line kenar, 22 px yarıçap. Satırlar
/// [ListeKartiSatiri] ya da başka bir öğe olabilir.
class ListeKarti extends StatelessWidget {
  const ListeKarti({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
        side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (sira, satir) in children.indexed) ...[
            if (sira > 0)
              Divider(
                height: TayfamSizes.kenar,
                thickness: TayfamSizes.kenar,
                color: r.cizgi,
              ),
            satir,
          ],
        ],
      ),
    );
  }
}

/// [ListeKarti]'ndaki dokunulabilir satır: satırın tamamı tek düğmedir ve
/// ekran okuyucu içeriği birlikte okur.
class ListeKartiSatiri extends StatelessWidget {
  const ListeKartiSatiri({
    super.key,
    required this.child,
    this.onTap,
    this.icBosluk = const EdgeInsets.symmetric(
      horizontal: TayfamSpacing.s16,
      vertical: TayfamSpacing.s12,
    ),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry icBosluk;

  @override
  Widget build(BuildContext context) {
    final icerik = Padding(padding: icBosluk, child: child);
    final onTap = this.onTap;
    if (onTap == null) return Semantics(container: true, child: icerik);
    return OdakCercevesi(
      koseler: BorderRadius.zero,
      child: Semantics(
        container: true,
        button: true,
        child: InkWell(onTap: onTap, child: icerik),
      ),
    );
  }
}
