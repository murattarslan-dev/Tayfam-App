import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir anketin listedeki kartı (tasarım: Anketler; ADR-0018 §5): solda
/// anket ikonu, soru, durum çipi, "N kişi oy verdi" ile kapanış günü ya da
/// "Gizli anket", kullanıcı oy verdiyse "Oy verdin".
///
/// Kartta seçenek sayıları gösterilmez; böylece gizli ankette eşik
/// (kesin kural 7) kartta ayrıca düşünülmek zorunda kalmaz. Kartın tamamı
/// tek bir düğmedir ve anketin ekranını açar.
class AnketKarti extends StatelessWidget {
  const AnketKarti({
    super.key,
    required this.anket,
    required this.simdi,
    this.onTap,
  });

  final Poll anket;

  /// Kapanma denetiminin saati.
  final DateTime simdi;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final kapali = anketKapali(anket, simdi);
    final oy = m.anket_oy_veren_sayisi(anket.voterCount);
    final ek = _ek(m, kapali);
    final kucuk = context.yazi.labelSmall?.copyWith(
      color: r.metinIkincil,
      fontWeight: FontWeight.w400,
    );
    return TayfamKart(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: r.tintMarka,
                borderRadius: TayfamRadii.dugmeKoseleri,
              ),
              child: SizedBox.square(
                dimension: TayfamSizes.menuIkonKutusu,
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: TayfamSizes.ikon,
                  color: r.tintMarkaUstu,
                ),
              ),
            ),
          ),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(anket.question, style: context.yazi.titleMedium),
                const SizedBox(height: TayfamSpacing.s8),
                Wrap(
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AnketDurumCipi(kapali: kapali),
                    Text(
                      ek == null ? oy : m.anket_karti_ozet(oy, ek),
                      style: kucuk,
                    ),
                  ],
                ),
                if (oyVerdi(anket)) ...[
                  const SizedBox(height: TayfamSpacing.s8),
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.check_rounded,
                          size: TayfamSizes.ikonKucuk,
                          color: r.tintMarkaUstu,
                        ),
                      ),
                      const SizedBox(width: TayfamSpacing.s4),
                      Flexible(
                        child: Text(
                          m.anket_oy_verdin,
                          style: context.yazi.labelMedium?.copyWith(
                            color: r.tintMarkaUstu,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Oy sayısının yanındaki bilgi: gizli ankette "Gizli anket", değilse
  /// kapanış günü (açıkta planlanan, kapanmışta kapandığı); yoksa `null`.
  String? _ek(AppLocalizations m, bool kapali) {
    if (anket.anonymous) return m.anket_gizli;
    if (kapali) {
      final zaman = anket.closedAt ?? anket.closesAt;
      return zaman == null ? null : m.anket_karti_kapandi(zaman.toLocal());
    }
    final kapanis = anket.closesAt;
    return kapanis == null ? null : m.anket_karti_kapanir(kapanis.toLocal());
  }
}
