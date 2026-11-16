import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Liste satırının solundaki gün ve ay kısaltması ("26 / Kas"; etkinlik
/// listesi, "Boşum" günleri). Ay adı `intl`'den, büyük harfe çevrilmeden
/// (ADR-0008). Satırın metni zaten okunduğu için ekran okuyucudan gizlenir.
/// [an]'ın takvim alanları olduğu gibi gösterilir; saat dilimi çevirisi
/// çağıranın işidir.
class TarihKutusu extends StatelessWidget {
  const TarihKutusu({super.key, required this.an});

  final DateTime an;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintMarka,
          borderRadius: TayfamRadii.onizlemeKoseleri,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: TayfamSizes.tarihKutusuGenislik,
            minHeight: TayfamSizes.tarihKutusuYukseklik,
          ),
          child: Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat.d(m.localeName).format(an),
                  style: yazi.titleLarge?.copyWith(
                    fontWeight: TayfamTypography.buyukBaslikAgirligi,
                  ),
                ),
                Text(
                  DateFormat.MMM(m.localeName).format(an),
                  style: yazi.labelSmall?.copyWith(color: r.tintMarkaUstu),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
