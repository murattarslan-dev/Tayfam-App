import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_havuzu/application/havuz_listesi.dart';
import 'package:tayfam/features/soru_havuzu/presentation/ortak.dart';
import 'package:tayfam/features/soru_havuzu/presentation/soru_satiri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ana sayfadaki "Soru havuzu" kartı (`question_pool`; App ADR-0033 §2):
/// son sorulan sorular. Veri modülün kendi ucundan (`GET …/questions?
/// pool=question_pool`) gelir ve havuz listesiyle paylaşılır. "Tümü" soru
/// havuzunu açar; havuz boşsa "Soru sor". Modül kapalıysa
/// (`module-disabled`) kart yer kaplamaz.
class HavuzKarti extends ConsumerWidget {
  const HavuzKarti({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = havuzListesiProvider(anaHavuzListesi(tayfaId));
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    if (liste == null &&
        hata is ApiProblem &&
        hata.type == ProblemType.moduleDisabled) {
      return const SizedBox.shrink();
    }
    final sorular = liste?.ogeler.take(kartSoruSayisi).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(
          baslik: m.soru_havuzu_ad,
          tumuEtiketi: m.soru_havuzu_tumu,
          onTumu: () => context.go(Adresler.soruHavuzu(tayfaId)),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (sorular != null && sorular.isEmpty)
          TayfamKart(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  m.soru_havuzu_bos,
                  style: context.yazi.bodyMedium?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                ),
                const SizedBox(height: TayfamSpacing.s8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => unawaited(
                      havuzSoruFormunuAc(context, tayfaId: tayfaId),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(m.soru_sor),
                  ),
                ),
              ],
            ),
          )
        else if (sorular != null)
          ListeKarti(
            children: [
              for (final soru in sorular)
                HavuzSoruSatiri(
                  key: ValueKey(soru.id),
                  ders: soru.subjectKey,
                  konu: soru.topicKey,
                  metin: soru.body,
                  fotografSayisi: soru.photoUploadIds.length,
                  cevapSayisi: soru.answerCount,
                  satirSayisi: 2,
                  onTap: () => unawaited(
                    context.push(Adresler.havuzSorusu(tayfaId, soru.id)),
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
              etiket: m.soru_havuzu_yukleniyor,
              gecikmeli: true,
            ),
          ),
      ],
    );
  }
}
