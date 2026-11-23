import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/garaj/application/garaj.dart';
import 'package:tayfam/features/garaj/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinliğin araç formundaki "Garajımdan seç" listesi (App ADR-0033 §2;
/// Tayfam-Api ADR-0040 §4): kendi garajındaki araçlar, tek seçim. Seçili
/// araca yeniden dokunmak seçimi kaldırır (elle yazmaya döner). Garaj boşsa
/// ya da okunamazsa hiçbir şey çizilmez; form elle yazmayla çalışır.
///
/// Plaka garajda yoktur; yalnızca etkinliğin araç formunda yazılır.
class GarajdanSecim extends ConsumerWidget {
  const GarajdanSecim({
    super.key,
    required this.secili,
    required this.onDegisti,
  });

  /// Seçili garaj aracının kimliği; elle yazılıyorsa `null`.
  final String? secili;

  final ValueChanged<GarageVehicle?> onDegisti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final araclar = ref.watch(garajimProvider).value?.vehicles;
    if (araclar == null || araclar.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.garaj_garajimdan_sec),
        ListeKarti(
          children: [
            for (final arac in araclar)
              _SecimSatiri(
                key: ValueKey(arac.id),
                arac: arac,
                secili: arac.id == secili,
                onTap: () => onDegisti(arac.id == secili ? null : arac),
              ),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Text(
          secili == null ? m.garaj_ya_da_elle_yaz : m.garaj_secim_notu,
          style: context.yazi.bodySmall?.copyWith(
            color: context.renkler.metinIkincil,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s12),
      ],
    );
  }
}

class _SecimSatiri extends StatelessWidget {
  const _SecimSatiri({
    super.key,
    required this.arac,
    required this.secili,
    required this.onTap,
  });

  final GarageVehicle arac;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi;
    final ayrinti = aracAyrintisi(arac);
    return Semantics(
      button: true,
      selected: secili,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s16,
              vertical: TayfamSpacing.s8,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    secili ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: secili ? r.marka : r.metinIkincil,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aracAdi(arac),
                        style: yazi.titleSmall?.copyWith(color: r.metin),
                      ),
                      if (ayrinti.isNotEmpty)
                        Text(
                          ayrinti,
                          style: yazi.bodySmall?.copyWith(
                            color: r.metinIkincil,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
