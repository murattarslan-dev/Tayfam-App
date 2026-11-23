import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/garaj/application/garaj.dart';
import 'package:tayfam/features/garaj/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ana sayfadaki "Garaj" kartı (`garage`; App ADR-0033 §2): bu tayfada
/// görünen son araçlar ve sahipleri. Veri modülün kendi ucundan
/// (`GET …/garage`) gelir ve liste ekranıyla paylaşılır. "Tümü" ve satıra
/// dokunma tayfanın garajını açar. Modül kapalıysa (`module-disabled`)
/// kart yer kaplamaz.
class GarajKarti extends ConsumerWidget {
  const GarajKarti({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = tayfaGarajiProvider(tayfaId);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    if (liste == null &&
        hata is ApiProblem &&
        hata.type == ProblemType.moduleDisabled) {
      return const SizedBox.shrink();
    }
    final araclar = liste?.ogeler.take(kartAracSayisi).toList();
    void garajiAc() => unawaited(context.push(Adresler.tayfaGaraji(tayfaId)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(
          baslik: m.garaj_ad,
          tumuEtiketi: m.garaj_tumu,
          onTumu: garajiAc,
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (araclar != null && araclar.isEmpty)
          TayfamKart(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  m.garaj_bos_tayfa,
                  style: context.yazi.bodyMedium?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                ),
                const SizedBox(height: TayfamSpacing.s8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BaglantiEylemi(
                    etiket: m.garaj_garaji_ac,
                    onPressed: garajiAc,
                  ),
                ),
              ],
            ),
          )
        else if (araclar != null)
          ListeKarti(
            children: [
              for (final arac in araclar)
                InkWell(
                  key: ValueKey(arac.id),
                  onTap: garajiAc,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: TayfamSizes.dokunmaMin,
                    ),
                    child: GarajAraci(
                      arac: arac,
                      sahibiGoster: true,
                      ozet: true,
                    ),
                  ),
                ),
            ],
          )
        else if (hata != null) ...[
          HataSatiri.hatadan(hata),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(saglayici),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(m.tayfa_ana_tekrar_dene),
            ),
          ),
        ] else
          Center(
            child: TayfamYukleniyor(
              etiket: m.garaj_yukleniyor,
              gecikmeli: true,
            ),
          ),
      ],
    );
  }
}
