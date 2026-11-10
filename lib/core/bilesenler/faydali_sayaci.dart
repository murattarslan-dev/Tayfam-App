import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Faydalı" sayacı: tint-mango zemin + honey metin (ADR-0004; koyu
/// temada tint-mango-dark + #FFD27A). Soru-cevap kartında cevabın kaç kişi
/// tarafından faydalı bulunduğunu gösterir.
///
/// [onPressed] verilirse dokunulabilir bir aç/kapa düğmesidir; [isaretli]
/// durumu ekran okuyucuya bildirilir ve yalnızca renkle değil ikonla da
/// gösterilir.
class FaydaliSayaci extends StatelessWidget {
  const FaydaliSayaci({
    super.key,
    required this.sayi,
    this.isaretli = false,
    this.onPressed,
  });

  final int sayi;
  final bool isaretli;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final yaziRengi = r.tintMangoUstu;
    final bicim = NumberFormat.decimalPattern(metinler.localeName);
    final sayiMetni = bicim.format(sayi);
    final icerik = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s12,
        vertical: TayfamSpacing.s4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isaretli ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
            size: TayfamSizes.ikonKucuk,
            color: yaziRengi,
          ),
          const SizedBox(width: TayfamSpacing.s4),
          Text(
            sayiMetni,
            style: context.yazi.labelLarge?.copyWith(color: yaziRengi),
          ),
          const SizedBox(width: TayfamSpacing.s4),
          Flexible(
            child: Text(
              metinler.bilesen_faydali,
              style: context.yazi.labelSmall?.copyWith(color: yaziRengi),
            ),
          ),
        ],
      ),
    );
    final anlam = metinler.bilesen_faydali_anlam(sayi);
    final onPressed = this.onPressed;
    if (onPressed == null) {
      return Semantics(
        container: true,
        label: anlam,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: r.tintMango,
            borderRadius: TayfamRadii.hapKoseleri,
          ),
          child: icerik,
        ),
      );
    }
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: Semantics(
        container: true,
        button: true,
        toggled: isaretli,
        label: anlam,
        onTap: onPressed,
        excludeSemantics: true,
        child: Material(
          color: r.tintMango,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: TayfamSizes.dokunmaMin,
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: icerik,
            ),
          ),
        ),
      ),
    );
  }
}
