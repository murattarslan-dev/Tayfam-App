import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik türü çipi: hap biçimli, türün kendi dolgu rengi ve üstündeki
/// metin rengi, türün ikonu ve adı (ADR-0004 Notlar, 2026-11-10). Renk,
/// ikon ve ad etkinlik türü kaydından gelir; renk tek başına bilgi taşımaz.
/// Yalnızca gösterir; dokunulmaz.
///
/// [buyuk] çip giriş ekranındaki tür haplarıdır (Design: Giriş): 15 px
/// etiket, 18 px ikon, daha geniş iç boşluk.
class EtkinlikTuruCipi extends StatelessWidget {
  const EtkinlikTuruCipi({super.key, required this.tur, this.buyuk = false});

  /// Gösterilecek tür; tanınmayan tür "genel" görünür.
  final EventType tur;

  /// Büyük çip mi.
  final bool buyuk;

  @override
  Widget build(BuildContext context) {
    final girdi = etkinlikTuruGirdisi(tur);
    final cift = context.turRenkleri.cift(girdi.renk);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cift.dolgu,
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: buyuk ? TayfamSpacing.s16 : TayfamSpacing.s12,
          vertical: buyuk ? TayfamSpacing.s8 : TayfamSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                girdi.ikon,
                size: buyuk ? TayfamSizes.ikonOrta : TayfamSizes.ikonKucuk,
                color: cift.ustu,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s4),
            Flexible(
              child: Text(
                girdi.ad(AppLocalizations.of(context)),
                style:
                    (buyuk ? context.yazi.labelLarge : context.yazi.labelMedium)
                        ?.copyWith(color: cift.ustu),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
