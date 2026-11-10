import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Uçtan uca şifreli" satırı: kilit ikonu + ink-muted metin (ADR-0004).
/// Birebir sohbetin üstünde gösterilir. Metin çeviri dosyasından gelir.
class UctanUcaSifreliSatiri extends StatelessWidget {
  const UctanUcaSifreliSatiri({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Metnin yanındaki kilit süstür; anlamı metin taşır.
        ExcludeSemantics(
          child: Icon(
            Icons.lock_outline_rounded,
            size: TayfamSizes.ikonKucuk,
            color: r.metinIkincil,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s8),
        Flexible(
          child: Text(
            AppLocalizations.of(context).bilesen_uctan_uca_sifreli,
            style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
          ),
        ),
      ],
    );
  }
}
