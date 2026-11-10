import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Etkinlik türü çipinin vurgu rengi. Hepsinde metin ink'tir (vurgu
/// renkleri metin rengi olmaz). Türün hangi vurguyu alacağına etkinlik
/// özelliğindeki tür kaydı karar verir (ADR-0002).
enum CipVurgusu { teal, mango, nar }

/// Etkinlik türü çipi: hap biçimli, vurgu zemin + ink metin, isteğe bağlı
/// tür ikonu. Yalnızca gösterir; dokunulmaz.
class EtkinlikTuruCipi extends StatelessWidget {
  const EtkinlikTuruCipi({
    super.key,
    required this.etiket,
    required this.vurgu,
    this.ikon,
  });

  final String etiket;
  final CipVurgusu vurgu;
  final IconData? ikon;

  /// [vurgu]nun bu temadaki zemin rengi.
  static Color zeminRengi(TayfamColors r, CipVurgusu vurgu) {
    return switch (vurgu) {
      CipVurgusu.teal => r.teal,
      CipVurgusu.mango => r.mango,
      CipVurgusu.nar => r.nar,
    };
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final ikon = this.ikon;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: zeminRengi(r, vurgu),
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ikon != null) ...[
              ExcludeSemantics(
                child: Icon(
                  ikon,
                  size: TayfamSizes.ikonKucuk,
                  color: r.vurguUstu,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s4),
            ],
            Flexible(
              child: Text(
                etiket,
                style: context.yazi.labelMedium?.copyWith(color: r.vurguUstu),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
