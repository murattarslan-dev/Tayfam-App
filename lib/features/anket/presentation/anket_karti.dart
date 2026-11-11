import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir anketin listedeki kartı (ADR-0018 §5): durum etiketleri, soru, oy
/// veren sayısı, kullanıcı oy verdiyse "Oy verdin" ve kapanış zamanı.
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
    final kapali = anketKapali(anket, simdi);
    return TayfamKart(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnketEtiketleri(anket: anket, kapali: kapali),
          const SizedBox(height: TayfamSpacing.s8),
          Text(anket.question, style: context.yazi.titleMedium),
          const SizedBox(height: TayfamSpacing.s8),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                m.anket_oy_veren_sayisi(anket.voterCount),
                style: context.yazi.bodyMedium?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              ),
              if (oyVerdi(anket)) Etiket(metin: m.anket_oy_verdin),
            ],
          ),
          if (anket.closesAt != null || anket.closedAt != null) ...[
            const SizedBox(height: TayfamSpacing.s4),
            AnketKapanisMetni(anket: anket, kapali: kapali),
          ],
        ],
      ),
    );
  }
}
