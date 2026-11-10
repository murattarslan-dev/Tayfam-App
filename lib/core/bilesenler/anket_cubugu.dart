import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/tema/tayfam_motion.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Anket seçeneği satırı: seçenek metni, oy sayısı ve 10 px tam yuvarlak
/// çubuk (ADR-0004). Önde olan seçenek brand, diğerleri nar.
///
/// Bileşen yalnızca kendisine verilen sayıyı gösterir. Gizli ankette kimin
/// oy verdiğini göstermemek ve az oyda eşik uygulamak (CLAUDE.md, kesin
/// kural 7) anketi gösteren özelliğin işidir.
class AnketCubugu extends StatelessWidget {
  const AnketCubugu({
    super.key,
    required this.secenek,
    required this.oy,
    required this.toplamOy,
    this.onde = false,
  });

  final String secenek;
  final int oy;
  final int toplamOy;

  /// En çok oyu alan seçenek mi (brand dolgu).
  final bool onde;

  /// Çubuğun doluluk oranı (0–1).
  double get oran => toplamOy <= 0 ? 0.0 : (oy / toplamOy).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final yuzde = (oran * 100).round();
    final sayi = NumberFormat.decimalPattern(metinler.localeName).format(oy);
    final sure = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TayfamMotion.uzun;
    return Semantics(
      container: true,
      label: metinler.bilesen_anket_secenek_anlam(secenek, oy, yuzde),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(secenek, style: context.yazi.bodyLarge)),
              const SizedBox(width: TayfamSpacing.s12),
              Text(sayi, style: context.yazi.titleMedium),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s8),
          ClipRRect(
            borderRadius: TayfamRadii.hapKoseleri,
            child: SizedBox(
              height: TayfamSizes.anketCubugu,
              child: ColoredBox(
                color: r.cizgi,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: oran),
                    duration: sure,
                    curve: TayfamMotion.egri,
                    builder: (context, deger, _) => FractionallySizedBox(
                      widthFactor: deger,
                      heightFactor: 1,
                      child: ColoredBox(color: onde ? r.marka : r.nar),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
